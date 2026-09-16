import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/home_feed_models.dart';
import '../models/reel_model.dart';
import '../models/home_feed_runtime_models.dart';
import 'ranking/home_feed_ranker.dart';

class HomeFeedService {
  HomeFeedService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    HomeFeedRanker? ranker,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _ranker = ranker ?? const DefaultHomeFeedRanker();

  static const int candidatePageSize = 20;
  static const int finalPageSize = 10;
  static const int maxWhereInIds = 30;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final HomeFeedRanker _ranker;

  CollectionReference<Map<String, dynamic>> get _reels =>
      _firestore.collection('reels');

  Future<HomeFeedPage> fetchPage({
    required HomeFeedContext context,
    required HomeFeedInterestProfile interest,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    final userId = context.userId.isNotEmpty
        ? context.userId
        : (_auth.currentUser?.uid ?? '');
    if (userId.isEmpty) {
      return const HomeFeedPage(items: <HomeFeedItem>[], hasMore: false);
    }

    final snapshot = await _fetchCandidates(
      mode: context.mode,
      userId: userId,
      cursor: cursor,
    );

    final candidates = <HomeFeedItem>[];
    for (final doc in snapshot.docs) {
      final item = _toFeedItem(doc, context, userId);
      if (item.eligibility != HomeEligibilityStatus.eligible) continue;
      if (context.seenContentIds.contains(item.contentId)) continue;
      if (context.negativeContentIds.contains(item.contentId)) continue;
      if (context.mutedCreatorIds.contains(item.creatorId)) continue;
      if (context.blockedCreatorIds.contains(item.creatorId)) continue;
      candidates.add(item);
    }

    final ranked = _ranker.rank(
      candidates: candidates,
      interest: interest,
      mode: context.mode,
    );
    final selected = ranked.take(finalPageSize).toList(growable: false);

    return HomeFeedPage(
      items: selected,
      cursor: snapshot.docs.isEmpty ? cursor : snapshot.docs.last,
      hasMore: snapshot.docs.length >= candidatePageSize,
    );
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchCandidates({
    required HomeFeedMode mode,
    required String userId,
    required DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    switch (mode) {
      case HomeFeedMode.latest:
        return _runQuery(
          _reels.orderBy('createdAt', descending: true),
          cursor,
        );
      case HomeFeedMode.following:
        final following = await _readFollowing(userId);
        if (following.isEmpty) return _emptySnapshot();
        final ids = following.take(maxWhereInIds).toList(growable: false);
        return _runQuery(
          _reels
              .where('creatorId', whereIn: ids)
              .orderBy('createdAt', descending: true),
          cursor,
        );
      case HomeFeedMode.favorites:
        final savedIds = await _readSavedContentIds(userId);
        if (savedIds.isEmpty) return _emptySnapshot();
        return _runQuery(
          _reels
              .where(
                FieldPath.documentId,
                whereIn: savedIds.take(maxWhereInIds).toList(),
              )
              .orderBy('createdAt', descending: true),
          cursor,
        );
      case HomeFeedMode.personalized:
        // Candidate generation is intentionally broad. Ranking happens through
        // the dedicated ranker and never trusts client-visible algorithmScore.
        return _runQuery(
          _reels.orderBy('createdAt', descending: true),
          cursor,
        );
      case HomeFeedMode.friends:
        // A verified friend graph is not present in the repository schema yet.
        // Returning an empty set is safer than silently showing unrelated posts.
        return _emptySnapshot();
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _runQuery(
    Query<Map<String, dynamic>> query,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  ) {
    var prepared = query.limit(candidatePageSize);
    if (cursor != null) prepared = prepared.startAfterDocument(cursor);
    return prepared.get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _emptySnapshot() async {
    return _reels.where(FieldPath.documentId, isEqualTo: '__ojas_empty__').get();
  }

  Future<List<String>> _readFollowing(String userId) async {
    final snapshot = await _firestore.collection('publicProfiles').doc(userId).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final values = data['following'];
    if (values is! List) return const <String>[];
    return values
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> _readSavedContentIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('interactions')
          .where('saved', isEqualTo: true)
          .limit(maxWhereInIds)
          .get();
      return snapshot.docs
          .map((doc) => doc.id)
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  HomeFeedItem _toFeedItem(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    HomeFeedContext context,
    String userId,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final reel = ReelModel.fromFirestore(snapshot);
    final ageHours = math.max(
      0,
      DateTime.now().toUtc().difference(reel.createdAt.toUtc()).inMinutes / 60,
    );
    final freshness = 1 / (1 + ageHours / 24);
    final engagement =
        reel.likes.toDouble() +
        (reel.comments * 2.0) +
        (reel.saves * 2.5) +
        (reel.shares * 3.0);
    final avgWatchMs = reel.views <= 0 ? 0 : reel.watchTimeMs / reel.views;
    final watchQuality = (avgWatchMs / 60000).clamp(0.0, 1.0);

    final eligibility = _readEligibility(data, reel, userId);
    final mediaSources = _readStringList(data['mediaSources']);
    final hashtags = _readStringList(data['hashtags']);
    final mentions = _readStringList(data['mentions']);
    final contentType = switch (data['contentType']) {
      'post' => HomeContentType.post,
      'carousel' => HomeContentType.carousel,
      'video' => HomeContentType.video,
      _ => HomeContentType.video,
    };

    return HomeFeedItem(
      contentId: reel.id,
      creatorId: reel.creatorId,
      contentType: contentType,
      mediaType: (data['mediaType'] as String?) ?? 'video',
      createdAt: reel.createdAt,
      source: _sourceFor(context.mode),
      eligibility: eligibility,
      rankingScore: 0,
      mediaSources: mediaSources.isEmpty && reel.hlsUrl.isNotEmpty
          ? <String>[reel.hlsUrl]
          : mediaSources,
      thumbnailUrl: reel.thumbnailUrl.isEmpty ? null : reel.thumbnailUrl,
      mediaUrl: reel.hlsUrl.isEmpty ? null : reel.hlsUrl,
      caption: reel.caption,
      hashtags: hashtags,
      mentions: mentions,
      soundId: reel.audioTrackId.isEmpty ? null : reel.audioTrackId,
      location: data['location'] as String?,
      likes: reel.likes,
      comments: reel.comments,
      shares: reel.shares,
      saves: reel.saves,
      views: reel.views,
      recommendationReason: _recommendationReason(context.mode, data),
      rankingContext: <String, double>{
        'freshness': freshness,
        'engagement': (engagement / 100000).clamp(0.0, 1.0),
        'watchQuality': watchQuality,
      },
      trackingToken: '${context.sessionId}:${reel.id}',
      visibility: (data['visibility'] as String?) ?? 'public',
      recommendationEligible: data['recommendationEligible'] as bool? ?? true,
    );
  }

  HomeEligibilityStatus _readEligibility(
    Map<String, dynamic> data,
    ReelModel reel,
    String userId,
  ) {
    if (reel.id.isEmpty || reel.creatorId.isEmpty || userId.isEmpty) {
      return HomeEligibilityStatus.restricted;
    }
    if (data['deleted'] == true) return HomeEligibilityStatus.rejected;
    if (data['private'] == true) return HomeEligibilityStatus.filtered;
    if (data['ageRestricted'] == true) return HomeEligibilityStatus.restricted;
    if (data['recommendationEligible'] == false) return HomeEligibilityStatus.filtered;
    if ((data['moderationStatus'] as String?) == 'rejected') {
      return HomeEligibilityStatus.rejected;
    }
    if ((data['copyrightStatus'] as String?) == 'blocked') {
      return HomeEligibilityStatus.rejected;
    }
    if (data['spam'] == true) return HomeEligibilityStatus.rejected;
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

  String? _recommendationReason(
    HomeFeedMode mode,
    Map<String, dynamic> data,
  ) {
    final explicit = data['recommendationReason'] as String?;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    switch (mode) {
      case HomeFeedMode.following:
        return 'Because you follow this creator';
      case HomeFeedMode.favorites:
        return 'From your saved interests';
      case HomeFeedMode.latest:
        return 'Recently published';
      case HomeFeedMode.friends:
        return null;
      case HomeFeedMode.personalized:
        return null;
    }
  }

  List<String> _readStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }
}
