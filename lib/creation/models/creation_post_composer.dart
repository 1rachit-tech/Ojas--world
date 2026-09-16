class CreationMentionEntity {
  const CreationMentionEntity({
    required this.userId,
    required this.handle,
    required this.start,
    required this.end,
  });

  final String userId;
  final String handle;
  final int start;
  final int end;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'userId': userId,
        'handle': handle,
        'start': start,
        'end': end,
      };

  factory CreationMentionEntity.fromMap(Map<String, dynamic> map) {
    return CreationMentionEntity(
      userId: map['userId'] as String? ?? '',
      handle: map['handle'] as String? ?? '',
      start: (map['start'] as num?)?.toInt() ?? 0,
      end: (map['end'] as num?)?.toInt() ?? 0,
    );
  }
}

class CreationHashtagEntity {
  const CreationHashtagEntity({
    required this.tag,
    required this.start,
    required this.end,
  });

  final String tag;
  final int start;
  final int end;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'tag': tag,
        'start': start,
        'end': end,
      };

  factory CreationHashtagEntity.fromMap(Map<String, dynamic> map) {
    return CreationHashtagEntity(
      tag: map['tag'] as String? ?? '',
      start: (map['start'] as num?)?.toInt() ?? 0,
      end: (map['end'] as num?)?.toInt() ?? 0,
    );
  }
}

class CreationPostComposer {
  const CreationPostComposer({
    this.caption = '',
    this.mentions = const <CreationMentionEntity>[],
    this.hashtags = const <CreationHashtagEntity>[],
    this.location,
    this.audioMetadata,
    this.coverAssetId,
    this.audience = 'Public',
    this.commentPolicy = 'Everyone',
    this.reusePolicy = 'Allowed',
    this.altText,
    this.captionLanguage,
    this.audioDescription,
    this.aiGeneratedDisclosure = false,
    this.copyrightConfirmed = false,
  });

  final String caption;
  final List<CreationMentionEntity> mentions;
  final List<CreationHashtagEntity> hashtags;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? audioMetadata;
  final String? coverAssetId;
  final String audience;
  final String commentPolicy;
  final String reusePolicy;
  final String? altText;
  final String? captionLanguage;
  final String? audioDescription;
  final bool aiGeneratedDisclosure;
  final bool copyrightConfirmed;

  CreationPostComposer copyWith({
    String? caption,
    List<CreationMentionEntity>? mentions,
    List<CreationHashtagEntity>? hashtags,
    Map<String, dynamic>? location,
    Map<String, dynamic>? audioMetadata,
    String? coverAssetId,
    String? audience,
    String? commentPolicy,
    String? reusePolicy,
    String? altText,
    String? captionLanguage,
    String? audioDescription,
    bool? aiGeneratedDisclosure,
    bool? copyrightConfirmed,
  }) {
    return CreationPostComposer(
      caption: caption ?? this.caption,
      mentions: mentions ?? this.mentions,
      hashtags: hashtags ?? this.hashtags,
      location: location ?? this.location,
      audioMetadata: audioMetadata ?? this.audioMetadata,
      coverAssetId: coverAssetId ?? this.coverAssetId,
      audience: audience ?? this.audience,
      commentPolicy: commentPolicy ?? this.commentPolicy,
      reusePolicy: reusePolicy ?? this.reusePolicy,
      altText: altText ?? this.altText,
      captionLanguage: captionLanguage ?? this.captionLanguage,
      audioDescription: audioDescription ?? this.audioDescription,
      aiGeneratedDisclosure:
          aiGeneratedDisclosure ?? this.aiGeneratedDisclosure,
      copyrightConfirmed: copyrightConfirmed ?? this.copyrightConfirmed,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'caption': caption,
        'mentions': mentions.map((e) => e.toMap()).toList(growable: false),
        'hashtags': hashtags.map((e) => e.toMap()).toList(growable: false),
        'location': location,
        'audioMetadata': audioMetadata,
        'coverAssetId': coverAssetId,
        'audience': audience,
        'commentPolicy': commentPolicy,
        'reusePolicy': reusePolicy,
        'altText': altText,
        'captionLanguage': captionLanguage,
        'audioDescription': audioDescription,
        'aiGeneratedDisclosure': aiGeneratedDisclosure,
        'copyrightConfirmed': copyrightConfirmed,
      };

  factory CreationPostComposer.fromMap(Map<String, dynamic> map) {
    final mentions = (map['mentions'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => CreationMentionEntity.fromMap(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    final hashtags = (map['hashtags'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => CreationHashtagEntity.fromMap(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    Map<String, dynamic>? mapOrNull(dynamic value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    return CreationPostComposer(
      caption: map['caption'] as String? ?? '',
      mentions: mentions,
      hashtags: hashtags,
      location: mapOrNull(map['location']),
      audioMetadata: mapOrNull(map['audioMetadata']),
      coverAssetId: map['coverAssetId'] as String?,
      audience: map['audience'] as String? ?? 'Public',
      commentPolicy: map['commentPolicy'] as String? ?? 'Everyone',
      reusePolicy: map['reusePolicy'] as String? ?? 'Allowed',
      altText: map['altText'] as String?,
      captionLanguage: map['captionLanguage'] as String?,
      audioDescription: map['audioDescription'] as String?,
      aiGeneratedDisclosure: map['aiGeneratedDisclosure'] == true,
      copyrightConfirmed: map['copyrightConfirmed'] == true,
    );
  }
}
