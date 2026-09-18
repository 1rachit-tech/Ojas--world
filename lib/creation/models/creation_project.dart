import 'dart:convert';

import 'package:uuid/uuid.dart';

enum CreationType { post, show, story, remix, template }

enum CreationProjectStatus {
  newProject,
  editing,
  autosaved,
  ready,
  uploading,
  processing,
  scheduled,
  published,
  failed,
}

class CreationMediaAsset {
  const CreationMediaAsset({
    required this.assetId,
    required this.localUri,
    required this.type,
    required this.mimeType,
    required this.sizeBytes,
    this.width,
    this.height,
    this.durationMs,
    this.creationTime,
    this.orientation = 0,
    this.normalizedUri,
  });

  final String assetId;
  final String localUri;
  final String type;
  final String mimeType;
  final int sizeBytes;
  final int? width;
  final int? height;
  final int? durationMs;
  final DateTime? creationTime;
  final int orientation;
  final String? normalizedUri;

  CreationMediaAsset copyWith({
    String? localUri,
    String? mimeType,
    int? sizeBytes,
    int? width,
    int? height,
    int? durationMs,
    DateTime? creationTime,
    int? orientation,
    String? normalizedUri,
  }) {
    return CreationMediaAsset(
      assetId: assetId,
      localUri: localUri ?? this.localUri,
      type: type,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
      creationTime: creationTime ?? this.creationTime,
      orientation: orientation ?? this.orientation,
      normalizedUri: normalizedUri ?? this.normalizedUri,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'assetId': assetId,
        'localUri': localUri,
        'type': type,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'width': width,
        'height': height,
        'durationMs': durationMs,
        'creationTime': creationTime?.toIso8601String(),
        'orientation': orientation,
        'normalizedUri': normalizedUri,
      };

  factory CreationMediaAsset.fromMap(Map<String, dynamic> map) {
    return CreationMediaAsset(
      assetId: map['assetId'] as String? ?? '',
      localUri: map['localUri'] as String? ?? '',
      type: map['type'] as String? ?? 'unknown',
      mimeType: map['mimeType'] as String? ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      durationMs: (map['durationMs'] as num?)?.toInt(),
      creationTime: DateTime.tryParse(map['creationTime'] as String? ?? ''),
      orientation: (map['orientation'] as num?)?.toInt() ?? 0,
      normalizedUri: map['normalizedUri'] as String?,
    );
  }
}

class CreationTimelineClip {
  const CreationTimelineClip({
    required this.clipId,
    required this.sourceId,
    required this.startMs,
    required this.endMs,
    this.trimInMs = 0,
    this.trimOutMs,
    this.speed = 1.0,
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.scale = 1.0,
    this.x = 0.0,
    this.y = 0.0,
  });

  final String clipId;
  final String sourceId;
  final int startMs;
  final int endMs;
  final int trimInMs;
  final int? trimOutMs;
  final double speed;
  final double opacity;
  final double rotation;
  final double scale;
  final double x;
  final double y;

