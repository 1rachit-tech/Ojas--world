/// Universal social interaction types for OJAS.

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
  followRequest,
  followAccept,
  followDecline,
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

enum CommentSort {
  newest,
  top,
}

class MentionRef {
  const MentionRef({
    required this.userId,
    required this.startIndex,
    required this.endIndex,
    this.displayName = '',
  });

  final String userId;
  final int startIndex;
  final int endIndex;
  final String displayName;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'startIndex': startIndex,
        'endIndex': endIndex,
        'displayName': displayName,
      };

  factory MentionRef.fromMap(Map<String, dynamic> data) => MentionRef(
        userId: (data['userId'] as String?) ?? '',
        startIndex: (data['startIndex'] as num?)?.toInt() ?? 0,
        endIndex: (data['endIndex'] as num?)?.toInt() ?? 0,
        displayName: (data['displayName'] as String?) ?? '',
      );
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
    this.mentions = const <MentionRef>[],
    this.likedByMe = false,
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
  final List<MentionRef> mentions;
  final bool likedByMe;

  bool get isReply => parentCommentId != null && parentCommentId!.isNotEmpty;
  bool get isEdited => editedAt != null;

  SocialComment copyWith({
    int? likeCount,
    bool? likedByMe,
    String? text,
    DateTime? editedAt,
    bool? isDeleted,
  }) {
    return SocialComment(
      id: id,
      contentId: contentId,
      authorId: authorId,
      authorName: authorName,
      text: text ?? this.text,
      parentCommentId: parentCommentId,
      rootCommentId: rootCommentId,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      clientActionId: clientActionId,
      mentions: mentions,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }

  factory SocialComment.fromMap(String id, Map<String, dynamic> data, {bool likedByMe = false}) {
    DateTime? ts(dynamic v) {
      if (v is DateTime) return v;
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    final rawMentions = data['mentions'];
    final mentions = <MentionRef>[];
    if (rawMentions is List) {
      for (final m in rawMentions) {
        if (m is Map) {
          mentions.add(MentionRef.fromMap(Map<String, dynamic>.from(m)));
        }
      }
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
      mentions: mentions,
      likedByMe: likedByMe,
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
  final String channel;
  final String intent;
  final String? destination;
  final String? clientActionId;
}

class SaveCollection {
  const SaveCollection({
    required this.id,
    required this.ownerId,
    required this.name,
    this.coverUrl = '',
    this.itemCount = 0,
    this.isPrivate = true,
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String coverUrl;
  final int itemCount;
  final bool isPrivate;
  final DateTime? createdAt;

  factory SaveCollection.fromMap(String id, Map<String, dynamic> data) {
    DateTime? ts(dynamic v) {
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    return SaveCollection(
      id: id,
      ownerId: (data['ownerId'] as String?) ?? '',
      name: (data['name'] as String?) ?? 'Collection',
      coverUrl: (data['coverUrl'] as String?) ?? '',
      itemCount: (data['itemCount'] as num?)?.toInt() ?? 0,
      isPrivate: data['isPrivate'] != false,
      createdAt: ts(data['createdAt']),
    );
  }
}

class FollowRequest {
  const FollowRequest({
    required this.id,
    required this.requesterId,
    required this.targetId,
    required this.status,
    this.createdAt,
    this.requesterName = '',
  });

  final String id;
  final String requesterId;
  final String targetId;
  final String status; // pending | accepted | declined | cancelled
  final DateTime? createdAt;
  final String requesterName;

  factory FollowRequest.fromMap(String id, Map<String, dynamic> data) {
    DateTime? ts(dynamic v) {
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    return FollowRequest(
      id: id,
      requesterId: (data['requesterId'] as String?) ?? '',
      targetId: (data['targetId'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'pending',
      createdAt: ts(data['createdAt']),
      requesterName: (data['requesterName'] as String?) ?? '',
    );
  }
}
