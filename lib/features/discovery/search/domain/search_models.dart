import 'package:cloud_firestore/cloud_firestore.dart';

enum SearchEntityType {
  person,
  content,
  hashtag,
  sound,
  topic,
  place,
  live,
  generic,
}

enum SearchTab {
  all,
  top,
  people,
  videos,
  posts,
  hashtags,
  sounds,
  topics,
  live,
  places,
}

extension SearchTabX on SearchTab {
  String get label {
    switch (this) {
      case SearchTab.all:
        return 'All';
      case SearchTab.top:
        return 'Top';
      case SearchTab.people:
        return 'People';
      case SearchTab.videos:
        return 'Videos';
      case SearchTab.posts:
        return 'Posts';
      case SearchTab.hashtags:
        return 'Hashtags';
      case SearchTab.sounds:
        return 'Sounds';
      case SearchTab.topics:
        return 'Topics';
      case SearchTab.live:
        return 'LIVE';
      case SearchTab.places:
        return 'Places';
    }
  }

  SearchEntityType? get entityFilter {
    switch (this) {
      case SearchTab.people:
        return SearchEntityType.person;
      case SearchTab.videos:
      case SearchTab.posts:
        return SearchEntityType.content;
      case SearchTab.hashtags:
        return SearchEntityType.hashtag;
      case SearchTab.sounds:
        return SearchEntityType.sound;
      case SearchTab.topics:
        return SearchEntityType.topic;
      case SearchTab.live:
        return SearchEntityType.live;
      case SearchTab.places:
        return SearchEntityType.place;
      case SearchTab.all:
      case SearchTab.top:
        return null;
    }
  }
}

class SearchQuery {
  const SearchQuery({
    required this.raw,
    required this.normalized,
    required this.tokens,
    required this.aliases,
    required this.language,
    required this.intent,
  });

  final String raw;
  final String normalized;
  final List<String> tokens;
  final List<String> aliases;
  final String language;
  final SearchEntityType intent;

  List<String> get prefixes {
    final values = <String>{};
    for (final token in aliases) {
      final clean = token.trim();
      if (clean.isEmpty) continue;
      final root = (clean.startsWith('#') || clean.startsWith('@'))
          ? clean.substring(1)
          : clean;
      final max = root.length < 12 ? root.length : 12;
      for (var length = 1; length <= max; length++) {
        values.add(root.substring(0, length));
      }
    }
    return values.take(30).toList(growable: false);
  }
}

class SearchResult {
  const SearchResult({
    required this.id,
    required this.entityType,
    required this.title,
    required this.subtitle,
    required this.score,
    this.queryScore = 0,
    this.personalScore = 0,
    this.qualityScore = 0,
    this.popularityScore = 0,
    this.freshnessScore = 0,
    this.trendScore = 0,
    this.imageUrl = '',
    this.creatorId = '',
    this.contentUrl = '',
    this.audioTrackId = '',
    this.createdAt,
    this.tags = const <String>[],
    this.extra = const <String, dynamic>{},
  });

  final String id;
  final SearchEntityType entityType;
  final String title;
  final String subtitle;
  final double score;
  final double queryScore;
  final double personalScore;
  final double qualityScore;
  final double popularityScore;
  final double freshnessScore;
  final double trendScore;
  final String imageUrl;
  final String creatorId;
  final String contentUrl;
  final String audioTrackId;
  final DateTime? createdAt;
  final List<String> tags;
  final Map<String, dynamic> extra;

  String get stableId => entityType.name + ':' + id;

  Map<String, dynamic> toCacheMap() => <String, dynamic>{
    'id': id,
    'entityType': entityType.name,
    'title': title,
    'subtitle': subtitle,
    'score': score,
    'queryScore': queryScore,
    'personalScore': personalScore,
    'qualityScore': qualityScore,
    'popularityScore': popularityScore,
    'freshnessScore': freshnessScore,
    'trendScore': trendScore,
    'imageUrl': imageUrl,
    'creatorId': creatorId,
    'contentUrl': contentUrl,
    'audioTrackId': audioTrackId,
    'createdAt': createdAt?.toIso8601String(),
    'tags': tags,
    'extra': extra,
  };