  CreationTimelineClip copyWith({
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
  }) {
    return CreationTimelineClip(
      clipId: clipId ?? this.clipId,
      sourceId: sourceId ?? this.sourceId,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      trimInMs: trimInMs ?? this.trimInMs,
      trimOutMs: trimOutMs ?? this.trimOutMs,
      speed: speed ?? this.speed,
      opacity: opacity ?? this.opacity,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'clipId': clipId,
        'sourceId': sourceId,
        'startMs': startMs,
        'endMs': endMs,
        'trimInMs': trimInMs,
        'trimOutMs': trimOutMs,
        'speed': speed,
        'opacity': opacity,
        'rotation': rotation,
        'scale': scale,
        'x': x,
        'y': y,
      };

  factory CreationTimelineClip.fromMap(Map<String, dynamic> map) {
    return CreationTimelineClip(
      clipId: map['clipId'] as String? ?? '',
      sourceId: map['sourceId'] as String? ?? '',
      startMs: (map['startMs'] as num?)?.toInt() ?? 0,
      endMs: (map['endMs'] as num?)?.toInt() ?? 0,
      trimInMs: (map['trimInMs'] as num?)?.toInt() ?? 0,
      trimOutMs: (map['trimOutMs'] as num?)?.toInt(),
      speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
      opacity: (map['opacity'] as num?)?.toDouble() ?? 1.0,
      rotation: (map['rotation'] as num?)?.toDouble() ?? 0.0,
      scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CreationProject {
  static const Object _keepRenderedUri = Object();

  CreationProject({
    required this.projectId,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    required this.creationType,
    required this.status,
    required this.mediaAssets,
    required this.timeline,
    this.caption = '',
    this.privacy = 'Public',
    this.coverLabel = 'Auto',
    this.version = 1,
    this.operations = const <Map<String, dynamic>>[],
    this.audio = const <Map<String, dynamic>>[],
    this.textLayers = const <Map<String, dynamic>>[],
    this.stickerLayers = const <Map<String, dynamic>>[],
    this.effectLayers = const <Map<String, dynamic>>[],
    this.accessibility = const <String, dynamic>{},
    this.rights = const <String, dynamic>{},
    this.publishState = const <String, dynamic>{},
    this.renderedUri,
  });

  final String projectId;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CreationType creationType;
  final CreationProjectStatus status;
  final List<CreationMediaAsset> mediaAssets;
  final List<CreationTimelineClip> timeline;
  final String caption;
  final String privacy;
  final String coverLabel;
  final int version;
  final List<Map<String, dynamic>> operations;
  final List<Map<String, dynamic>> audio;
  final List<Map<String, dynamic>> textLayers;
  final List<Map<String, dynamic>> stickerLayers;
  final List<Map<String, dynamic>> effectLayers;
  final Map<String, dynamic> accessibility;
  final Map<String, dynamic> rights;
  final Map<String, dynamic> publishState;
  final String? renderedUri;

  CreationProject copyWith({
    DateTime? updatedAt,
    CreationProjectStatus? status,
    List<CreationMediaAsset>? mediaAssets,
    List<CreationTimelineClip>? timeline,
    String? caption,
    String? privacy,
    String? coverLabel,
    int? version,
    List<Map<String, dynamic>>? operations,
    List<Map<String, dynamic>>? audio,
    List<Map<String, dynamic>>? textLayers,
    List<Map<String, dynamic>>? stickerLayers,
    List<Map<String, dynamic>>? effectLayers,
    Map<String, dynamic>? accessibility,
    Map<String, dynamic>? rights,
    Map<String, dynamic>? publishState,
    Object? renderedUri = _keepRenderedUri,
  }) {
    return CreationProject(
      projectId: projectId,
      ownerId: ownerId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      creationType: creationType,
      status: status ?? this.status,
      mediaAssets: mediaAssets ?? this.mediaAssets,
      timeline: timeline ?? this.timeline,
      caption: caption ?? this.caption,
      privacy: privacy ?? this.privacy,
      coverLabel: coverLabel ?? this.coverLabel,
      version: version ?? this.version,
      operations: operations ?? this.operations,
      audio: audio ?? this.audio,
      textLayers: textLayers ?? this.textLayers,
      stickerLayers: stickerLayers ?? this.stickerLayers,
      effectLayers: effectLayers ?? this.effectLayers,
      accessibility: accessibility ?? this.accessibility,
      rights: rights ?? this.rights,
      publishState: publishState ?? this.publishState,
      renderedUri: identical(renderedUri, _keepRenderedUri)
          ? this.renderedUri
          : renderedUri as String?,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'projectId': projectId,
        'ownerId': ownerId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'creationType': creationType.name,
        'status': status.name,
        'mediaAssets': mediaAssets.map((e) => e.toMap()).toList(),
        'timeline': timeline.map((e) => e.toMap()).toList(),
        'caption': caption,
        'privacy': privacy,
        'coverLabel': coverLabel,
        'version': version,
        'operations': operations,
        'audio': audio,
        'textLayers': textLayers,
        'stickerLayers': stickerLayers,
        'effectLayers': effectLayers,
        'accessibility': accessibility,
        'rights': rights,
        'publishState': publishState,
        'renderedUri': renderedUri,
      };

  String encode() => jsonEncode(toMap());

  factory CreationProject.fromEncoded(String encoded) {
    return CreationProject.fromMap(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
  }

  factory CreationProject.fromMap(Map<String, dynamic> map) {
    final assets = (map['mediaAssets'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => CreationMediaAsset.fromMap(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    final timeline = (map['timeline'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => CreationTimelineClip.fromMap(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    CreationType parseType(String? value) => CreationType.values.firstWhere(
          (e) => e.name == value,
          orElse: () => CreationType.post,
        );
    CreationProjectStatus parseStatus(String? value) =>
        CreationProjectStatus.values.firstWhere(
          (e) => e.name == value,
          orElse: () => CreationProjectStatus.editing,
        );

    return CreationProject(
      projectId: map['projectId'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      creationType: parseType(map['creationType'] as String?),
      status: parseStatus(map['status'] as String?),
      mediaAssets: assets,
      timeline: timeline,
      caption: map['caption'] as String? ?? '',
      privacy: map['privacy'] as String? ?? 'Public',
      coverLabel: map['coverLabel'] as String? ?? 'Auto',
      version: (map['version'] as num?)?.toInt() ?? 1,
      operations: _mapList(map['operations']),
      audio: _mapList(map['audio']),
      textLayers: _mapList(map['textLayers']),
      stickerLayers: _mapList(map['stickerLayers']),
      effectLayers: _mapList(map['effectLayers']),
      accessibility: _map(map['accessibility']),
      rights: _map(map['rights']),
      publishState: _map(map['publishState']),
      renderedUri: map['renderedUri'] as String?,
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  static CreationProject createForAsset({
    required String ownerId,
    required String localUri,
    required bool isVideo,
    int sizeBytes = 0,
    int? width,
    int? height,
    int? durationMs,
    CreationType creationType = CreationType.post,
  }) {
    final now = DateTime.now();
    final projectId = const Uuid().v4();
    final assetId = const Uuid().v4();
    final asset = CreationMediaAsset(
      assetId: assetId,
      localUri: localUri,
      type: isVideo ? 'video' : 'image',
      mimeType: isVideo ? 'video/*' : 'image/*',
      sizeBytes: sizeBytes,
      width: width,
      height: height,
      durationMs: durationMs,
    );
    final timeline = <CreationTimelineClip>[
      CreationTimelineClip(
        clipId: const Uuid().v4(),
        sourceId: assetId,
        startMs: 0,
        endMs: durationMs ?? 0,
      ),
    ];
    return CreationProject(
      projectId: projectId,
      ownerId: ownerId,
      createdAt: now,
      updatedAt: now,
      creationType: creationType,
      status: CreationProjectStatus.newProject,
      mediaAssets: <CreationMediaAsset>[asset],
      timeline: timeline,
    );
  }
}
