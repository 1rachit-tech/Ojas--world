/// Universal social interaction types for OJAS.
/// Buttons are UI only — this is the shared language of the graph.

enum InteractionTargetType {
  content,
  comment,
  profile,
  hashtag,
  sound,
  collection,
}

enum InteractionActionType {
  like,
  unlike,
  comment,
  reply,
  save,
  unsave,
  share,
  follow,
  unfollow,
  commentLike,
  commentUnlike,
}

enum InteractionSource {
  homeFeed,
  explore,
  search,
  profile,
  content,
  comment,
  notification,
  share,
  suggestion,
  unknown,
}

enum RelationshipState {
  none,
  following,
  followedBy,
  mutual,
  requestSent,
  requestReceived,
  blocked,
}

class SocialComment {
  const SocialComment({
    required this.id,
    required this.contentId,
    required this.authorId,
    required this.authorName,
    required this.text,
    this.parentCommentId,
    this.rootCommentId,
    this.likeCount = 0,
    this.replyCount = 0,
    this.createdAt,
    this.editedAt,
    this.isDeleted = false,
    this.clientActionId,
  });

  final String id;
  final String contentId;
  final String authorId;
  final String authorName;
  final String text;
  final String? parentCommentId;
  final String? rootCommentId;
  final int likeCount;
  final int replyCount;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final bool isDeleted;
  final String? clientActionId;

  bool get isReply => parentCommentId != null && parentCommentId!.isNotEmpty;

  factory SocialComment.fromMap(String id, Map<String, dynamic> data) {
    DateTime? ts(dynamic v) {
      if (v is DateTime) return v;
      if (v != null && v is Object && v.runtimeType.toString().contains('Timestamp')) {
        try {
          return (v as dynamic).toDate() as DateTime;
        } catch (_) {}
      }
      return null;
    }

    return SocialComment(
      id: id,
      contentId: (data['contentId'] as String?) ?? '',
      authorId: (data['authorId'] as String?) ?? '',
      authorName: (data['authorName'] as String?)?.trim().isNotEmpty == true
          ? (data['authorName'] as String).trim()
          : 'OJAS User',
      text: (data['text'] as String?) ?? '',
      parentCommentId: data['parentCommentId'] as String?,
      rootCommentId: data['rootCommentId'] as String?,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      replyCount: (data['replyCount'] as num?)?.toInt() ?? 0,
      createdAt: ts(data['createdAt']),
      editedAt: ts(data['editedAt']),
      isDeleted: data['isDeleted'] == true,
      clientActionId: data['clientActionId'] as String?,
    );
  }
}

class ShareTrackEvent {
  const ShareTrackEvent({
    required this.contentId,
    required this.channel,
    required this.intent,
    this.destination,
    this.clientActionId,
  });

  final String contentId;
  final String channel; // internal | external | copy_link
  final String intent; // opened | completed | copied
  final String? destination;
  final String? clientActionId;
}
