import 'package:cloud_firestore/cloud_firestore.dart';

class OjasMessage {
  const OjasMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.type,
    required this.isDeleted,
    this.createdAt,
    this.reactions = const {},
    this.replyToMessageId,
    this.replyToSenderId,
    this.replyToText,
    this.replyToType,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final String type;
  final bool isDeleted;
  final Timestamp? createdAt;

  /// Map structure:
  ///
  /// {
  ///   "userUid1": "❤️",
  ///   "userUid2": "🔥"
  /// }
  ///
  /// One user can have only one reaction per message.
  final Map<String, String> reactions;

  /// Reply metadata.
  ///
  /// We intentionally store a small snapshot instead of loading the
  /// original message every time. This keeps chat reads low-cost.
  final String? replyToMessageId;
  final String? replyToSenderId;
  final String? replyToText;
  final String? replyToType;

  bool isSentBy(String uid) {
    return senderId == uid;
  }

  bool get hasReply {
    return replyToMessageId != null &&
        replyToMessageId!.isNotEmpty;
  }

  String? reactionOf(String uid) {
    return reactions[uid];
  }

  int reactionCount(String emoji) {
    return reactions.values
        .where((reaction) => reaction == emoji)
        .length;
  }

  Map<String, int> get reactionSummary {
    final summary = <String, int>{};

    for (final reaction in reactions.values) {
      if (reaction.trim().isEmpty) {
        continue;
      }

      summary[reaction] =
          (summary[reaction] ?? 0) + 1;
    }

    return summary;
  }

  factory OjasMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return OjasMessage(
      id: document.id,
      conversationId: _string(
        data['conversationId'],
      ),
      senderId: _string(
        data['senderId'],
      ),
      text: _string(
        data['text'],
      ),
      type: _string(
        data['type'],
        fallback: 'text',
      ),
      isDeleted: data['isDeleted'] == true,
      createdAt: data['createdAt'] as Timestamp?,
      reactions: _reactionMap(
        data['reactions'],
      ),
      replyToMessageId: _nullableString(
        data['replyToMessageId'],
      ),
      replyToSenderId: _nullableString(
        data['replyToSenderId'],
      ),
      replyToText: _nullableString(
        data['replyToText'],
      ),
      replyToType: _nullableString(
        data['replyToType'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'text': text,
      'type': type,
      'isDeleted': isDeleted,
      'reactions': reactions,
      'replyToMessageId': replyToMessageId,
      'replyToSenderId': replyToSenderId,
      'replyToText': replyToText,
      'replyToType': replyToType,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, String> _reactionMap(
    dynamic value,
  ) {
    if (value is! Map) {
      return const {};
    }

    final reactions = <String, String>{};

    value.forEach((key, reaction) {
      if (key is String &&
          reaction is String &&
          key.trim().isNotEmpty &&
          reaction.trim().isNotEmpty) {
        reactions[key] = reaction;
      }
    });

    return reactions;
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

  static String? _nullableString(
    dynamic value,
  ) {
    if (value is String &&
        value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }
}
