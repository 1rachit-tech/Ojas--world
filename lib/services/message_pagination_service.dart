import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ojas_message.dart';

class MessagePage {
  const MessagePage({
    required this.messages,
    required this.hasMore,
    required this.cursor,
  });

  final List<OjasMessage> messages;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}

class MessagePaginationService {
  MessagePaginationService._();

  static final MessagePaginationService instance =
      MessagePaginationService._();

  static const int pageSize = 40;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _messages(
    String conversationId,
  ) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages');
  }

  Future<MessagePage> loadPage({
    required String conversationId,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;

    final orderedQuery = _messages(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    try {
      snapshot = cursor == null
          ? await orderedQuery.get()
          : await orderedQuery.startAfterDocument(cursor).get();
    } on FirebaseException catch (error) {
      // A missing Firestore index must not make the real-time chat unusable.
      // Fall back to document-ID pagination; the chat screen sorts the merged
      // messages by createdAt before rendering them.
      if (error.code != 'failed-precondition') {
        rethrow;
      }

      final fallbackQuery = _messages(conversationId)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(pageSize);

      snapshot = cursor == null
          ? await fallbackQuery.get()
          : await fallbackQuery.startAfterDocument(cursor).get();
    }

    final documents = snapshot.docs;
    final messages = documents
        .map(OjasMessage.fromFirestore)
        .toList(growable: false);

    return MessagePage(
      messages: messages,
      hasMore: documents.length == pageSize,
      cursor: documents.isEmpty ? cursor : documents.last,
    );
  }
}