  static SearchResult? fromCacheMap(Map<String, dynamic> map) {
    final typeName = map['entityType'] as String?;
    SearchEntityType? type;
    for (final value in SearchEntityType.values) {
      if (value.name == typeName) {
        type = value;
        break;
      }
    }
    if (type == null) return null;

    final extra = map['extra'];
    return SearchResult(
      id: map['id'] as String? ?? '',
      entityType: type,
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      score: (map['score'] as num?)?.toDouble() ?? 0,
      queryScore: (map['queryScore'] as num?)?.toDouble() ?? 0,
      personalScore: (map['personalScore'] as num?)?.toDouble() ?? 0,
      qualityScore: (map['qualityScore'] as num?)?.toDouble() ?? 0,
      popularityScore: (map['popularityScore'] as num?)?.toDouble() ?? 0,
      freshnessScore: (map['freshnessScore'] as num?)?.toDouble() ?? 0,
      trendScore: (map['trendScore'] as num?)?.toDouble() ?? 0,
      imageUrl: map['imageUrl'] as String? ?? '',
      creatorId: map['creatorId'] as String? ?? '',
      contentUrl: map['contentUrl'] as String? ?? '',
      audioTrackId: map['audioTrackId'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      tags: map['tags'] is List
          ? List<String>.from(map['tags'] as List)
          : const <String>[],
      extra: extra is Map
          ? Map<String, dynamic>.from(extra)
          : const <String, dynamic>{},
    );
  }
}

class SearchPage {
  const SearchPage({
    required this.results,
    required this.query,
    required this.sessionId,
    this.cursor,
    this.hasMore = false,
    this.fromCache = false,
    this.offline = false,
    this.didYouMean,
  });

  final List<SearchResult> results;
  final SearchQuery query;
  final String sessionId;
  final String? cursor;
  final bool hasMore;
  final bool fromCache;
  final bool offline;
  final String? didYouMean;
}

class SearchSuggestion {
  const SearchSuggestion({
    required this.text,
    required this.entityType,
    this.subtitle = '',
    this.id = '',
    this.imageUrl = '',
  });

  final String text;
  final SearchEntityType entityType;
  final String subtitle;
  final String id;
  final String imageUrl;
}

class SearchUserContext {
  const SearchUserContext({
    this.creatorAffinity = const <String, double>{},
    this.topicAffinity = const <String, double>{},
    this.hashtagAffinity = const <String, double>{},
    this.soundAffinity = const <String, double>{},
    this.contentTypeAffinity = const <String, double>{},
    this.negativeAffinity = const <String, double>{},
    this.blockedCreatorIds = const <String>{},
  });

  final Map<String, double> creatorAffinity;
  final Map<String, double> topicAffinity;
  final Map<String, double> hashtagAffinity;
  final Map<String, double> soundAffinity;
  final Map<String, double> contentTypeAffinity;
  final Map<String, double> negativeAffinity;
  final Set<String> blockedCreatorIds;
}

class SearchIndexRow {
  const SearchIndexRow({
    required this.id,
    required this.entityType,
    required this.title,
    required this.subtitle,
    required this.text,
    this.imageUrl = '',
    this.creatorId = '',
    this.contentUrl = '',
    this.audioTrackId = '',
    this.tokens = const <String>[],
    this.prefixes = const <String>[],
    this.tags = const <String>[],
    this.createdAt,
    this.views = 0,
    this.likes = 0,
    this.saves = 0,
    this.followers = 0,
    this.posts = 0,
    this.algorithmScore = 0,
    this.trendScore = 0,
    this.region = '',
    this.language = '',
    this.location = '',
    this.topicIds = const <String>[],
    this.isLive = false,
    this.eligible = true,
  });

  final String id;
  final SearchEntityType entityType;
  final String title;
  final String subtitle;
  final String text;
  final String imageUrl;
  final String creatorId;
  final String contentUrl;
  final String audioTrackId;
  final List<String> tokens;
  final List<String> prefixes;
  final List<String> tags;
  final DateTime? createdAt;
  final int views;
  final int likes;
  final int saves;
  final int followers;
  final int posts;
  final double algorithmScore;
  final double trendScore;
  final String region;
  final String language;
  final String location;
  final List<String> topicIds;
  final bool isLive;
  final bool eligible;

  factory SearchIndexRow.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final typeName = data['entityType'] as String? ?? 'generic';
    final type = SearchEntityType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => SearchEntityType.generic,
    );

    return SearchIndexRow(
      id: data['entityId'] as String? ?? snapshot.id,
      entityType: type,
      title: data['title'] as String? ?? '',
      subtitle: data['subtitle'] as String? ?? '',
      text: data['text'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      creatorId: data['creatorId'] as String? ?? '',
      contentUrl: data['contentUrl'] as String? ?? '',
      audioTrackId: data['audioTrackId'] as String? ?? '',
      tokens: _stringList(data['tokens']),
      prefixes: _stringList(data['prefixes']),
      tags: _stringList(data['tags']),
      createdAt: _readDateTime(data['createdAt']),
      views: (data['views'] as num?)?.toInt() ?? 0,
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      saves: (data['saves'] as num?)?.toInt() ?? 0,
      followers: (data['followers'] as num?)?.toInt() ?? 0,
      posts: (data['posts'] as num?)?.toInt() ?? 0,
      algorithmScore: (data['algorithmScore'] as num?)?.toDouble() ?? 0,
      trendScore: (data['trendScore'] as num?)?.toDouble() ?? 0,
      region: data['region'] as String? ?? '',
      language: data['language'] as String? ?? '',
      location: data['location'] as String? ?? '',
      topicIds: _stringList(data['topicIds']),
      isLive: data['isLive'] == true,
      eligible: data['eligible'] != false,
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
