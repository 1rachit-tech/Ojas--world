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

enum HomePlaybackState {
  idle,
  loading,
  buffering,
  playing,
  paused,
  completed,
  failed,
  disposed,
}

class HomeFeedContext {
  const HomeFeedContext({
    required this.sessionId,
    required this.userId,
    required this.mode,
    required this.startedAt,
    this.cursor,
    this.seenContentIds = const <String>{},
    this.negativeContentIds = const <String>{},
    this.mutedCreatorIds = const <String>{},
    this.blockedCreatorIds = const <String>{},
  });

  final String sessionId;
  final String userId;
  final HomeFeedMode mode;
  final DateTime startedAt;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final Set<String> seenContentIds;
  final Set<String> negativeContentIds;
  final Set<String> mutedCreatorIds;
  final Set<String> blockedCreatorIds;

  HomeFeedContext copyWith({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    Set<String>? seenContentIds,
    Set<String>? negativeContentIds,
    Set<String>? mutedCreatorIds,
    Set<String>? blockedCreatorIds,
  }) {
    return HomeFeedContext(
      sessionId: sessionId,
      userId: userId,
      mode: mode,
      startedAt: startedAt,
      cursor: cursor ?? this.cursor,
      seenContentIds: seenContentIds ?? this.seenContentIds,
      negativeContentIds: negativeContentIds ?? this.negativeContentIds,
      mutedCreatorIds: mutedCreatorIds ?? this.mutedCreatorIds,
      blockedCreatorIds: blockedCreatorIds ?? this.blockedCreatorIds,
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
    this.mediaSources = const <String>[],
    this.thumbnailUrl,
    this.mediaUrl,
    this.caption = '',
    this.hashtags = const <String>[],
    this.mentions = const <String>[],
    this.soundId,
    this.location,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.saves = 0,
    this.views = 0,
    this.recommendationReason,
    this.rankingContext = const <String, double>{},
    this.trackingToken,
    this.visibility = 'public',
    this.recommendationEligible = true,
  });

  final String contentId;
  final String creatorId;
  final HomeContentType contentType;
  final String mediaType;
  final DateTime createdAt;
  final HomeFeedSource source;
  final HomeEligibilityStatus eligibility;
  final double rankingScore;
  final List<String> mediaSources;
  final String? thumbnailUrl;
  final String? mediaUrl;
  final String caption;
  final List<String> hashtags;
  final List<String> mentions;
  final String? soundId;
  final String? location;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  final int views;
  final String? recommendationReason;
  final Map<String, double> rankingContext;
  final String? trackingToken;
  final String visibility;
  final bool recommendationEligible;

  HomeFeedItem copyWith({
    List<String>? mediaSources,
    String? thumbnailUrl,
    String? mediaUrl,
  }) {
    return HomeFeedItem(
      contentId: contentId,
      creatorId: creatorId,
      contentType: contentType,
      mediaType: mediaType,
      createdAt: createdAt,
      source: source,
      eligibility: eligibility,
      rankingScore: rankingScore,
      mediaSources: mediaSources ?? this.mediaSources,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      caption: caption,
      hashtags: hashtags,
      mentions: mentions,
      soundId: soundId,
      location: location,
      likes: likes,
      comments: comments,
      shares: shares,
      saves: saves,
      views: views,
      recommendationReason: recommendationReason,
      rankingContext: rankingContext,
      trackingToken: trackingToken,
      visibility: visibility,
      recommendationEligible: recommendationEligible,
    );
  }

  bool get isVideo => mediaType == 'video' || contentType == HomeContentType.video;
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

class HomeSessionState {
  HomeSessionState({
    required this.sessionId,
    required this.userId,
    required this.mode,
    required this.startedAt,
  });

  final String sessionId;
  final String userId;
  HomeFeedMode mode;
  final DateTime startedAt;
  final Set<String> servedItems = <String>{};
  final Set<String> seenItems = <String>{};
  final Set<String> clickedItems = <String>{};
  final Set<String> watchedItems = <String>{};
  final Set<String> skippedItems = <String>{};
  final Set<String> interactionItems = <String>{};

  void markServed(Iterable<HomeFeedItem> items) =>
      servedItems.addAll(items.map((item) => item.contentId));

  void markSeen(String contentId) => seenItems.add(contentId);
  void markClicked(String contentId) => clickedItems.add(contentId);
  void markWatched(String contentId) => watchedItems.add(contentId);
  void markSkipped(String contentId) => skippedItems.add(contentId);
  void markInteraction(String contentId) => interactionItems.add(contentId);
}
