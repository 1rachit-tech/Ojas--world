import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ojas_message.dart';
import 'messaging_service.dart';

class ChatVideoMessageService {
  ChatVideoMessageService._();

  static final ChatVideoMessageService instance =
      ChatVideoMessageService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendVideoMessage({
    required String conversationId,
    required String receiverId,
    required String mediaUrl,
    required String mediaHash,
    required String mediaStoragePath,
    required int mediaBytes,
    int? width,
    int? height,
    int? durationMs,
    OjasMessage? replyTo,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const MessagingException('Please sign in again.');
    }

    final cleanUrl = mediaUrl.trim();
    final cleanHash = mediaHash.trim().toLowerCase();

    if (receiverId.trim().isEmpty ||
        cleanUrl.isEmpty ||
        cleanHash.isEmpty ||
        mediaBytes <= 0) {
      throw const MessagingException('Invalid video message.');
    }

    final conversation =
        _firestore.collection('conversations').doc(conversationId);
    final message = conversation.collection('messages').doc();

    final data = <String, dynamic>{
      'conversationId': conversationId,
      'senderId': uid,
      'type': 'video',
      'text': '',
      'mediaUrl': cleanUrl,
      'mediaHash': cleanHash,
      'mediaStoragePath': mediaStoragePath.trim(),
      'mediaBytes': mediaBytes,
      'status': 'sent',
      'isDeleted': false,
      'reactions': <String, String>{},
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (width != null && width > 0) data['mediaWidth'] = width;
    if (height != null && height > 0) data['mediaHeight'] = height;
    if (durationMs != null && durationMs > 0) {
      data['mediaDurationMs'] = durationMs;
    }

    if (replyTo != null) {
      data.addAll({
        'replyToMessageId': replyTo.id,
        'replyToSenderId': replyTo.senderId,
        'replyToText': replyTo.isDeleted
            ? 'This message was deleted.'
            : replyTo.isImage
                ? 'Photo'
                : replyTo.type == 'video'
                    ? 'Video'
                    : _safeReplyPreview(replyTo.text),
        'replyToType': replyTo.type,
      });
    }

    final batch = _firestore.batch();
    batch.set(message, data);
    batch.set(
      conversation,
      {
        'lastMessage': 'Video',
        'lastMessageSenderId': uid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts.$uid': 0,
        'lastReadAtBy.$uid': FieldValue.serverTimestamp(),
        'typingBy.$uid': false,
        'unreadCounts.$receiverId': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  String _safeReplyPreview(String value) {
    return value.length <= 120 ? value : '${value.substring(0, 120)}…';
  }
}
