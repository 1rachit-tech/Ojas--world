import '../models/creation_project.dart';

class CreationMetadataPipelineResult {
  const CreationMetadataPipelineResult({
    required this.hashtags,
    required this.mentions,
    required this.audioTrackId,
    required this.audioMetadata,
    required this.location,
    required this.shopItemIds,
    required this.searchTokens,
  });

  final List<String> hashtags;
  final List<String> mentions;
  final String audioTrackId;
  final Map<String, dynamic> audioMetadata;
  final Map<String, dynamic> location;
  final List<String> shopItemIds;
  final List<String> searchTokens;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'schemaVersion': 1,
        'hashtags': hashtags,
        'mentions': mentions,
        'audioTrackId': audioTrackId,
        'audioMetadata': audioMetadata,
        'location': location,
        'shopItemIds': shopItemIds,
        'searchTokens': searchTokens,
      };
}

/// Normalizes creator metadata at the last local stage before publish.
/// It is intentionally deterministic and bounded so retries produce the
/// same Firestore payload without introducing another backend dependency.
class CreationMetadataPipelineService {
  const CreationMetadataPipelineService._();

  static const int maxHashtags = 32;
  static const int maxMentions = 32;
  static const int maxShopItemIds = 32;
  static const int maxSearchTokens = 100;

  static CreationMetadataPipelineResult build(CreationProject project) {
    final composer = _map(project.publishState['composer']);
    final composerHashtags = _listOfMaps(composer['hashtags']);
    final composerMentions = _listOfMaps(composer['mentions']);

    final hashtags = <String>{};
    for (final entry in composerHashtags) {
      final tag = _normalizeHandleOrTag(entry['tag'], leading: '#');
      if (tag.isNotEmpty) hashtags.add(tag);
    }
    hashtags.addAll(_hashtagsFromCaption(project.caption));

    final mentions = <String>{};
    for (final entry in composerMentions) {
      final handle = _normalizeHandleOrTag(entry['handle'], leading: '@');
      if (handle.isNotEmpty) mentions.add(handle);
    }
    mentions.addAll(_mentionsFromCaption(project.caption));

    final composerAudio = _map(composer['audioMetadata']);
    final audioTrackId = _firstNonEmptyString(<dynamic>[
      composerAudio['trackId'],
      composerAudio['audioTrackId'],
      project.publishState['audioTrackId'],
    ]);

    final shopItemIds = _boundedStrings(
      project.publishState['shopItemIds'],
      maxShopItemIds,
    );

    final searchTokens = _buildSearchTokens(
      caption: project.caption,
      hashtags: hashtags.toList(growable: false),
      mentions: mentions.toList(growable: false),
    );

    return CreationMetadataPipelineResult(
      hashtags: hashtags.take(maxHashtags).toList(growable: false),
      mentions: mentions.take(maxMentions).toList(growable: false),
      audioTrackId: audioTrackId,
      audioMetadata: _boundedMap(composerAudio, 12),
      location: _boundedMap(_map(composer['location']), 12),
      shopItemIds: shopItemIds,
      searchTokens: searchTokens,
    );
  }

  static Set<String> _hashtagsFromCaption(String caption) {
    final result = <String>{};
    for (final token in caption.split(RegExp(r'\s+'))) {
      final cleaned = token.trim().replaceAll(RegExp(r'^[^#]*#'), '#');
      if (!cleaned.startsWith('#')) continue;
      final value = cleaned.substring(1).replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');
      if (value.length >= 2 && value.length <= 64) result.add(value.toLowerCase());
    }
    return result;
  }

  static Set<String> _mentionsFromCaption(String caption) {
    final result = <String>{};
    for (final token in caption.split(RegExp(r'\s+'))) {
      final cleaned = token.trim();
      if (!cleaned.startsWith('@')) continue;
      final value = cleaned.substring(1).replaceAll(RegExp(r'[^A-Za-z0-9_.\-]'), '');
      if (value.length >= 2 && value.length <= 64) result.add(value.toLowerCase());
    }
    return result;
  }

  static List<String> _buildSearchTokens({
    required String caption,
    required List<String> hashtags,
    required List<String> mentions,
  }) {
    final values = <String>[
      caption.toLowerCase(),
      ...hashtags.map((tag) => tag.toLowerCase()),
      ...mentions.map((handle) => handle.toLowerCase()),
    ];
    final tokens = <String>{};
    for (final value in values) {
      for (final token in value.replaceAll(RegExp(r'[^a-z0-9_#@\s]'), ' ').split(RegExp(r'\s+'))) {
        final cleaned = token.replaceAll(RegExp(r'^[#@]'), '').trim();
        if (cleaned.length >= 2 && cleaned.length <= 64) tokens.add(cleaned);
      }
    }
    return tokens.take(maxSearchTokens).toList(growable: false);
  }

  static String _normalizeHandleOrTag(dynamic value, {required String leading}) {
    if (value is! String) return '';
    var cleaned = value.trim();
    if (cleaned.startsWith(leading)) cleaned = cleaned.substring(1);
    cleaned = cleaned.replaceAll(
      RegExp(leading == '#' ? r'[^A-Za-z0-9_\-]' : r'[^A-Za-z0-9_.\-]'),
      '',
    );
    if (cleaned.length < 2 || cleaned.length > 64) return '';
    return cleaned.toLowerCase();
  }

  static List<String> _boundedStrings(dynamic value, int maxItems) {
    if (value is! List) return const <String>[];
    final values = <String>{};
    for (final raw in value) {
      if (raw is! String) continue;
      final cleaned = raw.trim();
      if (cleaned.isEmpty || cleaned.length > 128) continue;
      if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(cleaned)) continue;
      values.add(cleaned);
      if (values.length >= maxItems) break;
    }
    return values.toList(growable: false);
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .take(64)
        .toList(growable: false);
  }

  static Map<String, dynamic> _boundedMap(
    Map<String, dynamic> input,
    int maxEntries,
  ) {
    final output = <String, dynamic>{};
    for (final entry in input.entries.take(maxEntries)) {
      if (entry.key.length > 64) continue;
      final value = entry.value;
      if (value is String) {
        if (value.length <= 512) output[entry.key] = value;
      } else if (value is num || value is bool) {
        output[entry.key] = value;
      }
    }
    return output;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim().slice(0, 128);
    }
    return '';
  }
}

extension on String {
  String slice(int start, int end) {
    if (start >= length) return '';
    final safeEnd = end > length ? length : end;
    return substring(start, safeEnd);
  }
}
