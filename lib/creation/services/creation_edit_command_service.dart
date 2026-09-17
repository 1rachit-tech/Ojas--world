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
      (clip) => _copyClip(
        clip,
        trimInMs: trimInMs.clamp(0, _sourceDuration(project, clip.sourceId)),
        trimOutMs: trimOutMs > trimInMs ? trimOutMs : trimInMs + 1,
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
    final effectiveIn = clip.effectiveStartMs;
    final effectiveOut = clip.effectiveEndMs;
    if (splitAtMs <= effectiveIn || splitAtMs >= effectiveOut) return project;

    final left = _copyClip(
      clip,
      clipId: '${clip.clipId}_a',
      startMs: clip.startMs,
      endMs: splitAtMs,
      trimInMs: effectiveIn,
      trimOutMs: splitAtMs,
    );
    final right = _copyClip(
      clip,
      clipId: '${clip.clipId}_b',
      startMs: splitAtMs,
      endMs: clip.endMs,
      trimInMs: splitAtMs,
      trimOutMs: effectiveOut,
    );
    final timeline = <CreationTimelineClip>[
      ...project.timeline.take(index),
      left,
      right,
      ...project.timeline.skip(index + 1),
    ];
    return _finish(
      project.copyWith(timeline: timeline),
      <String, dynamic>{'type': 'split', 'clipId': clipId, 'splitAtMs': splitAtMs},
    );
  }

  CreationProject deleteClip(
    CreationProject project, {
    required String clipId,
  }) {
    if (project.timeline.length <= 1) return project;
    final exists = project.timeline.any((clip) => clip.clipId == clipId);
    if (!exists) return project;
    return _finish(
      project.copyWith(
        timeline: project.timeline.where((clip) => clip.clipId != clipId).toList(growable: false),
      ),
      <String, dynamic>{'type': 'delete_clip', 'clipId': clipId},
    );
  }

  CreationProject reorderClip(
    CreationProject project, {
    required String clipId,
    required int toIndex,
  }) {
    final currentIndex = project.timeline.indexWhere((clip) => clip.clipId == clipId);
    if (currentIndex < 0 || project.timeline.length < 2) return project;
    final safeIndex = toIndex.clamp(0, project.timeline.length - 1);
    if (currentIndex == safeIndex) return project;
    final timeline = [...project.timeline];
    final clip = timeline.removeAt(currentIndex);
    timeline.insert(safeIndex, clip);
    return _finish(
      project.copyWith(timeline: timeline),
      <String, dynamic>{'type': 'reorder_clip', 'clipId': clipId, 'toIndex': safeIndex},
    );
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
      (clip) => _copyClip(clip, speed: safeSpeed),
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
      (clip) => _copyClip(
        clip,
        opacity: (opacity ?? clip.opacity).clamp(0.0, 1.0).toDouble(),
        rotation: rotation ?? clip.rotation,
        scale: (scale ?? clip.scale).clamp(0.1, 5.0).toDouble(),
        x: x ?? clip.x,
        y: y ?? clip.y,
      ),
      operation: <String, dynamic>{
        'type': 'transform',
        'clipId': clipId,
        'rotation': rotation,
        'scale': scale,
        'x': x,
        'y': y,
        'opacity': opacity,
      },
    );
  }

  CreationProject setCrop(
    CreationProject project, {
    required String clipId,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return _updateClip(
      project,
      clipId,
      (clip) => _copyClip(
        clip,
        cropLeft: (left ?? clip.cropLeft).clamp(0.0, 0.9).toDouble(),
        cropTop: (top ?? clip.cropTop).clamp(0.0, 0.9).toDouble(),
        cropRight: (right ?? clip.cropRight).clamp(0.0, 0.9).toDouble(),
        cropBottom: (bottom ?? clip.cropBottom).clamp(0.0, 0.9).toDouble(),
      ),
      operation: <String, dynamic>{
        'type': 'crop',
        'clipId': clipId,
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
      },
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
      'layerType': 'text',
      'text': text.trim(),
      'startMs': startMs.clamp(0, 86400000),
      'endMs': _safeEnd(startMs, endMs),
      'x': x,
      'y': y,
      'fontSize': fontSize.clamp(8, 120),
    };
    return _finish(project.copyWith(textLayers: [...project.textLayers, layer]), <String, dynamic>{'type': 'text_add', 'layerId': layer['id']});
  }

  CreationProject addCaption(
    CreationProject project, {
    required String text,
    required int startMs,
    required int endMs,
    double x = 0,
    double y = 0.72,
    double fontSize = 30,
    String style = 'default',
  }) {
    final safeStart = startMs.clamp(0, 86400000);
    final safeEnd = endMs.clamp(safeStart + 1, 86400000);
    final layer = <String, dynamic>{
      'id': _nextLayerId('caption'),
      'layerType': 'caption',
      'text': text.trim(),
      'startMs': safeStart,
      'endMs': safeEnd,
      'x': x,
      'y': y,
      'fontSize': fontSize.clamp(10, 120),
      'style': style.trim().isEmpty ? 'default' : style.trim(),
      'source': 'manual',
    };
    return _finish(project.copyWith(textLayers: [...project.textLayers, layer]), <String, dynamic>{'type': 'caption_add', 'layerId': layer['id']});
  }

  CreationProject setAutoCaptions(
    CreationProject project, {
    required bool enabled,
  }) {
    return setAccessibility(project, autoCaptions: enabled);
  }

  CreationProject updateTextLayer(
    CreationProject project, {
    required String layerId,
    String? text,
    int? startMs,
    int? endMs,
    double? x,
    double? y,
    double? fontSize,
  }) {
    final index = project.textLayers.indexWhere((layer) => layer['id'] == layerId);
    if (index < 0) return project;
    final current = project.textLayers[index];
    final safeStart = (startMs ?? (current['startMs'] as num?)?.toInt() ?? 0).clamp(0, 86400000);
    final safeEnd = (endMs ?? (current['endMs'] as num?)?.toInt() ?? safeStart + 1).clamp(safeStart + 1, 86400000);
    final nextLayer = <String, dynamic>{
      ...current,
      if (text != null) 'text': text.trim(),
      'startMs': safeStart,
      'endMs': safeEnd,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (fontSize != null) 'fontSize': fontSize.clamp(8, 120),
    };
    final layers = [...project.textLayers]..[index] = nextLayer;
    return _finish(project.copyWith(textLayers: layers), <String, dynamic>{'type': 'text_update', 'layerId': layerId});
  }

  CreationProject addAudio(
    CreationProject project, {
    required String uri,
    String? title,
    int startMs = 0,
    int? endMs,
    double volume = 1.0,
    bool muted = false,
  }) {
    final safeStart = startMs.clamp(0, 86400000);
    final layer = <String, dynamic>{
      'id': _nextLayerId('audio'),
      'uri': uri.trim(),
      'title': (title ?? 'Audio').trim().isEmpty ? 'Audio' : title!.trim(),
      'startMs': safeStart,
      'endMs': _safeEnd(safeStart, endMs),
      'volume': volume.clamp(0.0, 2.0),
      'muted': muted,
    };
    return _finish(project.copyWith(audio: [...project.audio, layer]), <String, dynamic>{'type': 'audio_add', 'layerId': layer['id']});
  }

  CreationProject updateAudio(
    CreationProject project, {
    required String layerId,
    String? title,
    int? startMs,
    int? endMs,
    double? volume,
    bool? muted,
  }) {
    final index = project.audio.indexWhere((layer) => layer['id'] == layerId);
    if (index < 0) return project;
    final current = project.audio[index];
    final safeStart = (startMs ?? (current['startMs'] as num?)?.toInt() ?? 0).clamp(0, 86400000);
    final safeEnd = (endMs ?? (current['endMs'] as num?)?.toInt() ?? safeStart + 1).clamp(safeStart + 1, 86400000);
    final nextLayer = <String, dynamic>{
      ...current,
      if (title != null) 'title': title.trim(),
      'startMs': safeStart,
      'endMs': safeEnd,
      if (volume != null) 'volume': volume.clamp(0.0, 2.0),
      if (muted != null) 'muted': muted,
    };
    final layers = [...project.audio]..[index] = nextLayer;
    return _finish(project.copyWith(audio: layers), <String, dynamic>{'type': 'audio_update', 'layerId': layerId});
  }

  CreationProject removeTextLayer(CreationProject project, {required String layerId}) {
    if (!project.textLayers.any((layer) => layer['id'] == layerId)) return project;
    return _finish(
      project.copyWith(textLayers: project.textLayers.where((layer) => layer['id'] != layerId).toList(growable: false)),
      <String, dynamic>{'type': 'text_remove', 'layerId': layerId},
    );
  }

  CreationProject removeAudioLayer(CreationProject project, {required String layerId}) {
    if (!project.audio.any((layer) => layer['id'] == layerId)) return project;
    return _finish(
      project.copyWith(audio: project.audio.where((layer) => layer['id'] != layerId).toList(growable: false)),
      <String, dynamic>{'type': 'audio_remove', 'layerId': layerId},
    );
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

  CreationTimelineClip _copyClip(
    CreationTimelineClip clip, {
    String? clipId,
    String? sourceId,
    int? startMs,
    int? endMs,
    int? trimInMs,
    int? trimOutMs,
    double? speed,
    double? opacity,
    double? rotation,
    double? scale,
    double? x,
    double? y,
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
  }) {
    return CreationTimelineClip(
      clipId: clipId ?? clip.clipId,
      sourceId: sourceId ?? clip.sourceId,
      startMs: startMs ?? clip.startMs,
      endMs: endMs ?? clip.endMs,
      trimInMs: trimInMs ?? clip.trimInMs,
      trimOutMs: trimOutMs ?? clip.trimOutMs,
      speed: speed ?? clip.speed,
      opacity: opacity ?? clip.opacity,
      rotation: rotation ?? clip.rotation,
      scale: scale ?? clip.scale,
      x: x ?? clip.x,
      y: y ?? clip.y,
      cropLeft: cropLeft ?? clip.cropLeft,
      cropTop: cropTop ?? clip.cropTop,
      cropRight: cropRight ?? clip.cropRight,
      cropBottom: cropBottom ?? clip.cropBottom,
    );
  }

  CreationProject _finish(CreationProject project, Map<String, dynamic> operation) {
    final nextVersion = project.version + 1;
    final now = DateTime.now();
    return project.copyWith(
      status: CreationProjectStatus.editing,
      version: nextVersion,
      updatedAt: now,
      operations: [
        ...project.operations,
        <String, dynamic>{
          ...operation,
          'version': nextVersion,
          'at': now.toIso8601String(),
        },
      ],
    );
  }

  int? _safeEnd(int startMs, int? endMs) {
    if (endMs == null) return null;
    return endMs.clamp(startMs + 1, 86400000);
  }

  int _sourceDuration(CreationProject project, String sourceId) {
    for (final asset in project.mediaAssets) {
      if (asset.assetId == sourceId) return asset.durationMs ?? 0;
    }
    return 0;
  }

  String _nextLayerId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
}
