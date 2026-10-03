import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'safety_service.dart';

class EngagementService {
  EngagementService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> setFollowState({
    required String creatorId,
    required bool following,
  }) async {
    final uid = _auth.currentUser?.uid;
    final targetId = creatorId.trim();

    if (uid == null || uid.isEmpty || targetId.isEmpty || uid == targetId) {
      return;
    }

    if (await SafetyService.instance.isBlocked(targetId)) {
      throw StateError('Cannot follow a blocked user.');
    }

    final currentUserRef = _firestore.collection('publicProfiles').doc(uid);
    final creatorRef = _firestore.collection('publicProfiles').doc(targetId);

    await _firestore.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(currentUserRef);
      final creatorSnapshot = await transaction.get(creatorRef);

      if (!creatorSnapshot.exists) {
        throw StateError('Creator profile not found.');
      }

      final currentData = currentSnapshot.data() ?? const <String, dynamic>{};
      final creatorData = creatorSnapshot.data() ?? const <String, dynamic>{};
      final currentFollowing = _stringList(currentData['following']);
      final alreadyFollowing = currentFollowing.contains(targetId);

      if (alreadyFollowing == following) return;

      if (following) {
        transaction.set(
          currentUserRef,
          <String, dynamic>{
            'following': FieldValue.arrayUnion(<String>[targetId]),
            'followingCount': FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );
        transaction.set(
          creatorRef,
          <String, dynamic>{
            'followers': FieldValue.arrayUnion(<String>[uid]),
            'followersCount': FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );
      } else {
        transaction.set(
          currentUserRef,
          <String, dynamic>{
            'following': FieldValue.arrayRemove(<String>[targetId]),
            'followingCount': FieldValue.increment(-1),
          },
          SetOptions(merge: true),
        );
        transaction.set(
          creatorRef,
          <String, dynamic>{
            'followers': FieldValue.arrayRemove(<String>[uid]),
            'followersCount': FieldValue.increment(-1),
          },
          SetOptions(merge: true),
        );
      }
    });
  }

  /// Alias used by some UI call sites.
  Future<void> syncFollow({
    required String creatorId,
    required bool following,
  }) =>
      setFollowState(creatorId: creatorId, following: following);

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

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
