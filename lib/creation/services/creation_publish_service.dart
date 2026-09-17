import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../services/media_hash_service.dart';
import '../models/creation_project.dart';
import '../models/creation_publish_state.dart';
import 'creation_azure_media_service.dart';
import 'creation_project_store.dart';
import 'creation_publish_state_store.dart';
import 'creation_validation_service.dart';

class CreationPublishResult {
  const CreationPublishResult({
    required this.postId,
    required this.mediaUrl,
    required this.isProcessing,
  });

  final String postId;
  final String mediaUrl;
  final bool isProcessing;
}

class CreationPublishService {
  CreationPublishService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    CreationAzureMediaService? azureMedia,
  })  : _auth = auth ?? FirebaseAuth.instance,
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

    const maxCaptionLength = 2200;
    final validation = await CreationValidationService.validateProject(
      project,
      requirePublishRights: true,
    );
    if (!validation.isValid) {
      throw CreationPublishException(validation.message);
    }
    if (project.caption.length > maxCaptionLength) {
      throw const CreationPublishException('Caption is too long.');
    }

    if (project.mediaAssets.length != 1 || project.mediaAssets.first.type != 'video') {
      throw const CreationPublishException(
        'This publishing path currently accepts one video. Multi-media and image publishing remain draft-ready until the existing post schema is extended.',
      );
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
        final existingStatus = (data['mediaProcessingStatus'] as String? ?? '').toLowerCase();
        final existingProvider = (data['mediaProvider'] as String? ?? '').toLowerCase();
        final processing = existingProvider == 'azure' && existingStatus != 'ready' && existingStatus != 'published';
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
      'allowComments': allowComments,
      'mediaProvider': _azureMedia.isConfigured ? 'azure' : 'firebase',
      'mediaStoragePath': storagePath,
      'mediaProcessingStatus': _azureMedia.isConfigured ? 'queued' : 'uploaded',
      'mediaProcessingVersion': 1,
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
      },
    );
    await CreationProjectStore.instance.save(published);
    await _saveState(project.projectId, processing ? CreationPublishStage.processing : CreationPublishStage.published, requestId: publishRequestId, bytesUploaded: asset.sizeBytes, totalBytes: asset.sizeBytes);

    return CreationPublishResult(postId: postRef.id, mediaUrl: downloadUrl, isProcessing: processing);
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
