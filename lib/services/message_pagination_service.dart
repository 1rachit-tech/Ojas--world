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

  /// Hard upper bound for every history request.
  static const int pageSize = 20;

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
      // Keep pagination optional. If the composite ordering index is missing,
      // fall back to document ID so an older-history fetch still works.
      if (error.code != 'failed-precondition') {
        return _emptyPage(cursor);
      }

      final fallbackQuery = _messages(conversationId)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(pageSize);

      try {
        snapshot = cursor == null
            ? await fallbackQuery.get()
            : await fallbackQuery.startAfterDocument(cursor).get();
      } on FirebaseException {
        return _emptyPage(cursor);
      }
    }

    final documents = snapshot.docs;
    final messages = <OjasMessage>[];

    for (final document in documents) {
      try {
        messages.add(OjasMessage.fromFirestore(document));
      } catch (_) {
        // Ignore malformed legacy messages rather than breaking the room.
      }
    }

    return MessagePage(
      messages: messages,
      hasMore: documents.length == pageSize,
      cursor: documents.isEmpty ? cursor : documents.last,
    );
  }

  MessagePage _emptyPage(
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  ) {
    return MessagePage(
      messages: const <OjasMessage>[],
      hasMore: false,
      cursor: cursor,
    );
  }
}
