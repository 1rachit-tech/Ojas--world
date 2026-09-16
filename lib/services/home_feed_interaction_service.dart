import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'engagement_service.dart';

class HomeFeedInteractionService {
  HomeFeedInteractionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    EngagementService? engagement,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _engagement = engagement ?? EngagementService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final EngagementService _engagement;

  Future<void> setLike({
    required String contentId,
    required bool liked,
    required bool saved,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || contentId.isEmpty) return;
    await _engagement.syncInteraction(
      reelId: contentId,
      liked: liked,
      saved: saved,
      likeDelta: liked ? 1 : -1,
    );
  }

  Future<void> setSave({
    required String contentId,
    required bool saved,
    required bool liked,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || contentId.isEmpty) return;
    await _engagement.syncInteraction(
      reelId: contentId,
      liked: liked,
      saved: saved,
      saveDelta: saved ? 1 : -1,
    );
  }

  Future<void> recordNegativeFeedback({
    required String contentId,
    required String type,
    String? creatorId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || contentId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('feedFeedback')
        .doc(contentId)
        .set(<String, dynamic>{
      'contentId': contentId,
      'creatorId': creatorId,
      'type': type,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
