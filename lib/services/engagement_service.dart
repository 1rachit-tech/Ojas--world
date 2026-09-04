import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EngagementService {
  EngagementService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> syncFollow({
    required String creatorId,
    required bool following,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null ||
        uid.isEmpty ||
        creatorId.trim().isEmpty ||
        uid == creatorId) {
      return;
    }
    final followingRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(creatorId);
    final creatorRef = _firestore.collection('users').doc(creatorId);
    final batch = _firestore.batch();
    if (following) {
      batch.set(followingRef, <String, dynamic>{
        'following': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      batch.delete(followingRef);
    }
    batch.set(creatorRef, <String, dynamic>{
      'followersCount': FieldValue.increment(following ? 1 : -1),
    }, SetOptions(merge: true));
    try {
      await batch.commit();
    } catch (error) {
      // ignore: avoid_print
      print('OJAS follow sync failed: $error');
    }
  }

  Future<void> syncInteraction({
    required String reelId,
    required bool liked,
    required bool saved,
    int likeDelta = 0,
    int saveDelta = 0,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || reelId.trim().isEmpty) return;

    final batch = _firestore.batch();
    batch.set(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('interactions')
          .doc(reelId),
      <String, dynamic>{
        'liked': liked,
        'saved': saved,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(_firestore.collection('reels').doc(reelId), <String, dynamic>{
      'likes': FieldValue.increment(likeDelta),
      'saves': FieldValue.increment(saveDelta),
    }, SetOptions(merge: true));

    try {
      await batch.commit();
    } catch (error) {
      // Background engagement must never block feed interaction.
      // ignore: avoid_print
      print('OJAS engagement sync failed: $error');
    }
  }
}
