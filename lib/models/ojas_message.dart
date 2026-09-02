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
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final String type;
  final bool isDeleted;
  final Timestamp? createdAt;

  bool isSentBy(String uid) {
    return senderId == uid;
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'text': text,
      'type': type,
      'isDeleted': isDeleted,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static String _string(
    dynamic value, {
    String fallback = '',
  }) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }
}
