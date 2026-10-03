import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/social_interaction.dart';
import 'engagement_service.dart';
import 'safety_service.dart';

/// Master interaction command layer.
/// UI never talks to raw collections for social actions — only through here.
class SocialInteractionService {
  SocialInteractionService._();
  static final SocialInteractionService instance = SocialInteractionService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EngagementService _engagement = EngagementService();
  final SafetyService _safety = SafetyService.instance;

  String? get _uid => _auth.currentUser?.uid;

  String newClientActionId() {
    final r = Random.secure();
    final t = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'ca_${t}_${r.nextInt(1 << 32).toRadixString(16)}';
  }

  // ─── LIKE / SAVE (delegates to engagement + interactions path) ───

  Future<void> setContentLike({
    required String contentId,
    required bool liked,
    bool? currentlySaved,
    String? clientActionId,
  }) async {
    final uid = _uid;
    if (uid == null || contentId.isEmpty) return;
    await _engagement.syncInteraction(
      reelId: contentId,
      liked: liked,
      saved: currentlySaved ?? false,
      likeDelta: liked ? 1 : -1,
    );
    await _writeActivity(
      action: liked ? 'like' : 'unlike',
      targetType: 'content',
      targetId: contentId,
      clientActionId: clientActionId,
    );
  }

  Future<void> setContentSave({
    required String contentId,
    required bool saved,
    required bool currentlyLiked,
    String? clientActionId,
  }) async {
    final uid = _uid;
    if (uid == null || contentId.isEmpty) return;
    await _engagement.syncInteraction(
      reelId: contentId,
      liked: currentlyLiked,
      saved: saved,
      saveDelta: saved ? 1 : -1,
    );
    await _writeActivity(
      action: saved ? 'save' : 'unsave',
      targetType: 'content',
      targetId: contentId,
      clientActionId: clientActionId,
    );
  }

  // ─── FOLLOW / UNFOLLOW ───

