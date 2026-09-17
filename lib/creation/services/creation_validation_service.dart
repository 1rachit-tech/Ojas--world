import 'dart:io';

import '../models/creation_project.dart';

class CreationValidationResult {
  const CreationValidationResult({
    required this.isValid,
    this.errors = const <String>[],
  });

  final bool isValid;
  final List<String> errors;

  String get message => errors.isEmpty ? '' : errors.join('\n');
}

class CreationValidationService {
  const CreationValidationService._();

  static const int maxVideoBytes = 512 * 1024 * 1024;
  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxTimelineClips = 32;
  static const int maxOperations = 256;
  static const int maxTextLayers = 64;
  static const int maxAudioLayers = 32;
  static const int maxStickerLayers = 64;
  static const int maxEffectLayers = 32;

  static const Set<String> supportedVideoMimeTypes = <String>{
    'video/mp4',
    'video/quicktime',
    'video/webm',
    'video/x-m4v',
    'video/*',
  };

  static const Set<String> supportedImageMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/*',
  };

  static Future<CreationValidationResult> validateProject(
    CreationProject project, {
    bool requirePublishRights = false,
  }) async {
    final errors = <String>[];

    if (project.ownerId.isEmpty) errors.add('You must be signed in to create content.');
    if (project.projectId.isEmpty) errors.add('Creation project is missing an ID.');
    if (project.mediaAssets.isEmpty) errors.add('Add at least one photo or video.');
    if (project.timeline.length > maxTimelineClips) errors.add('The timeline contains too many clips.');
    if (project.operations.length > maxOperations) errors.add('The edit history is too large. Please save a fresh checkpoint.');
    if (project.textLayers.length > maxTextLayers) errors.add('Too many text/caption layers.');
    if (project.audio.length > maxAudioLayers) errors.add('Too many audio layers.');
    if (project.stickerLayers.length > maxStickerLayers) errors.add('Too many sticker layers.');
    if (project.effectLayers.length > maxEffectLayers) errors.add('Too many effect layers.');

    for (final asset in project.mediaAssets) {
      if (asset.assetId.isEmpty) errors.add('A media asset is missing its ID.');
      if (asset.localUri.isEmpty) {
        errors.add('A media asset has no source file.');
        continue;
      }

      final file = File(asset.localUri);
      if (!await file.exists()) {
        errors.add('A selected media file is no longer available.');
        continue;
      }

      final size = await file.length();
      if (size <= 0) errors.add('A selected media file is empty or corrupt.');

      if (asset.type == 'video') {
        if (size > maxVideoBytes) errors.add('A video is larger than the current 512 MB creation limit.');
        if (!supportedVideoMimeTypes.contains(asset.mimeType)) errors.add('This video format is not supported for creation uploads.');
        if ((asset.width != null && asset.width! <= 0) || (asset.height != null && asset.height! <= 0)) errors.add('Video dimensions are invalid.');
        if (asset.durationMs != null && asset.durationMs! <= 0) errors.add('Video duration is invalid.');
      } else if (asset.type == 'image') {
        if (size > maxImageBytes) errors.add('An image is larger than the current 10 MB creation limit.');
        if (!supportedImageMimeTypes.contains(asset.mimeType)) errors.add('This image format is not supported for creation uploads.');
      } else {
        errors.add('Unsupported creation media type: ${asset.type}.');
      }
    }

    if (project.caption.length > 2200) errors.add('Caption cannot exceed 2200 characters.');

    final knownAssetIds = project.mediaAssets.map((asset) => asset.assetId).toSet();
    for (final clip in project.timeline) {
      if (clip.clipId.trim().isEmpty) errors.add('Timeline contains a clip without an ID.');
      if (clip.endMs <= clip.startMs) errors.add('Timeline contains an invalid clip range.');
      if (clip.sourceId.isEmpty || !knownAssetIds.contains(clip.sourceId)) errors.add('Timeline contains a clip without a valid source asset.');
      if (clip.trimInMs < 0 || (clip.trimOutMs != null && clip.trimOutMs! <= clip.trimInMs)) errors.add('Timeline contains an invalid trim range.');
      if (clip.speed < 0.25 || clip.speed > 4.0) errors.add('Timeline contains an unsupported speed value.');
      if (clip.scale < 0.1 || clip.scale > 5.0) errors.add('Timeline contains an unsupported scale value.');
      if (clip.opacity < 0.0 || clip.opacity > 1.0) errors.add('Timeline contains an invalid opacity value.');
      if (clip.rotation.isNaN || clip.rotation.isInfinite) errors.add('Timeline contains an invalid rotation value.');
      final normalizedRotation = clip.rotation % 90;
      if ((normalizedRotation.abs() > 0.01) && ((90 - normalizedRotation.abs()).abs() > 0.01)) {
        errors.add('Timeline rotation must use 90° increments.');
      }
      if (clip.x < -1.0 || clip.x > 1.0 || clip.y < -1.0 || clip.y > 1.0) {
        errors.add('Timeline transform position is outside the supported range.');
      }
      if (clip.cropLeft < 0 || clip.cropTop < 0 || clip.cropRight < 0 || clip.cropBottom < 0 ||
          clip.cropLeft + clip.cropRight >= 1.0 || clip.cropTop + clip.cropBottom >= 1.0) {
        errors.add('Timeline contains an invalid crop rectangle.');
      }

      final source = project.mediaAssets.where((asset) => asset.assetId == clip.sourceId).firstOrNull;
      final sourceDuration = source?.durationMs;
      if (sourceDuration != null) {
        if (clip.trimInMs >= sourceDuration) errors.add('Timeline trim starts beyond the source duration.');
        if (clip.trimOutMs != null && clip.trimOutMs! > sourceDuration) errors.add('Timeline trim ends beyond the source duration.');
      }
    }

    if (project.timeline.isEmpty && project.mediaAssets.isNotEmpty) errors.add('Timeline must contain at least one clip.');

    _validateTimedLayers(project, errors);
    _validateRights(project, errors);

    if (requirePublishRights) {
      if (project.rights['copyrightConfirmed'] != true) {
        errors.add('Confirm that you have the rights to publish this media.');
      }
      if (project.privacy.trim().isEmpty) errors.add('Choose an audience before publishing.');
      if (project.publishState['allowComments'] is! bool) errors.add('Comment policy is missing.');
      if (project.publishState['recommend'] is! bool) errors.add('Recommendation preference is missing.');
    }

    return CreationValidationResult(
      isValid: errors.isEmpty,
      errors: List<String>.unmodifiable(errors),
    );
  }

  static void _validateTimedLayers(CreationProject project, List<String> errors) {
    for (final layer in project.textLayers) {
      _validateLayerTiming(layer, errors, 'text/caption');
      _validateTextLength(layer, errors, 'text/caption');
    }
    for (final layer in project.audio) {
      _validateLayerTiming(layer, errors, 'audio');
      final volume = _doubleValue(layer['volume']);
      if (volume != null && (volume < 0 || volume > 2)) errors.add('Audio layer volume is outside the supported range.');
      if (layer['uri'] is! String || (layer['uri'] as String).trim().isEmpty) errors.add('An audio layer is missing its source URI.');
    }
    for (final layer in project.stickerLayers) {
      final scale = _doubleValue(layer['scale']);
      final x = _doubleValue(layer['x']);
      final y = _doubleValue(layer['y']);
      if (scale != null && (scale < 0.1 || scale > 5)) errors.add('Sticker scale is outside the supported range.');
      if (x != null && (x < -1 || x > 1) || y != null && (y < -1 || y > 1)) errors.add('Sticker position is outside the supported range.');
    }
    for (final layer in project.effectLayers) {
      final intensity = _doubleValue(layer['intensity']);
      if (layer['effectId'] is! String || (layer['effectId'] as String).trim().isEmpty) errors.add('An effect layer is missing its ID.');
      if (intensity != null && (intensity < 0 || intensity > 1)) errors.add('Effect intensity is outside the supported range.');
    }
  }

  static void _validateLayerTiming(Map<String, dynamic> layer, List<String> errors, String label) {
    final start = _intValue(layer['startMs']);
    final end = _intValue(layer['endMs']);
    if (start == null || end == null || start < 0 || end <= start) {
      errors.add('$label layer has invalid timing.');
    } else if (end > 86400000) {
      errors.add('$label layer exceeds the supported duration window.');
    }
  }

  static void _validateTextLength(Map<String, dynamic> layer, List<String> errors, String label) {
    final text = layer['text'];
    if (text is String && text.length > 5000) errors.add('$label content is too long.');
  }

  static void _validateRights(CreationProject project, List<String> errors) {
    final disclosure = project.rights['aiGeneratedDisclosure'];
    if (disclosure is! bool && disclosure != null) errors.add('AI-generated disclosure must be boolean.');
    final confirmed = project.rights['copyrightConfirmed'];
    if (confirmed is! bool && confirmed != null) errors.add('Copyright confirmation must be boolean.');
  }

  static int? _intValue(dynamic value) => value is num ? value.toInt() : null;

  static double? _doubleValue(dynamic value) => value is num ? value.toDouble() : null;
}
