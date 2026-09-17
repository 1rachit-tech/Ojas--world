import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../services/azure_media_playback_service.dart';
import '../models/creation_project.dart';
import 'creation_checkpoint_store.dart';
import 'creation_project_store.dart';

class PublishedShowEditService {
  PublishedShowEditService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    AzureMediaPlaybackService? playback,
    http.Client? client,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _playback = playback ?? AzureMediaPlaybackService(auth: auth),
        _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AzureMediaPlaybackService _playback;
  final http.Client _client;

  static const int _maxDownloadBytes = 512 * 1024 * 1024;

  Future<CreationProject> createProjectForEditing(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw const PublishedShowEditException('Please sign in again.');

    final normalizedPostId = postId.trim();
    if (normalizedPostId.isEmpty) {
      throw const PublishedShowEditException('Show ID is missing.');
    }

    final snapshot = await _firestore.collection('reels').doc(normalizedPostId).get();
    if (!snapshot.exists) throw const PublishedShowEditException('This Show no longer exists.');

    final data = snapshot.data() ?? const <String, dynamic>{};
    final creatorId = data['creatorId'] as String? ?? '';
    if (creatorId != user.uid) {
      throw const PublishedShowEditException('Only the creator can edit this Show.');
    }
    if (data['deletedAt'] != null || data['moderationStatus'] == 'deleted') {
      throw const PublishedShowEditException('Deleted Shows cannot be edited.');
    }

    final mediaProvider = (data['mediaProvider'] as String? ?? '').trim().toLowerCase();
    if (mediaProvider != 'azure') {
      throw const PublishedShowEditException(
        'This Show is not on the supported secure media pipeline yet.',
      );
    }
    if (!_playback.isConfigured) {
      throw const PublishedShowEditException(
        'The secure media broker is not configured on this build.',
      );
    }

    final asset = await _downloadSecureSource(normalizedPostId);
    final durationMs = await _readDuration(asset);
    if (durationMs <= 0) {
      throw const PublishedShowEditException('Unable to read the published video duration.');
    }

    final now = DateTime.now();
    final assetId = 'edit_${normalizedPostId}_${const Uuid().v4()}';
    final reelAudioPaths = _readAudioPaths(data['editGraph']);
    final privacy = _normalizePrivacy(data['visibility']);
    final reusePolicy = _normalizeReusePolicy(data['reusePolicy']);

    final media = CreationMediaAsset(
      assetId: assetId,
      localUri: asset.path,
      type: 'video',
      mimeType: 'video/mp4',
      sizeBytes: await asset.length(),
      durationMs: durationMs,
    );
    final clip = CreationTimelineClip(
      clipId: const Uuid().v4(),
      sourceId: assetId,
      startMs: 0,
      endMs: durationMs,
      trimInMs: 0,
      trimOutMs: durationMs,
    );

    final project = CreationProject(
      projectId: normalizedPostId,
      ownerId: user.uid,
      createdAt: now,
      updatedAt: now,
      creationType: CreationType.show,
      status: CreationProjectStatus.editing,
      mediaAssets: <CreationMediaAsset>[media],
      timeline: <CreationTimelineClip>[clip],
      caption: data['caption'] as String? ?? '',
      privacy: privacy,
      rights: <String, dynamic>{
        'copyrightConfirmed': data['copyrightConfirmed'] == true,
        'aiGeneratedDisclosure': data['aiGeneratedDisclosure'] == true,
      },
      publishState: <String, dynamic>{
        'editOfPostId': normalizedPostId,
        'previousMediaAssetId': data['mediaAssetId'],
        'previousMediaStoragePath': data['mediaStoragePath'],
        'previousProcessedVideoStoragePath': data['processedVideoStoragePath'],
        'previousThumbnailStoragePath': data['thumbnailStoragePath'],
        'previousHlsStoragePath': data['hlsStoragePath'],
        'previousAudioPaths': reelAudioPaths,
        'allowComments': data['allowComments'] == true,
        'recommend': data['recommendationEligible'] == true,
        'reusePolicy': reusePolicy,
        'processingStatus': 'edit_pending',
        'sourcePreparedAt': now.toIso8601String(),
      },
    );

    await CreationProjectStore.instance.save(project);
    await CreationCheckpointStore.instance.save(project);
    return project;
  }

  Future<File> _downloadSecureSource(String postId) async {
    final assets = await _playback.resolvePlaybackAssets(<String>[postId]);
    final sourceUrl = assets[postId]?.playbackUrl.trim() ?? '';
    if (sourceUrl.isEmpty) {
      throw const PublishedShowEditException(
        'Secure playback is not available for this Show yet. Try again after processing finishes.',
      );
    }

    final root = await getApplicationSupportDirectory();
    final editDirectory = Directory('${root.path}/ojas/published-edits/$postId');
    await editDirectory.create(recursive: true);
    final target = File('${editDirectory.path}/source.mp4');
    final partial = File('${editDirectory.path}/source.mp4.part');

    if (await partial.exists()) {
      await partial.delete();
    }

    final request = http.Request('GET', Uri.parse(sourceUrl));
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw PublishedShowEditException(
        'Secure media download failed (${response.statusCode}).',
      );
    }

    final announcedLength = response.contentLength;
    if (announcedLength != null && announcedLength > _maxDownloadBytes) {
      throw const PublishedShowEditException('Published media exceeds the 512 MB editing limit.');
    }

    var downloaded = 0;
    final sink = partial.openWrite();
    try {
      await for (final chunk in response.stream) {
        downloaded += chunk.length;
        if (downloaded > _maxDownloadBytes) {
          throw const PublishedShowEditException('Published media exceeds the 512 MB editing limit.');
        }
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }

    if (downloaded <= 0 || (announcedLength != null && downloaded != announcedLength)) {
      if (await partial.exists()) await partial.delete();
      throw const PublishedShowEditException('Downloaded media is incomplete.');
    }

    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
    return target;
  }

  Future<int> _readDuration(File file) async {
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      return controller.value.duration.inMilliseconds;
    } finally {
      await controller.dispose();
    }
  }

  static List<String> _readAudioPaths(dynamic editGraph) {
    if (editGraph is! Map) return const <String>[];
    final rawAudio = editGraph['audio'];
    if (rawAudio is! List) return const <String>[];
    return rawAudio
        .whereType<Map>()
        .map((layer) => layer['storagePath'])
        .whereType<String>()
        .map((path) => path.trim())
        .where((path) => path.startsWith('creation-audio/'))
        .take(32)
        .toList(growable: false);
  }

  static String _normalizePrivacy(dynamic value) {
    final normalized = value is String ? value.trim().toLowerCase() : 'public';
    return <String>{'public', 'followers', 'only me'}.contains(normalized)
        ? normalized
        : 'public';
  }

  static String _normalizeReusePolicy(dynamic value) {
    final normalized = value is String ? value.trim().toLowerCase() : 'allowed';
    return <String>{'allowed', 'followers', 'public'}.contains(normalized)
        ? normalized
        : 'allowed';
  }

  void dispose() {
    _client.close();
    _playback.dispose();
  }
}

class PublishedShowEditException implements Exception {
  const PublishedShowEditException(this.message);
  final String message;

  @override
  String toString() => message;
}