  Future<void> setFollow({
    required String targetUserId,
    required bool following,
    InteractionSource source = InteractionSource.unknown,
    String? clientActionId,
  }) async {
    final uid = _uid;
    final target = targetUserId.trim();
    if (uid == null || target.isEmpty || uid == target) {
      throw const SocialInteractionException('Invalid follow target.');
    }

    if (await _safety.isBlocked(target)) {
      throw const SocialInteractionException('Cannot follow a blocked user.');
    }

    // Edge doc for scalable graph queries (unique follower→following).
    final edgeId = '${uid}_$target';
    final edgeRef = _db.collection('socialEdges').doc(edgeId);

    if (following) {
      await edgeRef.set({
        'followerId': uid,
        'followingId': target,
        'state': 'active',
        'source': source.name,
        'clientActionId': clientActionId ?? newClientActionId(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await edgeRef.set({
        'state': 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // Keep publicProfiles counts/lists in sync (existing UI depends on this).
    await _engagement.setFollowState(creatorId: target, following: following);

    await _writeActivity(
      action: following ? 'follow' : 'unfollow',
      targetType: 'profile',
      targetId: target,
      clientActionId: clientActionId,
      metadata: {'source': source.name},
    );
  }

  Future<RelationshipState> relationshipWith(String otherUserId) async {
    final uid = _uid;
    final other = otherUserId.trim();
    if (uid == null || other.isEmpty || uid == other) {
      return RelationshipState.none;
    }
    if (await _safety.isBlocked(other)) return RelationshipState.blocked;

    final a = await _db.collection('socialEdges').doc('${uid}_$other').get();
    final b = await _db.collection('socialEdges').doc('${other}_$uid').get();
    final aActive = a.exists && (a.data()?['state'] == 'active');
    final bActive = b.exists && (b.data()?['state'] == 'active');
    if (aActive && bActive) return RelationshipState.mutual;
    if (aActive) return RelationshipState.following;
    if (bActive) return RelationshipState.followedBy;
    return RelationshipState.none;
  }

  // ─── COMMENTS ───

  CollectionReference<Map<String, dynamic>> _comments(String contentId) =>
      _db.collection('reels').doc(contentId).collection('comments');

  Stream<List<SocialComment>> watchComments(String contentId, {int limit = 50}) {
    if (contentId.isEmpty) {
      return Stream.value(const <SocialComment>[]);
    }
    return _comments(contentId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SocialComment.fromMap(d.id, d.data()))
            .where((c) => !c.isDeleted)
            .toList());
  }

  Future<SocialComment> postComment({
    required String contentId,
    required String text,
    String? parentCommentId,
    String? rootCommentId,
    String? clientActionId,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw const SocialInteractionException('Please sign in to comment.');
    }
    final clean = text.trim();
    if (contentId.isEmpty || clean.isEmpty) {
      throw const SocialInteractionException('Comment cannot be empty.');
    }
    if (clean.length > 1000) {
      throw const SocialInteractionException('Comment is too long.');
    }

    final actionId = clientActionId ?? newClientActionId();

    // Idempotency: if same clientActionId already exists under this content, return it.
    final existing = await _comments(contentId)
        .where('clientActionId', isEqualTo: actionId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      final d = existing.docs.first;
      return SocialComment.fromMap(d.id, d.data());
    }

    String authorName = 'OJAS User';
    try {
      final profile = await _db.collection('publicProfiles').doc(uid).get();
      final dn = profile.data()?['displayName'];
      if (dn is String && dn.trim().isNotEmpty) authorName = dn.trim();
    } catch (_) {}

    final ref = _comments(contentId).doc();
    final data = <String, dynamic>{
      'contentId': contentId,
      'authorId': uid,
      'authorName': authorName,
      'text': clean,
      'parentCommentId': parentCommentId,
      'rootCommentId': rootCommentId ?? parentCommentId,
      'likeCount': 0,
      'replyCount': 0,
      'isDeleted': false,
      'status': 'published',
      'clientActionId': actionId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();
    batch.set(ref, data);
    batch.set(
      _db.collection('reels').doc(contentId),
      {
        'comments': FieldValue.increment(1),
        'commentsCount': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );
    if (parentCommentId != null && parentCommentId.isNotEmpty) {
      batch.set(
        _comments(contentId).doc(parentCommentId),
        {'replyCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    await _writeActivity(
      action: parentCommentId == null ? 'comment' : 'reply',
      targetType: 'content',
      targetId: contentId,
      clientActionId: actionId,
      metadata: {
        'commentId': ref.id,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
      },
    );

    return SocialComment(
      id: ref.id,
      contentId: contentId,
      authorId: uid,
      authorName: authorName,
      text: clean,
      parentCommentId: parentCommentId,
      rootCommentId: rootCommentId ?? parentCommentId,
      clientActionId: actionId,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Future<void> deleteComment({
    required String contentId,
    required String commentId,
  }) async {
    final uid = _uid;
    if (uid == null || contentId.isEmpty || commentId.isEmpty) return;

    final ref = _comments(contentId).doc(commentId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    if (data['authorId'] != uid) {
      throw const SocialInteractionException('You can only delete your own comments.');
    }

    final batch = _db.batch();
    batch.set(
      ref,
      {
        'isDeleted': true,
        'text': 'This comment was deleted.',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _db.collection('reels').doc(contentId),
      {
        'comments': FieldValue.increment(-1),
        'commentsCount': FieldValue.increment(-1),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // ─── SHARE TRACKING ───

  Future<void> trackShare(ShareTrackEvent event) async {
    final uid = _uid;
    if (uid == null || event.contentId.isEmpty) return;
    final actionId = event.clientActionId ?? newClientActionId();
    await _db.collection('users').doc(uid).collection('shareEvents').doc(actionId).set({
      'contentId': event.contentId,
      'channel': event.channel,
      'intent': event.intent,
      'destination': event.destination,
      'clientActionId': actionId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Soft counter — analytics only; not ranking-critical alone.
    if (event.intent == 'completed' || event.intent == 'copied') {
      try {
        await _db.collection('reels').doc(event.contentId).set({
          'shares': FieldValue.increment(1),
          'shareCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  // ─── ACTIVITY (private, for recommendation / history) ───

  Future<void> _writeActivity({
    required String action,
    required String targetType,
    required String targetId,
    String? clientActionId,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final id = clientActionId ?? newClientActionId();
      await _db
          .collection('users')
          .doc(uid)
          .collection('activity')
          .doc(id)
          .set({
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'clientActionId': id,
        'metadata': metadata ?? <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Activity is best-effort — never fail the user action.
    }
  }
}

class SocialInteractionException implements Exception {
  const SocialInteractionException(this.message);
  final String message;
  @override
  String toString() => message;
}
