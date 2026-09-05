import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      final creatorFollowers = _stringList(creatorData['followers']);
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

      // Keep these reads as the authoritative state check for idempotent UI retries.
      if (following && creatorFollowers.contains(uid)) return;
      if (!following && !creatorFollowers.contains(uid)) return;
    });
  }

  Future<void> syncFollow({
    required String creatorId,
    required bool following,
  }) async {
    try {
      await setFollowState(creatorId: creatorId, following: following);
    } catch (error) {
      // Background engagement must never block feed interaction.
      // ignore: avoid_print
      print('OJAS follow sync failed: $error');
    }
  }

  Future<void> syncWatchMetrics({
    required String reelId,
    required int watchTimeMs,
    int completionDelta = 0,
  }) async {
    if (reelId.trim().isEmpty || (watchTimeMs <= 0 && completionDelta == 0)) return;
    try {
      await _firestore.collection('reels').doc(reelId).set(<String, dynamic>{
        'watchTimeMs': FieldValue.increment(watchTimeMs),
        'completions': FieldValue.increment(completionDelta),
      }, SetOptions(merge: true));
    } catch (error) {
      // ignore: avoid_print
      print('OJAS watch metrics sync failed: $error');
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

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
