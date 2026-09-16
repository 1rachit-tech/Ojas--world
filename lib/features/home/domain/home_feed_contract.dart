import 'package:cloud_firestore/cloud_firestore.dart';

enum HomeFeedMode {
  personalized,
  following,
  favorites,
  latest,
  friends,
}

enum HomeFeedSource {
  following,
  favorite,
  suggested,
  interest,
  trending,
  fresh,
  friend,
}

enum HomeContentType { post, video, carousel }

enum HomeMediaType { image, video }

enum HomeFeedItemState { idle, loading, ready, failed }

/// Stable client-side contract for Home. This deliberately does not assume
/// that the current Firestore schema is the final production feed schema.
class HomeFeedItem {
  const HomeFeedItem({
    required this.contentId,
    required this.creatorId,
    required this.contentType,
    required this.mediaType,
    required this.createdAt,
    required this.source,
    this.mediaSources = const <String>[],
    this.thumbnailUrl = '',
    this.caption = '',
    this.hashtags = const <String>[],
    this.mentions = const <String>[],
    this.soundId,
    this.locationId,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.saveCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isFollowingCreator = false,
    this.rankingContext = const <String, dynamic>{},
    this.trackingToken,
  });

  final String contentId;
  final String creatorId;
  final HomeContentType contentType;
  final HomeMediaType mediaType;
  final DateTime createdAt;
  final HomeFeedSource source;
  final List<String> mediaSources;
  final String thumbnailUrl;
  final String caption;
  final List<String> hashtags;
  final List<String> mentions;
  final String? soundId;
  final String? locationId;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int saveCount;
  final bool isLiked;
  final bool isSaved;
  final bool isFollowingCreator;
  final Map<String, dynamic> rankingContext;
  final String? trackingToken;

  HomeFeedItem copyWith({
    bool? isLiked,
    bool? isSaved,
    bool? isFollowingCreator,
    int? likeCount,
    int? saveCount,
  }) {
    return HomeFeedItem(
      contentId: contentId,
      creatorId: creatorId,
      contentType: contentType,
      mediaType: mediaType,
      createdAt: createdAt,
      source: source,
      mediaSources: mediaSources,
      thumbnailUrl: thumbnailUrl,
      caption: caption,
      hashtags: hashtags,
      mentions: mentions,
      soundId: soundId,
      locationId: locationId,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount,
      shareCount: shareCount,
      saveCount: saveCount ?? this.saveCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isFollowingCreator: isFollowingCreator ?? this.isFollowingCreator,
      rankingContext: rankingContext,
      trackingToken: trackingToken,
    );
  }
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

class HomeFeedSession {
  HomeFeedSession({
    required this.sessionId,
    required this.userId,
    required this.mode,
  });

  final String sessionId;
  final String userId;
  HomeFeedMode mode;
  final DateTime startedAt = DateTime.now();

  final Set<String> servedItemIds = <String>{};
  final Set<String> seenItemIds = <String>{};
  final Set<String> skippedItemIds = <String>{};
  final Set<String> negativeFeedbackItemIds = <String>{};
}
