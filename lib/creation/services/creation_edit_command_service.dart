import '../models/creation_project.dart';

class CreationEditCommandService {
  const CreationEditCommandService();

  CreationProject trimClip(
    CreationProject project, {
    required String clipId,
    required int trimInMs,
    required int trimOutMs,
  }) {
    return _updateClip(
      project,
      clipId,
      (clip) => CreationTimelineClip(
        clipId: clip.clipId,
        sourceId: clip.sourceId,
        startMs: clip.startMs,
        endMs: clip.endMs,
        trimInMs: trimInMs.clamp(0, _sourceDuration(project, clip.sourceId)),
        trimOutMs: trimOutMs > trimInMs ? trimOutMs : trimInMs + 1,
        speed: clip.speed,
        opacity: clip.opacity,
        rotation: clip.rotation,
        scale: clip.scale,
        x: clip.x,
        y: clip.y,
      ),
      operation: <String, dynamic>{'type': 'trim', 'clipId': clipId, 'trimInMs': trimInMs, 'trimOutMs': trimOutMs},
    );
  }

  CreationProject splitClip(
    CreationProject project, {
    required String clipId,
    required int splitAtMs,
  }) {
    final index = project.timeline.indexWhere((clip) => clip.clipId == clipId);
    if (index < 0) return project;
    final clip = project.timeline[index];
    final effectiveIn = clip.trimInMs;
    final effectiveOut = clip.trimOutMs ?? clip.endMs;
    if (splitAtMs <= effectiveIn || splitAtMs >= effectiveOut) return project;

    final left = CreationTimelineClip(
      clipId: '${clip.clipId}_a',
      sourceId: clip.sourceId,
      startMs: clip.startMs,
      endMs: splitAtMs,
      trimInMs: effectiveIn,
      trimOutMs: splitAtMs,
      speed: clip.speed,
      opacity: clip.opacity,
      rotation: clip.rotation,
      scale: clip.scale,
      x: clip.x,
      y: clip.y,
    );
    final right = CreationTimelineClip(
      clipId: '${clip.clipId}_b',
      sourceId: clip.sourceId,
      startMs: splitAtMs,
      endMs: clip.endMs,
      trimInMs: splitAtMs,
      trimOutMs: effectiveOut,
      speed: clip.speed,
      opacity: clip.opacity,
      rotation: clip.rotation,
      scale: clip.scale,
      x: clip.x,
      y: clip.y,
    );
    final timeline = <CreationTimelineClip>[
      ...project.timeline.take(index),
      left,
      right,
      ...project.timeline.skip(index + 1),
    ];
    return _finish(project.copyWith(timeline: timeline), <String, dynamic>{'type': 'split', 'clipId': clipId, 'splitAtMs': splitAtMs});
  }

  CreationProject setSpeed(
    CreationProject project, {
    required String clipId,
    required double speed,
  }) {
    final safeSpeed = speed.clamp(0.25, 4.0).toDouble();
    return _updateClip(
      project,
      clipId,
      (clip) => CreationTimelineClip(
        clipId: clip.clipId,
        sourceId: clip.sourceId,
        startMs: clip.startMs,
        endMs: clip.endMs,
        trimInMs: clip.trimInMs,
        trimOutMs: clip.trimOutMs,
        speed: safeSpeed,
        opacity: clip.opacity,
        rotation: clip.rotation,
        scale: clip.scale,
        x: clip.x,
        y: clip.y,
      ),
      operation: <String, dynamic>{'type': 'speed', 'clipId': clipId, 'speed': safeSpeed},
    );
  }

  CreationProject setTransform(
    CreationProject project, {
    required String clipId,
    double? rotation,
    double? scale,
    double? x,
    double? y,
    double? opacity,
  }) {
    return _updateClip(
      project,
      clipId,
      (clip) => CreationTimelineClip(
        clipId: clip.clipId,
        sourceId: clip.sourceId,
        startMs: clip.startMs,
        endMs: clip.endMs,
        trimInMs: clip.trimInMs,
        trimOutMs: clip.trimOutMs,
        speed: clip.speed,
        opacity: (opacity ?? clip.opacity).clamp(0.0, 1.0).toDouble(),
        rotation: rotation ?? clip.rotation,
        scale: (scale ?? clip.scale).clamp(0.1, 5.0).toDouble(),
        x: x ?? clip.x,
        y: y ?? clip.y,
      ),
      operation: <String, dynamic>{'type': 'transform', 'clipId': clipId, 'rotation': rotation, 'scale': scale, 'x': x, 'y': y, 'opacity': opacity},
    );
  }

