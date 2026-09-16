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
    bool? saved,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || contentId.isEmpty) return;
    var savedState = saved;
    if (savedState == null) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('interactions')
            .doc(contentId)
            .get();
        savedState = snapshot.data()?['saved'] as bool? ?? false;
      } catch (_) {
        savedState = false;
      }
    }
    final bool savedForSync = savedState ?? false;
    await _engagement.syncInteraction(
      reelId: contentId,
      liked: liked,
      saved: savedForSync,
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

  Future<List<String>> loadMutedCreatorIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return const <String>[];
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('feedFeedback')
        .where('type', isEqualTo: 'mute_creator')
        .limit(100)
        .get();
    final ids = <String>{};
    for (final doc in snapshot.docs) {
      final creatorId = doc.data()['creatorId'] as String?;
      if (creatorId != null && creatorId.trim().isNotEmpty) {
        ids.add(creatorId.trim());
      }
    }
    return ids.toList(growable: false);
  }

  Future<void> resetRecommendationControls() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final interestRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('feedProfile')
        .doc('interest');
    await interestRef.set(<String, dynamic>{
      'creatorAffinity': <String, double>{},
      'topicAffinity': <String, double>{},
      'hashtagAffinity': <String, double>{},
      'soundAffinity': <String, double>{},
      'contentTypeAffinity': <String, double>{},
      'negativeAffinity': <String, double>{},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final feedbackSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('feedFeedback')
        .limit(100)
        .get();
    final resettableTypes = <String>{
      'not_interested',
      'hide',
      'mute_creator',
    };
    final resettableDocs = feedbackSnapshot.docs.where(
      (doc) => resettableTypes.contains(doc.data()['type']),
    );
    final batch = _firestore.batch();
    var count = 0;
    for (final doc in resettableDocs) {
      batch.delete(doc.reference);
      count++;
      if (count >= 100) break;
    }
    if (count > 0) await batch.commit();
  }

  Future<void> removeNegativeFeedbackForCreator({
    required String creatorId,
    required String type,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || creatorId.isEmpty) return;
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('feedFeedback')
        .where('creatorId', isEqualTo: creatorId)
        .limit(100)
        .get();
    final matchingDocs = snapshot.docs.where(
      (doc) => doc.data()['type'] == type,
    );
    final batch = _firestore.batch();
    var count = 0;
    for (final doc in matchingDocs) {
      batch.delete(doc.reference);
      count++;
      if (count >= 100) break;
    }
    if (count > 0) await batch.commit();
  }
}
