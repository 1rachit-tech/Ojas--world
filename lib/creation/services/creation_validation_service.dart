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
      if (clip.endMs < clip.startMs) errors.add('Timeline contains an invalid clip range.');
      if (clip.sourceId.isEmpty || !knownAssetIds.contains(clip.sourceId)) errors.add('Timeline contains a clip without a valid source asset.');
      if (clip.trimInMs < 0 || (clip.trimOutMs != null && clip.trimOutMs! <= clip.trimInMs)) errors.add('Timeline contains an invalid trim range.');
      if (clip.speed < 0.25 || clip.speed > 4.0) errors.add('Timeline contains an unsupported speed value.');
      if (clip.scale < 0.1 || clip.scale > 5.0) errors.add('Timeline contains an unsupported scale value.');
      if (clip.opacity < 0.0 || clip.opacity > 1.0) errors.add('Timeline contains an invalid opacity value.');
    }

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
}
