import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/social_interaction.dart';
import 'engagement_service.dart';
import 'safety_service.dart';

/// Master interaction command layer for OJAS social graph.
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

  // ─── LIKE / SAVE ───

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
    String? collectionId,
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
    if (saved && collectionId != null && collectionId.isNotEmpty) {
      await _db
          .collection('users')
          .doc(uid)
          .collection('collections')
          .doc(collectionId)
          .collection('items')
          .doc(contentId)
          .set({
        'contentId': contentId,
        'savedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _db
          .collection('users')
          .doc(uid)
          .collection('collections')
          .doc(collectionId)
          .set({'itemCount': FieldValue.increment(1)}, SetOptions(merge: true));
    }
    await _writeActivity(
      action: saved ? 'save' : 'unsave',
      targetType: 'content',
      targetId: contentId,
      clientActionId: clientActionId,
      metadata: {if (collectionId != null) 'collectionId': collectionId},
    );
  }

  // ─── COLLECTIONS ───

  Future<SaveCollection> createCollection(String name, {bool isPrivate = true}) async {
    final uid = _uid;
    if (uid == null) throw const SocialInteractionException('Sign in required.');
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 60) {
      throw const SocialInteractionException('Invalid collection name.');
    }
    final ref = _db.collection('users').doc(uid).collection('collections').doc();
    await ref.set({
      'ownerId': uid,
      'name': clean,
      'coverUrl': '',
      'itemCount': 0,
      'isPrivate': isPrivate,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return SaveCollection(
      id: ref.id,
      ownerId: uid,
      name: clean,
      isPrivate: isPrivate,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Stream<List<SaveCollection>> watchCollections() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <SaveCollection>[]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('collections')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((s) => s.docs
            .map((d) => SaveCollection.fromMap(d.id, d.data()))
            .toList());
  }

  // ─── FOLLOW + PRIVATE REQUESTS ───

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

    if (following) {
      final profile = await _db.collection('publicProfiles').doc(target).get();
      final isPrivate = profile.data()?['isPrivate'] == true;
      if (isPrivate) {
        await _sendFollowRequest(
          targetId: target,
          source: source,
          clientActionId: clientActionId,
        );
        return;
      }
    }

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
      // Cancel pending request if any
      final reqId = '${uid}_$target';
      try {
        await _db.collection('followRequests').doc(reqId).set({
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    await _engagement.setFollowState(creatorId: target, following: following);
    await _writeActivity(
      action: following ? 'follow' : 'unfollow',
      targetType: 'profile',
      targetId: target,
      clientActionId: clientActionId,
      metadata: {'source': source.name},
    );
  }

  Future<void> _sendFollowRequest({
    required String targetId,
    required InteractionSource source,
    String? clientActionId,
  }) async {
    final uid = _uid!;
    final reqId = '${uid}_$targetId';
    String requesterName = 'OJAS User';
    try {
      final p = await _db.collection('publicProfiles').doc(uid).get();
      final dn = p.data()?['displayName'];
      if (dn is String && dn.trim().isNotEmpty) requesterName = dn.trim();
    } catch (_) {}

    await _db.collection('followRequests').doc(reqId).set({
      'requesterId': uid,
      'targetId': targetId,
      'requesterName': requesterName,
      'status': 'pending',
      'source': source.name,
      'clientActionId': clientActionId ?? newClientActionId(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _writeActivity(
      action: 'follow_request',
      targetType: 'profile',
      targetId: targetId,
      clientActionId: clientActionId,
    );
  }

  Future<void> acceptFollowRequest(String requestId) async {
    final uid = _uid;
    if (uid == null || requestId.isEmpty) return;
    final ref = _db.collection('followRequests').doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    if (data['targetId'] != uid || data['status'] != 'pending') {
      throw const SocialInteractionException('Invalid follow request.');
    }
    final requesterId = data['requesterId'] as String? ?? '';
    if (requesterId.isEmpty) return;

    final batch = _db.batch();
    batch.set(ref, {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_db.collection('socialEdges').doc('${requesterId}_$uid'), {
      'followerId': requesterId,
      'followingId': uid,
      'state': 'active',
      'source': 'follow_request',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();

    // Update counts via engagement as the requester would
    // Direct count update on both profiles
    await _db.collection('publicProfiles').doc(requesterId).set({
      'following': FieldValue.arrayUnion([uid]),
      'followingCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await _db.collection('publicProfiles').doc(uid).set({
      'followers': FieldValue.arrayUnion([requesterId]),
      'followersCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await _writeActivity(
      action: 'follow_accept',
      targetType: 'profile',
      targetId: requesterId,
    );
  }

  Future<void> declineFollowRequest(String requestId) async {
    final uid = _uid;
    if (uid == null || requestId.isEmpty) return;
    final ref = _db.collection('followRequests').doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) return;
    if (snap.data()?['targetId'] != uid) return;
    await ref.set({
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<FollowRequest>> watchIncomingFollowRequests() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <FollowRequest>[]);
    return _db
        .collection('followRequests')
        .where('targetId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(30)
        .snapshots()
        .map((s) => s.docs
            .map((d) => FollowRequest.fromMap(d.id, d.data()))
            .toList());
  }

  Future<RelationshipState> relationshipWith(String otherUserId) async {
    final uid = _uid;
    final other = otherUserId.trim();
    if (uid == null || other.isEmpty || uid == other) {
      return RelationshipState.none;
    }
    if (await _safety.isBlocked(other)) return RelationshipState.blocked;

    final reqId = '${uid}_$other';
    final req = await _db.collection('followRequests').doc(reqId).get();
    if (req.exists && req.data()?['status'] == 'pending') {
      return RelationshipState.requestSent;
    }
    final incoming = await _db.collection('followRequests').doc('${other}_$uid').get();
    if (incoming.exists && incoming.data()?['status'] == 'pending') {
      return RelationshipState.requestReceived;
    }

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

  Stream<List<SocialComment>> watchComments(
    String contentId, {
    int limit = 50,
    CommentSort sort = CommentSort.newest,
  }) {
    if (contentId.isEmpty) {
      return Stream.value(const <SocialComment>[]);
    }
    Query<Map<String, dynamic>> q = _comments(contentId);
    if (sort == CommentSort.top) {
      q = q.orderBy('likeCount', descending: true).orderBy('createdAt', descending: true);
    } else {
      q = q.orderBy('createdAt', descending: true);
    }
    return q.limit(limit).snapshots().asyncMap((snap) async {
      final uid = _uid;
      final likedIds = <String>{};
      if (uid != null && snap.docs.isNotEmpty) {
        try {
          final likesSnap = await _db
              .collection('users')
              .doc(uid)
              .collection('commentLikes')
              .where('contentId', isEqualTo: contentId)
              .limit(100)
              .get();
          for (final d in likesSnap.docs) {
            final cid = d.data()['commentId'] as String?;
            if (cid != null) likedIds.add(cid);
          }
        } catch (_) {}
      }
      return snap.docs
          .map((d) => SocialComment.fromMap(
                d.id,
                d.data(),
                likedByMe: likedIds.contains(d.id),
              ))
          .where((c) => !c.isDeleted)
          .toList();
    });
  }

  /// Parse @mentions of form @ojasId from text against publicProfiles.
  Future<List<MentionRef>> resolveMentions(String text) async {
    final regex = RegExp(r'@([a-zA-Z0-9_]{2,32})');
    final matches = regex.allMatches(text);
    if (matches.isEmpty) return const [];
    final result = <MentionRef>[];
    for (final m in matches) {
      final handle = m.group(1)!;
      try {
        final q = await _db
            .collection('publicProfiles')
            .where('ojasId', isEqualTo: handle.toLowerCase())
            .limit(1)
            .get();
        if (q.docs.isEmpty) continue;
        final doc = q.docs.first;
        final dn = doc.data()['displayName'] as String? ?? handle;
        result.add(MentionRef(
          userId: doc.id,
          startIndex: m.start,
          endIndex: m.end,
          displayName: dn,
        ));
      } catch (_) {}
    }
    return result;
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

    final mentions = await resolveMentions(clean);

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
      'mentions': mentions.map((m) => m.toMap()).toList(),
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
        if (mentions.isNotEmpty)
          'mentionedUserIds': mentions.map((m) => m.userId).toList(),
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
      mentions: mentions,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Future<void> editComment({
    required String contentId,
    required String commentId,
    required String text,
  }) async {
    final uid = _uid;
    if (uid == null) throw const SocialInteractionException('Sign in required.');
    final clean = text.trim();
    if (clean.isEmpty || clean.length > 1000) {
      throw const SocialInteractionException('Invalid comment text.');
    }
    final ref = _comments(contentId).doc(commentId);
    final snap = await ref.get();
    if (!snap.exists || snap.data()?['authorId'] != uid) {
      throw const SocialInteractionException('You can only edit your own comments.');
    }
    final mentions = await resolveMentions(clean);
    await ref.set({
      'text': clean,
      'mentions': mentions.map((m) => m.toMap()).toList(),
      'editedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  Future<void> setCommentLike({
    required String contentId,
    required String commentId,
    required bool liked,
    String? clientActionId,
  }) async {
    final uid = _uid;
    if (uid == null || contentId.isEmpty || commentId.isEmpty) return;

    final likeRef = _db
        .collection('users')
        .doc(uid)
        .collection('commentLikes')
        .doc('${contentId}_$commentId');
    final commentRef = _comments(contentId).doc(commentId);

    final existing = await likeRef.get();
    final already = existing.exists;
    if (liked == already) return; // idempotent

    final batch = _db.batch();
    if (liked) {
      batch.set(likeRef, {
        'contentId': contentId,
        'commentId': commentId,
        'createdAt': FieldValue.serverTimestamp(),
        'clientActionId': clientActionId ?? newClientActionId(),
      });
      batch.set(commentRef, {'likeCount': FieldValue.increment(1)}, SetOptions(merge: true));
    } else {
      batch.delete(likeRef);
      batch.set(commentRef, {'likeCount': FieldValue.increment(-1)}, SetOptions(merge: true));
    }
    await batch.commit();

    await _writeActivity(
      action: liked ? 'comment_like' : 'comment_unlike',
      targetType: 'comment',
      targetId: commentId,
      clientActionId: clientActionId,
      metadata: {'contentId': contentId},
    );
  }

  // ─── SHARE TRACKING ───

  Future<void> trackShare(ShareTrackEvent event) async {
    final uid = _uid;
    if (uid == null || event.contentId.isEmpty) return;
    final actionId = event.clientActionId ?? newClientActionId();
    await _db
        .collection('users')
        .doc(uid)
        .collection('shareEvents')
        .doc(actionId)
        .set({
      'contentId': event.contentId,
      'channel': event.channel,
      'intent': event.intent,
      'destination': event.destination,
      'clientActionId': actionId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (event.intent == 'completed' || event.intent == 'copied') {
      try {
        await _db.collection('reels').doc(event.contentId).set({
          'shares': FieldValue.increment(1),
          'shareCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    await _writeActivity(
      action: 'share',
      targetType: 'content',
      targetId: event.contentId,
      clientActionId: actionId,
      metadata: {
        'channel': event.channel,
        'intent': event.intent,
        if (event.destination != null) 'destination': event.destination,
      },
    );
  }

  // ─── ACTIVITY ───

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
    } catch (_) {}
  }
}

class SocialInteractionException implements Exception {
  const SocialInteractionException(this.message);
  final String message;
  @override
  String toString() => message;
}
