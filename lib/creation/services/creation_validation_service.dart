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

  static Future<CreationValidationResult> validateProject(
    CreationProject project,
  ) async {
    final errors = <String>[];

    if (project.ownerId.isEmpty) {
      errors.add('You must be signed in to create content.');
    }
    if (project.projectId.isEmpty) {
      errors.add('Creation project is missing an ID.');
    }
    if (project.mediaAssets.isEmpty) {
      errors.add('Add at least one photo or video.');
    }

    for (final asset in project.mediaAssets) {
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
      if (size <= 0) {
        errors.add('A selected media file is empty or corrupt.');
      }

      if (asset.type == 'video' && size > 50 * 1024 * 1024) {
        errors.add('A video is larger than the current 50 MB upload limit.');
      }
      if (asset.type == 'image' && size > 10 * 1024 * 1024) {
        errors.add('An image is larger than the current 10 MB upload limit.');
      }
    }

    if (project.caption.length > 2200) {
      errors.add('Caption cannot exceed 2200 characters.');
    }

    if (project.timeline.any((clip) => clip.endMs < clip.startMs)) {
      errors.add('Timeline contains an invalid clip range.');
    }

    return CreationValidationResult(
      isValid: errors.isEmpty,
      errors: List<String>.unmodifiable(errors),
    );
  }
}
