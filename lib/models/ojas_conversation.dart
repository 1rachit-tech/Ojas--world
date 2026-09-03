import 'package:cloud_firestore/cloud_firestore.dart';

class OjasConversation {
  const OjasConversation({
    required this.id,
    required this.participantIds,
    required this.participantProfiles,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.unreadCounts,
    this.lastReadAtBy = const <String, Timestamp>{},
    this.createdAt,
    this.lastMessageAt,
  });

  final String id;

  final List<String> participantIds;

  final Map<String, Map<String, dynamic>>
      participantProfiles;

  final String lastMessage;

  final String lastMessageSenderId;

  final Map<String, int> unreadCounts;

  final Map<String, Timestamp> lastReadAtBy;

  final Timestamp? createdAt;

  final Timestamp? lastMessageAt;

  String otherUserId(String currentUid) {
    for (final uid in participantIds) {
      if (uid != currentUid) {
        return uid;
      }
    }

    return '';
  }

  Map<String, dynamic> profileFor(
    String uid,
  ) {
    return participantProfiles[uid] ??
        <String, dynamic>{};
  }

  int unreadCountFor(
    String uid,
  ) {
    return unreadCounts[uid] ?? 0;
  }

  Timestamp? lastReadAtFor(
    String uid,
  ) {
    return lastReadAtBy[uid];
  }

  factory OjasConversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data =
        document.data() ?? <String, dynamic>{};

    final participants =
        data['participants'];

    final participantIds =
        participants is List
            ? participants
                .whereType<String>()
                .toList()
            : <String>[];

    final profiles =
        <String, Map<String, dynamic>>{};

    final rawProfiles =
        data['participantProfiles'];

    if (rawProfiles is Map) {
      rawProfiles.forEach(
        (key, value) {
          if (key is String &&
              value is Map<String, dynamic>) {
            profiles[key] = value;
          } else if (key is String &&
              value is Map) {
            profiles[key] =
                Map<String, dynamic>.from(value);
          }
        },
      );
    }

    final unread =
        <String, int>{};

    final lastReadAt =
        <String, Timestamp>{};

    final rawLastReadAt =
        data['lastReadAtBy'];

    if (rawLastReadAt is Map) {
      rawLastReadAt.forEach(
        (key, value) {
          if (key is String && value is Timestamp) {
            lastReadAt[key] = value;
          }
        },
      );
    }

    final rawUnread =
        data['unreadCounts'];

    if (rawUnread is Map) {
      rawUnread.forEach(
        (key, value) {
          if (key is String) {
            if (value is int) {
              unread[key] = value;
            } else if (value is num) {
              unread[key] = value.toInt();
            }
          }
        },
      );
    }

    return OjasConversation(
      id: document.id,
      participantIds: participantIds,
      participantProfiles: profiles,
      lastMessage: _string(
        data['lastMessage'],
      ),
      lastMessageSenderId: _string(
        data['lastMessageSenderId'],
      ),
      unreadCounts: unread,
      lastReadAtBy: lastReadAt,
      createdAt: data['createdAt'] as Timestamp?,
      lastMessageAt:
          data['lastMessageAt'] as Timestamp?,
    );
  }

  static String _string(
    dynamic value, {
    String fallback = '',
  }) {
    if (value is String &&
        value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }
}
