import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_feed_models.dart';

class HomeFeedCacheService {
  static const String _key = 'ojas_home_feed_cache_v1';

  Future<void> save(List<HomeFeedItem> items) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = items.take(20).map((item) => <String, dynamic>{
          'contentId': item.contentId,
          'creatorId': item.creatorId,
          'contentType': item.contentType.name,
          'mediaType': item.mediaType,
          'createdAt': item.createdAt.toIso8601String(),
          'source': item.source.name,
          'rankingScore': item.rankingScore,
          'thumbnailUrl': item.thumbnailUrl,
          'mediaUrl': item.mediaUrl,
          'mediaSources': item.mediaSources,
          'caption': item.caption,
          'hashtags': item.hashtags,
          'mentions': item.mentions,
          'soundId': item.soundId,
          'location': item.location,
          'likes': item.likes,
          'comments': item.comments,
          'shares': item.shares,
          'saves': item.saves,
          'views': item.views,
          'recommendationReason': item.recommendationReason,
          'rankingContext': item.rankingContext,
          'trackingToken': item.trackingToken,
          'visibility': item.visibility,
          'recommendationEligible': item.recommendationEligible,
        }).toList(growable: false);
    await preferences.setString(_key, jsonEncode(payload));
  }

  Future<List<HomeFeedItem>> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return const <HomeFeedItem>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <HomeFeedItem>[];
      return decoded.whereType<Map<String, dynamic>>().map(_fromMap).toList(growable: false);
    } catch (_) {
      return const <HomeFeedItem>[];
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }

  HomeFeedItem _fromMap(Map<String, dynamic> map) {
    HomeContentType parseContentType(Object? value) {
      return HomeContentType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => HomeContentType.unknown,
      );
    }

    HomeFeedSource parseSource(Object? value) {
      return HomeFeedSource.values.firstWhere(
        (source) => source.name == value,
        orElse: () => HomeFeedSource.fresh,
      );
    }

    final context = map['rankingContext'];
    return HomeFeedItem(
      contentId: map['contentId'] as String? ?? '',
      creatorId: map['creatorId'] as String? ?? '',
      contentType: parseContentType(map['contentType']),
      mediaType: map['mediaType'] as String? ?? 'image',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      source: parseSource(map['source']),
      eligibility: HomeEligibilityStatus.eligible,
      rankingScore: (map['rankingScore'] as num?)?.toDouble() ?? 0,
      mediaSources: _strings(map['mediaSources']),
      thumbnailUrl: map['thumbnailUrl'] as String?,
      mediaUrl: map['mediaUrl'] as String?,
      caption: map['caption'] as String? ?? '',
      hashtags: _strings(map['hashtags']),
      mentions: _strings(map['mentions']),
      soundId: map['soundId'] as String?,
      location: map['location'] as String?,
      likes: (map['likes'] as num?)?.toInt() ?? 0,
      comments: (map['comments'] as num?)?.toInt() ?? 0,
      shares: (map['shares'] as num?)?.toInt() ?? 0,
      saves: (map['saves'] as num?)?.toInt() ?? 0,
      views: (map['views'] as num?)?.toInt() ?? 0,
      recommendationReason: map['recommendationReason'] as String?,
      rankingContext: _doubleMap(context),
      trackingToken: map['trackingToken'] as String?,
      visibility: map['visibility'] as String? ?? 'public',
      recommendationEligible: map['recommendationEligible'] as bool? ?? true,
    );
  }

  List<String> _strings(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }

  Map<String, double> _doubleMap(Object? value) {
    if (value is! Map) return const <String, double>{};
    return value.map(
      (key, value) => MapEntry(
        key.toString(),
        value is num ? value.toDouble() : 0,
      ),
    );
  }
}
