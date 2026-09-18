import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/media_hash_service.dart';
import '../../services/reel_lifecycle_service.dart';
import '../../services/video_compression_service.dart';
import '../models/creation_project.dart';
import 'creation_metadata_pipeline_service.dart';
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

class _PreparedUploadMedia {
  const _PreparedUploadMedia({required this.file, required this.compression});

  final File file;
  final Map<String, dynamic> compression;
}

class CreationPublishService {
  CreationPublishService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    CreationAzureMediaService? azureMedia,
    ReelLifecycleService? lifecycle,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _azureMedia = azureMedia ?? CreationAzureMediaService(auth: auth),
        _lifecycle = lifecycle ?? ReelLifecycleService(auth: auth);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final CreationAzureMediaService _azureMedia;
  final ReelLifecycleService _lifecycle;

  Future<CreationPublishResult> publish(CreationProject project) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != project.ownerId) throw const CreationPublishException('Please sign in again before posting.');

    final validation = await CreationValidationService.validateProject(project, requirePublishRights: true);
    if (!validation.isValid) throw CreationPublishException(validation.message);
    if (project.mediaAssets.length != 1 || project.mediaAssets.first.type != 'video') {
      throw const CreationPublishException('This publishing path currently accepts one video. Multi-media and image publishing remain draft-ready.');
    }

    final publishState = project.publishState;
    final editOfPostId = publishState['editOfPostId'] is String ? (publishState['editOfPostId'] as String).trim() : '';
    final isExistingEdit = editOfPostId.isNotEmpty && editOfPostId == project.projectId;
    if (isExistingEdit && !_azureMedia.isConfigured) {
      throw const CreationPublishException('Published Show editing requires the OJAS Azure media pipeline.');
    }
    if (project.audio.isNotEmpty && !_azureMedia.isConfigured) {
      throw const CreationPublishException('Audio tracks require the server media processor. Configure the OJAS Azure media broker before publishing audio edits.');
    }

    final asset = project.mediaAssets.first;
    final postRef = _firestore.collection('reels').doc(project.projectId);
    final publishRequestId = publishState['publishRequestId'] as String? ?? 'creation:${project.projectId}';
    final allowComments = publishState['allowComments'] is bool ? publishState['allowComments'] as bool : true;
    final recommendRequested = publishState['recommend'] is bool ? publishState['recommend'] as bool : true;
    final isPublic = project.privacy.toLowerCase() == 'public';
    final recommendationEligible = isPublic && recommendRequested;
    final reusePolicy = publishState['reusePolicy'] is String && (publishState['reusePolicy'] as String).trim().isNotEmpty
        ? (publishState['reusePolicy'] as String).trim().toLowerCase()
        : 'allowed';

    final existingSnapshot = await postRef.get();
    final existingData = existingSnapshot.data() ?? const <String, dynamic>{};
    if (existingSnapshot.exists && existingData['creatorId'] != user.uid) {
      throw const CreationPublishException('You cannot replace another creator\'s Show.');
    }

    if (existingSnapshot.exists && !isExistingEdit) {
      final existingUrl = existingData['videoUrl'] as String? ?? '';
      if (existingUrl.isNotEmpty) {
        final status = (existingData['mediaProcessingStatus'] as String? ?? '').toLowerCase();
        final provider = (existingData['mediaProvider'] as String? ?? '').toLowerCase();
        final processing = provider == 'azure' && status != 'ready' && status != 'published';
        await _saveState(project.projectId, processing ? CreationPublishStage.processing : CreationPublishStage.published, requestId: publishRequestId);
        return CreationPublishResult(postId: postRef.id, mediaUrl: existingUrl, isProcessing: processing);
      }
    }

    await _saveState(project.projectId, CreationPublishStage.validating, requestId: publishRequestId);
    await _saveState(project.projectId, CreationPublishStage.preparing, requestId: publishRequestId);
    final prepared = await _prepareUploadMedia(
      project: project,
      asset: asset,
      publishState: publishState,
      requestId: publishRequestId,
    );
    final uploadFile = prepared.file;
    final compression = prepared.compression;
    final uploadBytes = await uploadFile.length();
    if (uploadBytes <= 0) {
      throw const CreationPublishException('Prepared video is empty. Please try again.');
    }

    String downloadUrl;
    String? storagePath;

    if (_azureMedia.isConfigured) {
      final uploadFingerprint = '${uploadFile.path}|$uploadBytes';
      final localUploadState = await CreationPublishStateStore.instance.load(project.projectId);
      final checkpointMatches = localUploadState != null &&
          localUploadState.requestId == publishRequestId &&
          localUploadState.uploadSourceFingerprint == uploadFingerprint &&
          localUploadState.uploadTotalBytes == uploadBytes;
      final resumeBytes = checkpointMatches ? localUploadState.uploadBytes : 0;
      final resumeStoragePath = checkpointMatches ? localUploadState.uploadStoragePath : null;

      await _saveState(
        project.projectId,
        CreationPublishStage.uploading,
        requestId: publishRequestId,
        bytesUploaded: resumeBytes,
        totalBytes: uploadBytes,
        uploadStoragePath: resumeStoragePath,
        uploadSourceFingerprint: uploadFingerprint,
        uploadBytes: resumeBytes,
        uploadTotalBytes: uploadBytes,
        uploadBlockSize: CreationAzureMediaService.chunkSize,
      );

      final azureResult = await _azureMedia.uploadVideo(
        projectId: project.projectId,
        assetId: asset.assetId,
        localPath: uploadFile.path,
        contentType: 'video/mp4',
        deferProcessing: true,
        resumeBytes: resumeBytes,
        resumeStoragePath: resumeStoragePath,
        onCheckpoint: (uploaded, total, checkpointStoragePath) async {
          await _saveState(
            project.projectId,
            CreationPublishStage.uploading,
            requestId: publishRequestId,
            bytesUploaded: uploaded,
            totalBytes: total,
            uploadStoragePath: checkpointStoragePath,
            uploadSourceFingerprint: uploadFingerprint,
            uploadBytes: uploaded,
            uploadTotalBytes: total,
            uploadBlockSize: CreationAzureMediaService.chunkSize,
          );
        },
      );
      if (azureResult == null) throw const CreationPublishException('Azure media service returned no upload result.');
      downloadUrl = azureResult.mediaUrl;
      storagePath = azureResult.storagePath;
    } else {
      final storageReference = _storage.ref().child('reels').child(user.uid).child('${project.projectId}.mp4');
      await _saveState(project.projectId, CreationPublishStage.uploading, requestId: publishRequestId, totalBytes: uploadBytes);
      final uploadTask = await storageReference.putFile(File(uploadFile.path), SettableMetadata(contentType: 'video/mp4'));
      downloadUrl = await uploadTask.ref.getDownloadURL();
      storagePath = storageReference.fullPath;
      await _saveState(project.projectId, CreationPublishStage.uploading, requestId: publishRequestId, bytesUploaded: uploadBytes, totalBytes: uploadBytes);
    }

    await _saveState(project.projectId, CreationPublishStage.processing, requestId: publishRequestId, bytesUploaded: uploadBytes, totalBytes: uploadBytes);
    final mediaHash = await _computeMediaHash(uploadFile.path);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(mediaHash)) {
      throw const CreationPublishException('Could not calculate a valid media hash. Please try again.');
    }
    final editGraph = await _prepareEditGraph(project);
    final metadata = CreationMetadataPipelineService.build(project);
    await _saveState(project.projectId, CreationPublishStage.publishing, requestId: publishRequestId);

    final reuseSourcePostId = publishState['reuseSourcePostId'] as String?;
    final reuseSourceCreatorId = publishState['reuseSourceCreatorId'] as String?;
    final reuseRequestId = publishState['reuseRequestId'] as String?;

    if (isExistingEdit) {
      await _lifecycle.replacePublishedMedia(
        postId: postRef.id,
        mediaAssetId: asset.assetId,
        videoUrl: downloadUrl,
        mediaStoragePath: storagePath,
        contentLength: uploadBytes,
        mediaHash: mediaHash,
        editGraph: editGraph,
        caption: project.caption,
        visibility: project.privacy.toLowerCase(),
        allowComments: allowComments,
        recommendationEligible: recommendationEligible,
        reusePolicy: reusePolicy,
        aiGeneratedDisclosure: project.rights['aiGeneratedDisclosure'] == true,
        copyrightConfirmed: project.rights['copyrightConfirmed'] == true,
        hashtags: metadata.hashtags,
        mentions: metadata.mentions,
        shopItemIds: metadata.shopItemIds,
        searchTokens: metadata.searchTokens,
        audioTrackId: metadata.audioTrackId,
        audioMetadata: metadata.audioMetadata,
        location: metadata.location,
      );
    } else {
      final payload = <String, dynamic>{
        'creatorId': user.uid,
        'projectId': project.projectId,
        'mediaAssetId': asset.assetId,
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
        'reusePolicy': reusePolicy,
        'mediaProvider': _azureMedia.isConfigured ? 'azure' : 'firebase',
        'mediaStoragePath': storagePath,
        'mediaProcessingStatus': _azureMedia.isConfigured ? 'queued' : 'uploaded',
        'mediaProcessingVersion': 4,
        'mediaProcessingMode': _azureMedia.isConfigured ? 'device-delivery-validate' : 'device-delivery-local',
        'editGraphVersion': 2,
        'editGraph': editGraph,
        'deviceCompressed': compression['applied'] == true,
        'deviceDeliveryReady': compression['deliveryReady'] == true,
        'deviceCompressionProfile': compression['profile'],
        'deviceOriginalBytes': compression['originalBytes'],
        'deviceUploadBytes': compression['uploadBytes'],
        'deviceCompressionRatio': compression['ratio'],
        'aiGeneratedDisclosure': project.rights['aiGeneratedDisclosure'] == true,
        'copyrightConfirmed': project.rights['copyrightConfirmed'] == true,
        'mediaHash': mediaHash,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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
        'shopItemIds': metadata.shopItemIds,
        'algorithmScore': 0.0,
        'audioTrackId': metadata.audioTrackId,
        'hashtags': metadata.hashtags,
        'mentions': metadata.mentions,
        'audioMetadata': metadata.audioMetadata,
        'location': metadata.location,
        'searchTokens': metadata.searchTokens,
        if (reuseRequestId != null && reuseRequestId.trim().isNotEmpty) 'reuseRequestId': reuseRequestId.trim(),
        if (reuseSourcePostId != null && reuseSourcePostId.trim().isNotEmpty) 'reusedFromPostId': reuseSourcePostId.trim(),
        if (reuseSourceCreatorId != null && reuseSourceCreatorId.trim().isNotEmpty) 'reusedFromCreatorId': reuseSourceCreatorId.trim(),
      };
      await postRef.set(payload, SetOptions(merge: false));
    }

    if (_azureMedia.isConfigured) {
      await _markCreationMediaQueued(
        assetId: asset.assetId,
        projectId: project.projectId,
        ownerId: user.uid,
        storagePath: storagePath,
        contentLength: uploadBytes,
        deviceCompressed: compression['applied'] == true,
        deviceDeliveryReady: compression['deliveryReady'] == true,
      );
    }

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
        'reusePolicy': reusePolicy,
        'processingStatus': processing ? 'queued' : 'uploaded',
        'pipelineMetadata': metadata.toMap(),
        'mediaHash': mediaHash,
        'editGraphVersion': 2,
        'mediaAssetId': asset.assetId,
        'preparedMediaPath': uploadFile.path,
        'mediaCompression': compression,
        if (isExistingEdit) 'editOfPostId': project.projectId,
      },
    );
    await CreationProjectStore.instance.save(published);
    await _saveState(project.projectId, processing ? CreationPublishStage.processing : CreationPublishStage.published, bytesUploaded: uploadBytes, totalBytes: uploadBytes, requestId: publishRequestId);

    return CreationPublishResult(postId: postRef.id, mediaUrl: downloadUrl, isProcessing: processing);
  }

  Future<_PreparedUploadMedia> _prepareUploadMedia({
    required CreationProject project,
    required CreationMediaAsset asset,
    required Map<String, dynamic> publishState,
    required String requestId,
  }) async {
    final sourceFile = File(asset.localUri);
    if (!await sourceFile.exists()) {
      throw const CreationPublishException('Selected video is no longer available.');
    }
    final sourceBytes = await sourceFile.length();
    final sourceModifiedMs = (await sourceFile.stat()).modified.millisecondsSinceEpoch;
    if (sourceBytes <= 0) {
      throw const CreationPublishException('Selected video is empty.');
    }

    final storedPath = publishState['preparedMediaPath'] is String ? (publishState['preparedMediaPath'] as String).trim() : '';
    final storedCompressionRaw = publishState['mediaCompression'];
    if (storedPath.isNotEmpty && storedCompressionRaw is Map) {
      final storedCompression = Map<String, dynamic>.from(storedCompressionRaw);
      final sameSource = storedCompression['sourcePath'] == asset.localUri &&
          storedCompression['sourceBytes'] == sourceBytes &&
          storedCompression['sourceModifiedMs'] == sourceModifiedMs;
      if (sameSource) {
        final cached = File(storedPath);
        if (await cached.exists() && await cached.length() > 0) {
          return _PreparedUploadMedia(file: cached, compression: storedCompression);
        }
      }
    }

    final result = await VideoCompressionService.instance.prepareForUpload(
      XFile(sourceFile.path),
      projectId: project.projectId,
      assetId: asset.assetId,
      onProgress: (progress) {
        final bounded = progress.clamp(0.0, 1.0).toDouble();
        _saveState(
          project.projectId,
          CreationPublishStage.preparing,
          requestId: requestId,
          bytesUploaded: (sourceBytes * bounded).round(),
          totalBytes: sourceBytes,
        );
      },
    );
    final preparedFile = File(result.file.path);
    if (!await preparedFile.exists() || await preparedFile.length() <= 0) {
      throw const CreationPublishException('Device did not produce a usable delivery video.');
    }

    final compression = <String, dynamic>{
      'applied': result.compressionApplied,
      'deliveryReady': result.deliveryReady,
      'profile': result.profileName,
      'originalBytes': result.originalBytes,
      'uploadBytes': result.compressedBytes,
      'ratio': double.parse(result.compressionRatio.toStringAsFixed(6)),
      'sourcePath': asset.localUri,
      'sourceBytes': sourceBytes,
      'sourceModifiedMs': sourceModifiedMs,
      'sourceWidth': result.sourceWidth,
      'sourceHeight': result.sourceHeight,
      'outputWidth': result.outputWidth,
      'outputHeight': result.outputHeight,
      'durationMs': result.durationMs,
      'engine': 'device-video-compress-3.1.4',
      'version': 3,
    };

    final checkpointed = project.copyWith(
      publishState: <String, dynamic>{
        ...publishState,
        'preparedMediaPath': preparedFile.path,
        'mediaCompression': compression,
      },
    );
    await CreationProjectStore.instance.save(checkpointed);

    return _PreparedUploadMedia(file: preparedFile, compression: compression);
  }

  Future<void> _markCreationMediaQueued({
    required String assetId,
    required String projectId,
    required String ownerId,
    required String storagePath,
    required int contentLength,
    required bool deviceCompressed,
    required bool deviceDeliveryReady,
  }) async {
    if (storagePath.isEmpty) throw const CreationPublishException('Media storage path is missing.');
    await _firestore.collection('creationMedia').doc(assetId).set(<String, dynamic>{
      'assetId': assetId,
      'projectId': projectId,
      'ownerId': ownerId,
      'storagePath': storagePath,
      'contentLength': contentLength,
      'contentType': 'video/mp4',
      'deviceCompressed': deviceCompressed,
      'deviceDeliveryReady': deviceDeliveryReady,
      'status': 'uploaded',
      'processingStatus': 'queued',
      'queuedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> _prepareEditGraph(CreationProject project) async {
    List<Map<String, dynamic>> bounded(List<Map<String, dynamic>> input, int maxItems) => input.take(maxItems).map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
    final timeline = project.timeline.take(32).map((clip) => clip.toMap()).toList(growable: false);
    final audioLayers = <Map<String, dynamic>>[];

    for (final raw in project.audio.take(32)) {
      final layer = Map<String, dynamic>.from(raw);
      final rawUri = layer['uri'];
      final localUri = rawUri is String ? rawUri.trim() : '';
      final existingStoragePath = layer['storagePath'] is String ? (layer['storagePath'] as String).trim() : '';
      final layerId = layer['id'] is String && (layer['id'] as String).trim().isNotEmpty ? (layer['id'] as String).trim() : 'audio_${DateTime.now().microsecondsSinceEpoch}';

      if (existingStoragePath.startsWith('creation-audio/')) {
        layer
          ..remove('uri')
          ..['storagePath'] = existingStoragePath
          ..['storageProvider'] = 'azure'
          ..['id'] = layerId;
        audioLayers.add(layer);
        continue;
      }

      if (localUri.isEmpty) throw CreationPublishException('Audio file is missing: ${layer['title'] ?? layerId}.');
      final file = File(localUri);
      if (!await file.exists()) throw CreationPublishException('Audio file is no longer available: ${layer['title'] ?? layerId}.');
      final size = await file.length();
      if (size <= 0 || size > CreationAzureMediaService.maxAudioBytes) throw const CreationPublishException('Each creation audio track must be between 1 byte and 10 MB.');

      final fileName = localUri.split(RegExp(r'[\\/]')).last;
      final extensionIndex = fileName.lastIndexOf('.');
      final extension = extensionIndex >= 0 && extensionIndex < fileName.length - 1 ? fileName.substring(extensionIndex).toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]'), '') : '.bin';
      final safeExtension = extension.length <= 8 ? extension : '.bin';
      final contentType = _audioContentType(safeExtension);
      if (contentType == 'audio/*') throw const CreationPublishException('Unsupported audio format. Use MP3, M4A, WAV, AAC, OGG, or OPUS.');

      final azureAudio = await _azureMedia.uploadAudio(projectId: project.projectId, layerId: layerId, localPath: localUri, blobName: '$layerId$safeExtension', contentType: contentType);
      if (azureAudio == null) throw const CreationPublishException('Azure media service returned no audio upload result.');

      layer
        ..remove('uri')
        ..['storagePath'] = azureAudio.storagePath
        ..['storageProvider'] = 'azure'
        ..['id'] = layerId
        ..['sizeBytes'] = size;
      audioLayers.add(layer);
    }

    return <String, dynamic>{
      'version': 2,
      'timeline': timeline,
      'audio': audioLayers,
      'audioStorageProvider': 'azure',
      'textLayers': bounded(project.textLayers, 64),
      'stickerLayers': bounded(project.stickerLayers, 64),
      'effectLayers': bounded(project.effectLayers, 32),
      'operations': bounded(project.operations, 256),
      'accessibility': Map<String, dynamic>.from(project.accessibility),
    };
  }

  String _audioContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.mp3': return 'audio/mpeg';
      case '.wav': return 'audio/wav';
      case '.m4a': return 'audio/mp4';
      case '.aac': return 'audio/aac';
      case '.ogg': return 'audio/ogg';
      case '.opus': return 'audio/opus';
      default: return 'audio/*';
    }
  }

  Future<void> _saveState(
    String projectId,
    CreationPublishStage stage, {
    String? requestId,
    int bytesUploaded = 0,
    int totalBytes = 0,
    String? uploadStoragePath,
    String? uploadSourceFingerprint,
    int uploadBytes = 0,
    int uploadTotalBytes = 0,
    int uploadBlockSize = 0,
  }) async {
    try {
      await CreationPublishStateStore.instance.save(
        CreationPublishState(
          projectId: projectId,
          stage: stage,
          requestId: requestId,
          bytesUploaded: bytesUploaded,
          totalBytes: totalBytes,
          updatedAt: DateTime.now(),
          uploadStoragePath: uploadStoragePath,
          uploadSourceFingerprint: uploadSourceFingerprint,
          uploadBytes: uploadBytes,
          uploadTotalBytes: uploadTotalBytes,
          uploadBlockSize: uploadBlockSize,
        ),
      );
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
