import 'package:cloud_firestore/cloud_firestore.dart';

enum HomeFeedMode { personalized, following, favorites, latest, friends }

enum HomeFeedSource {
  following,
  favorite,
  suggested,
  interest,
  trending,
  fresh,
  friend,
}

enum HomeContentType { post, video, carousel, unknown }

enum HomeEligibilityStatus { eligible, filtered, restricted, rejected }

class HomeFeedContext {
  const HomeFeedContext({
    required this.sessionId,
    required this.userId,
    required this.mode,
    required this.startedAt,
    this.cursorToken,
    this.seenContentIds = const <String>{},
    this.negativeContentIds = const <String>{},
    this.mutedCreatorIds = const <String>{},
  });

  final String sessionId;
  final String userId;
  final HomeFeedMode mode;
  final DateTime startedAt;
  final String? cursorToken;
  final Set<String> seenContentIds;
  final Set<String> negativeContentIds;
  final Set<String> mutedCreatorIds;

  HomeFeedContext copyWith({
    String? cursorToken,
    Set<String>? seenContentIds,
    Set<String>? negativeContentIds,
    Set<String>? mutedCreatorIds,
  }) {
    return HomeFeedContext(
      sessionId: sessionId,
      userId: userId,
      mode: mode,
      startedAt: startedAt,
      cursorToken: cursorToken ?? this.cursorToken,
      seenContentIds: seenContentIds ?? this.seenContentIds,
      negativeContentIds: negativeContentIds ?? this.negativeContentIds,
      mutedCreatorIds: mutedCreatorIds ?? this.mutedCreatorIds,
    );
  }
}

class HomeFeedItem {
  const HomeFeedItem({
    required this.contentId,
    required this.creatorId,
    required this.contentType,
    required this.mediaType,
    required this.createdAt,
    required this.source,
    required this.eligibility,
    required this.rankingScore,
    this.thumbnailUrl,
    this.mediaUrl,
    this.caption = '',
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.saves = 0,
    this.views = 0,
    this.recommendationReason,
  });

  final String contentId;
  final String creatorId;
  final HomeContentType contentType;
  final String mediaType;
  final DateTime createdAt;
  final HomeFeedSource source;
  final HomeEligibilityStatus eligibility;
  final double rankingScore;
  final String? thumbnailUrl;
  final String? mediaUrl;
  final String caption;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  final int views;
  final String? recommendationReason;
}

class HomeFeedPage {
  const HomeFeedPage({
    required this.items,
    required this.hasMore,
    this.cursor,
  });

  final List<HomeFeedItem> items;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}
