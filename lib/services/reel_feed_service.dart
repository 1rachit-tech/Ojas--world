import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reel_model.dart';

class ReelFeedService {
  ReelFeedService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int pageSize = 5;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reels =>
      _firestore.collection('reels');

  Future<ReelFeedPage> fetchPage({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    Query<Map<String, dynamic>> query = _reels
        .orderBy('algorithmScore', descending: true)
        .limit(pageSize);

    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;

    return ReelFeedPage(
      reels: docs.map(ReelModel.fromFirestore).toList(growable: false),
      cursor: docs.isEmpty ? cursor : docs.last,
      hasMore: docs.length == pageSize,
    );
  }
}

class ReelFeedPage {
  const ReelFeedPage({
    required this.reels,
    required this.cursor,
    required this.hasMore,
  });

  final List<ReelModel> reels;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}
