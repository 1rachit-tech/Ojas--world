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
    Query<Map<String, dynamic>> query = _messages(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }

    final snapshot = await query.get();
    final documents = snapshot.docs;

    return MessagePage(
      messages: documents
          .map(OjasMessage.fromFirestore)
          .toList(growable: false),
      hasMore: documents.length == pageSize,
      cursor: documents.isEmpty ? cursor : documents.last,
    );
  }
}