  CreationProject addText(
    CreationProject project, {
    required String text,
    int startMs = 0,
    int? endMs,
    double x = 0,
    double y = 0,
    double fontSize = 28,
  }) {
    final layer = <String, dynamic>{
      'id': _nextLayerId('text'),
      'text': text.trim(),
      'startMs': startMs,
      'endMs': endMs,
      'x': x,
      'y': y,
      'fontSize': fontSize.clamp(8, 120),
    };
    return _finish(project.copyWith(textLayers: [...project.textLayers, layer]), <String, dynamic>{'type': 'text_add', 'layerId': layer['id']});
  }

  CreationProject addAudio(
    CreationProject project, {
    required String uri,
    String? title,
    int startMs = 0,
    int? endMs,
    double volume = 1.0,
  }) {
    final layer = <String, dynamic>{
      'id': _nextLayerId('audio'),
      'uri': uri,
      'title': title ?? 'Audio',
      'startMs': startMs,
      'endMs': endMs,
      'volume': volume.clamp(0.0, 2.0),
    };
    return _finish(project.copyWith(audio: [...project.audio, layer]), <String, dynamic>{'type': 'audio_add', 'layerId': layer['id']});
  }

  CreationProject addEffect(
    CreationProject project, {
    required String effectId,
    double intensity = 1.0,
  }) {
    final layer = <String, dynamic>{
      'id': _nextLayerId('effect'),
      'effectId': effectId,
      'intensity': intensity.clamp(0.0, 1.0),
    };
    return _finish(project.copyWith(effectLayers: [...project.effectLayers, layer]), <String, dynamic>{'type': 'effect_add', 'layerId': layer['id'], 'effectId': effectId});
  }

  CreationProject addSticker(
    CreationProject project, {
    required String stickerId,
    double x = 0,
    double y = 0,
    double scale = 1.0,
  }) {
    final layer = <String, dynamic>{
      'id': _nextLayerId('sticker'),
      'stickerId': stickerId,
      'x': x,
      'y': y,
      'scale': scale.clamp(0.1, 5.0),
    };
    return _finish(project.copyWith(stickerLayers: [...project.stickerLayers, layer]), <String, dynamic>{'type': 'sticker_add', 'layerId': layer['id'], 'stickerId': stickerId});
  }

  CreationProject setAccessibility(
    CreationProject project, {
    String? altText,
    bool? autoCaptions,
  }) {
    return _finish(
      project.copyWith(accessibility: <String, dynamic>{
        ...project.accessibility,
        if (altText != null) 'altText': altText.trim(),
        if (autoCaptions != null) 'autoCaptions': autoCaptions,
      }),
      <String, dynamic>{'type': 'accessibility_update'},
    );
  }

  CreationProject setRights(
    CreationProject project, {
    bool? copyrightConfirmed,
    bool? aiGeneratedDisclosure,
  }) {
    return _finish(
      project.copyWith(rights: <String, dynamic>{
        ...project.rights,
        if (copyrightConfirmed != null) 'copyrightConfirmed': copyrightConfirmed,
        if (aiGeneratedDisclosure != null) 'aiGeneratedDisclosure': aiGeneratedDisclosure,
      }),
      <String, dynamic>{'type': 'rights_update'},
    );
  }

  CreationProject _updateClip(
    CreationProject project,
    String clipId,
    CreationTimelineClip Function(CreationTimelineClip) update, {
    required Map<String, dynamic> operation,
  }) {
    var found = false;
    final timeline = project.timeline.map((clip) {
      if (clip.clipId != clipId) return clip;
      found = true;
      return update(clip);
    }).toList(growable: false);
    return found ? _finish(project.copyWith(timeline: timeline), operation) : project;
  }

  CreationProject _finish(CreationProject project, Map<String, dynamic> operation) {
    final nextVersion = project.version + 1;
    return project.copyWith(
      status: CreationProjectStatus.editing,
      version: nextVersion,
      updatedAt: DateTime.now(),
      operations: [
        ...project.operations,
        <String, dynamic>{...operation, 'version': nextVersion, 'at': DateTime.now().toIso8601String()},
      ],
    );
  }

  int _sourceDuration(CreationProject project, String sourceId) {
    for (final asset in project.mediaAssets) {
      if (asset.assetId == sourceId) return asset.durationMs ?? 0;
    }
    return 0;
  }

  String _nextLayerId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
}
