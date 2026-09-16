import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/home_feed_models.dart';
import '../models/reel_model.dart';

class HomeFeedService {
  HomeFeedService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const int candidatePageSize = 20;
  static const int maxFinalItems = 10;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _reels =>
      _firestore.collection('reels');

  Future<HomeFeedPage> fetchPage({
    required HomeFeedContext context,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    final userId = context.userId.isNotEmpty
        ? context.userId
        : (_auth.currentUser?.uid ?? '');

    Query<Map<String, dynamic>> query = _buildCandidateQuery(context.mode)
        .limit(candidatePageSize);

    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }

    final snapshot = await query.get();
    final candidates = snapshot.docs
        .map(ReelModel.fromFirestore)
        .map((reel) => _toFeedItem(reel, context, userId))
        .where((item) => item.eligibility == HomeEligibilityStatus.eligible)
        .where((item) => !context.seenContentIds.contains(item.contentId))
        .where((item) => !context.negativeContentIds.contains(item.contentId))
        .where((item) => !context.mutedCreatorIds.contains(item.creatorId))
        .toList(growable: false);

    final ranked = _rerank(candidates, context);
    final selected = ranked.take(maxFinalItems).toList(growable: false);

    return HomeFeedPage(
      items: selected,
      cursor: snapshot.docs.isEmpty ? cursor : snapshot.docs.last,
      hasMore: snapshot.docs.length == candidatePageSize,
    );
  }

  Query<Map<String, dynamic>> _buildCandidateQuery(HomeFeedMode mode) {
    switch (mode) {
      case HomeFeedMode.latest:
        return _reels.orderBy('createdAt', descending: true);
      case HomeFeedMode.personalized:
      case HomeFeedMode.following:
      case HomeFeedMode.favorites:
      case HomeFeedMode.friends:
        // Relationship-specific retrieval will be added when the corresponding
        // follow/favorite/friend collections are wired to the Home contract.
        // Keeping one stable candidate source here avoids inventing a schema.
        return _reels.orderBy('algorithmScore', descending: true);
    }
  }

  HomeFeedItem _toFeedItem(
    ReelModel reel,
    HomeFeedContext context,
    String userId,
  ) {
    final ageHours = math.max(
      0,
      DateTime.now().toUtc().difference(reel.createdAt.toUtc()).inMinutes / 60,
    );
    final freshness = 1 / (1 + ageHours / 24);
    final engagement =
        (reel.likes * 1.0) +
        (reel.comments * 2.0) +
        (reel.saves * 2.5) +
        (reel.shares * 3.0);
    final quality = reel.views <= 0
        ? 0.0
        : (reel.watchTimeMs / math.max(1, reel.views)).clamp(0, 60000) / 60000;

    final score = (reel.algorithmScore * 0.60) +
        (freshness * 0.15) +
        ((engagement / 100000).clamp(0, 1) * 0.15) +
        (quality * 0.10);

    return HomeFeedItem(
      contentId: reel.id,
      creatorId: reel.creatorId,
      contentType: HomeContentType.video,
      mediaType: 'video',
      createdAt: reel.createdAt,
      source: _sourceFor(context.mode),
      eligibility: _readEligibility(reel, userId),
      rankingScore: score,
      thumbnailUrl: reel.thumbnailUrl.isEmpty ? null : reel.thumbnailUrl,
      mediaUrl: reel.hlsUrl.isEmpty ? null : reel.hlsUrl,
      caption: reel.caption,
      likes: reel.likes,
      comments: reel.comments,
      shares: reel.shares,
      saves: reel.saves,
      views: reel.views,
    );
  }

  HomeEligibilityStatus _readEligibility(ReelModel reel, String userId) {
    // The current ReelModel intentionally contains no moderation/private-state
    // fields. Therefore this layer never guesses those states from UI data.
    // Firestore Rules remain the authoritative access-control boundary.
    if (reel.id.isEmpty || reel.creatorId.isEmpty) {
      return HomeEligibilityStatus.rejected;
    }
    if (userId.isEmpty) {
      return HomeEligibilityStatus.restricted;
    }
    return HomeEligibilityStatus.eligible;
  }

  HomeFeedSource _sourceFor(HomeFeedMode mode) {
    switch (mode) {
      case HomeFeedMode.following:
        return HomeFeedSource.following;
      case HomeFeedMode.favorites:
        return HomeFeedSource.favorite;
      case HomeFeedMode.friends:
        return HomeFeedSource.friend;
      case HomeFeedMode.latest:
        return HomeFeedSource.fresh;
      case HomeFeedMode.personalized:
        return HomeFeedSource.suggested;
    }
  }

  List<HomeFeedItem> _rerank(
    List<HomeFeedItem> candidates,
    HomeFeedContext context,
  ) {
    final sorted = [...candidates]
      ..sort((a, b) {
        final score = b.rankingScore.compareTo(a.rankingScore);
        if (score != 0) return score;
        return b.createdAt.compareTo(a.createdAt);
      });

    // Lightweight creator diversity: do not put the same creator at the top
    // repeatedly when enough alternative candidates exist.
    final result = <HomeFeedItem>[];
    final creatorCounts = <String, int>{};
    final deferred = <HomeFeedItem>[];

    for (final item in sorted) {
      final count = creatorCounts[item.creatorId] ?? 0;
      if (count >= 2) {
        deferred.add(item);
        continue;
      }
      result.add(item);
      creatorCounts[item.creatorId] = count + 1;
    }

    result.addAll(deferred);
    return result;
  }
}
