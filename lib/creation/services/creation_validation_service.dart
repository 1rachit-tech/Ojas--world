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

    final renderedPath = project.renderedUri;
    if (renderedPath != null && renderedPath.isNotEmpty) {
      final renderedFile = File(renderedPath);
      if (!await renderedFile.exists()) {
        errors.add('The final rendered video is no longer available.');
      } else if (await renderedFile.length() <= 0) {
        errors.add('The final rendered video is empty or corrupt.');
      } else if (await renderedFile.length() > 50 * 1024 * 1024) {
        errors.add('The final rendered video is larger than the current 50 MB upload limit.');
      }
    } else {
      for (final asset in project.mediaAssets) {
        if (asset.localUri.isEmpty) {
          errors.add('A media asset has no source file.');
          continue;
        }
  
        final normalized = asset.normalizedUri;
        final normalizedFile = normalized == null || normalized.isEmpty
            ? null
            : File(normalized);
        final file = normalizedFile != null && await normalizedFile.exists()
            ? normalizedFile
            : File(asset.localUri);
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
