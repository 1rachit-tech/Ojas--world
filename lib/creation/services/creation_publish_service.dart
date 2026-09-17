import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../services/media_hash_service.dart';
import '../models/creation_project.dart';
import '../models/creation_publish_state.dart';
import 'creation_azure_media_service.dart';
import 'creation_project_store.dart';
import 'creation_publish_state_store.dart';
import 'creation_validation_service.dart';

class CreationPublishResult {
  const CreationPublishResult({required this.postId, required this.mediaUrl, required this.isProcessing});
  final String postId;
  final String mediaUrl;
  final bool isProcessing;
}

class CreationPublishService {
  CreationPublishService({FirebaseAuth? auth, FirebaseFirestore? firestore, FirebaseStorage? storage, CreationAzureMediaService? azureMedia})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _azureMedia = azureMedia ?? CreationAzureMediaService(auth: auth);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final CreationAzureMediaService _azureMedia;

  Future<CreationPublishResult> publish(CreationProject project) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != project.ownerId) {
      throw const CreationPublishException('Please sign in again before posting.');
    }

    final validation = await CreationValidationService.validateProject(project, requirePublishRights: true);
    if (!validation.isValid) throw CreationPublishException(validation.message);
    if (project.mediaAssets.length != 1 || project.mediaAssets.first.type != 'video') {
      throw const CreationPublishException('This publishing path currently accepts one video. Multi-media and image publishing remain draft-ready.');
    }
    if (project.audio.isNotEmpty && !_azureMedia.isConfigured) {
      throw const CreationPublishException('Audio tracks require the server media processor. Configure the OJAS Azure media broker before publishing audio edits.');
    }

    final asset = project.mediaAssets.first;
    final postRef = _firestore.collection('reels').doc(project.projectId);
    final publishState = project.publishState;
    final publishRequestId = publishState['publishRequestId'] as String? ?? 'creation:${project.projectId}';
    final allowComments = publishState['allowComments'] is bool ? publishState['allowComments'] as bool : true;
    final recommendRequested = publishState['recommend'] is bool ? publishState['recommend'] as bool : true;
    final isPublic = project.privacy.toLowerCase() == 'public';
    final recommendationEligible = isPublic && recommendRequested;

    final existing = await postRef.get();
    if (existing.exists) {
      final data = existing.data() ?? const <String, dynamic>{};
      final existingUrl = data['videoUrl'] as String? ?? '';
      if (existingUrl.isNotEmpty) {
        final status = (data['mediaProcessingStatus'] as String? ?? '').toLowerCase();
        final provider = (data['mediaProvider'] as String? ?? '').toLowerCase();
        final processing = provider == 'azure' && status != 'ready' && status != 'published';
        await _saveState(project.projectId, processing ? CreationPublishStage.processing : CreationPublishStage.published, requestId: publishRequestId);
        return CreationPublishResult(postId: postRef.id, mediaUrl: existingUrl, isProcessing: processing);
      }
    }

    await _saveState(project.projectId, CreationPublishStage.validating, requestId: publishRequestId);
    String downloadUrl;
    String? storagePath;

    await _saveState(project.projectId, CreationPublishStage.preparing, requestId: publishRequestId);
    if (_azureMedia.isConfigured) {
      await _saveState(project.projectId, CreationPublishStage.uploading, requestId: publishRequestId, totalBytes: asset.sizeBytes);
      final azureResult = await _azureMedia.uploadVideo(
        projectId: project.projectId,
        assetId: asset.assetId,
        localPath: asset.localUri,
        contentType: asset.mimeType == 'video/*' ? 'video/mp4' : asset.mimeType,
        onProgress: (uploaded, total) {
          _saveState(project.projectId, CreationPublishStage.uploading, requestId: publishRequestId, bytesUploaded: uploaded, totalBytes: total);
        },
      );
      if (azureResult == null) throw const CreationPublishException('Azure media service returned no upload result.');
      downloadUrl = azureResult.mediaUrl;
      storagePath = azureResult.storagePath;
    } else {
      final source = File(asset.localUri);
      final storageReference = _storage.ref().child('reels').child(user.uid).child('${project.projectId}.mp4');
      await _saveState(project.projectId, CreationPublishStage.uploading, requestId: publishRequestId, totalBytes: asset.sizeBytes);
      final uploadTask = await storageReference.putFile(source, SettableMetadata(contentType: 'video/mp4'));
      downloadUrl = await uploadTask.ref.getDownloadURL();
      storagePath = storageReference.fullPath;
      await _saveState(project.projectId, CreationPublishStage.uploading, requestId: publishRequestId, bytesUploaded: asset.sizeBytes, totalBytes: asset.sizeBytes);
    }

    await _saveState(project.projectId, CreationPublishStage.processing, requestId: publishRequestId, bytesUploaded: asset.sizeBytes, totalBytes: asset.sizeBytes);
    final mediaHash = await _computeMediaHash(asset.localUri);
    final editGraph = await _prepareEditGraph(project, user.uid);
    await _saveState(project.projectId, CreationPublishStage.publishing, requestId: publishRequestId);

    await postRef.set(<String, dynamic>{
      'creatorId': user.uid,
      'projectId': project.projectId,
      'publishRequestId': publishRequestId,
      'videoUrl': downloadUrl,
      'hlsUrl': downloadUrl,
      'thumbnailUrl': '',
      'caption': project.caption,
      'shaderUsed': 'Natural',
      'visibility': project.privacy.toLowerCase(),
      'recommendationEligible': recommendationEligible,
      'moderationStatus': 'pending',
      'allowComments': allowComments,
      'mediaProvider': _azureMedia.isConfigured ? 'azure' : 'firebase',
      'mediaStoragePath': storagePath,
      'mediaProcessingStatus': _azureMedia.isConfigured ? 'queued' : 'uploaded',
      'mediaProcessingVersion': 2,
      'mediaProcessingMode': 'edit-graph-v2-render',
      'editGraphVersion': 2,
      'editGraph': editGraph,
      'aiGeneratedDisclosure': project.rights['aiGeneratedDisclosure'] == true,
      'copyrightConfirmed': project.rights['copyrightConfirmed'] == true,
      'createdAt': FieldValue.serverTimestamp(),
      'likesCount': 0,
      'commentsCount': 0,
      'sharesCount': 0,
      'likes': 0,
      'comments': 0,
      'saves': 0,
      'shares': 0,
      'views': 0,
      'watchTimeMs': 0,
      'completions': 0,
      'shopItemIds': const <String>[],
      'algorithmScore': 0.0,
      'audioTrackId': '',
      'mediaHash': mediaHash,
    }, SetOptions(merge: true));

    final processing = _azureMedia.isConfigured;
    final published = project.copyWith(
      status: processing ? CreationProjectStatus.processing : CreationProjectStatus.published,
      publishState: <String, dynamic>{
        ...publishState,
        'postId': postRef.id,
        'mediaUrl': downloadUrl,
        'mediaStoragePath': storagePath,
        'publishedAt': DateTime.now().toIso8601String(),
        'publishRequestId': publishRequestId,
        'allowComments': allowComments,
        'recommend': recommendationEligible,
        'processingStatus': processing ? 'queued' : 'uploaded',
        'mediaHash': mediaHash,
        'editGraphVersion': 2,
      },
    );
    await CreationProjectStore.instance.save(published);
    await _saveState(project.projectId, processing ? CreationPublishStage.processing : CreationPublishStage.published, requestId: publishRequestId, bytesUploaded: asset.sizeBytes, totalBytes: asset.sizeBytes);

    return CreationPublishResult(postId: postRef.id, mediaUrl: downloadUrl, isProcessing: processing);
  }

  Future<Map<String, dynamic>> _prepareEditGraph(CreationProject project, String uid) async {
    List<Map<String, dynamic>> bounded(List<Map<String, dynamic>> input, int maxItems) => input.take(maxItems).map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
    final timeline = project.timeline.take(32).map((clip) => clip.toMap()).toList(growable: false);
    final audioLayers = <Map<String, dynamic>>[];

    for (final raw in project.audio.take(32)) {
      final layer = Map<String, dynamic>.from(raw);
      final rawUri = layer['uri'];
      final localUri = rawUri is String ? rawUri.trim() : '';
      final layerId = layer['id'] is String && (layer['id'] as String).trim().isNotEmpty
          ? (layer['id'] as String).trim()
          : 'audio_${DateTime.now().microsecondsSinceEpoch}';

      if (localUri.startsWith('creation_audio/')) {
        layer
          ..remove('uri')
          ..['storagePath'] = localUri
          ..['id'] = layerId;
        audioLayers.add(layer);
        continue;
      }

      final file = File(localUri);
      if (!await file.exists()) {
        throw CreationPublishException('Audio file is no longer available: ${layer['title'] ?? layerId}.');
      }
      final size = await file.length();
      if (size <= 0 || size > 10 * 1024 * 1024) {
        throw const CreationPublishException('Each creation audio track must be between 1 byte and 10 MB.');
      }

      final fileName = localUri.split(RegExp(r'[\\/]')).last;
      final extensionIndex = fileName.lastIndexOf('.');
      final extension = extensionIndex >= 0 && extensionIndex < fileName.length - 1
          ? fileName.substring(extensionIndex).toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]'), '')
          : '.bin';
      final safeExtension = extension.length <= 8 ? extension : '.bin';
      final storageReference = _storage.ref()
          .child('creation_audio')
          .child(uid)
          .child(project.projectId)
          .child('$layerId$safeExtension');
      final metadata = SettableMetadata(contentType: _audioContentType(safeExtension));
      await storageReference.putFile(file, metadata);

      layer
        ..remove('uri')
        ..['storagePath'] = storageReference.fullPath
        ..['id'] = layerId;
      audioLayers.add(layer);
    }

    return <String, dynamic>{
      'version': 2,
      'timeline': timeline,
      'audio': audioLayers,
      'audioStorageBucket': Firebase.app().options.storageBucket ?? '',
      'textLayers': bounded(project.textLayers, 64),
      'stickerLayers': bounded(project.stickerLayers, 64),
      'effectLayers': bounded(project.effectLayers, 32),
      'operations': bounded(project.operations, 256),
      'accessibility': Map<String, dynamic>.from(project.accessibility),
    };
  }

  String _audioContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
        return 'audio/ogg';
      case '.opus':
        return 'audio/opus';
      default:
        return 'audio/*';
    }
  }

  Future<void> _saveState(String projectId, CreationPublishStage stage, {String? requestId, int bytesUploaded = 0, int totalBytes = 0}) async {
    try {
      await CreationPublishStateStore.instance.save(CreationPublishState(projectId: projectId, stage: stage, requestId: requestId, bytesUploaded: bytesUploaded, totalBytes: totalBytes, updatedAt: DateTime.now()));
    } catch (_) {}
  }

  Future<String> _computeMediaHash(String path) async {
    try {
      return MediaHashService.instance.normalize(await MediaHashService.instance.sha256File(File(path)));
    } catch (_) {
      return '';
    }
  }
}

class CreationPublishException implements Exception {
  const CreationPublishException(this.message);
  final String message;
  @override
  String toString() => message;
}
