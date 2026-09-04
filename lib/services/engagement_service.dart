import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EngagementService {
  EngagementService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> syncInteraction({
    required String reelId,
    required bool liked,
    required bool saved,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || reelId.trim().isEmpty) return;

    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('users').doc(uid).collection('interactions').doc(reelId),
      <String, dynamic>{
        'liked': liked,
        'saved': saved,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _firestore.collection('reels').doc(reelId),
      <String, dynamic>{
        'likes': FieldValue.increment(liked ? 1 : -1),
        'saves': FieldValue.increment(saved ? 1 : -1),
      },
      SetOptions(merge: true),
    );

    try {
      await batch.commit();
    } catch (error) {
      // Background engagement must never block feed interaction.
      // ignore: avoid_print
      print('OJAS engagement sync failed: $error');
    }
  }
}
