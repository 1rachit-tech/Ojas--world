import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/home_feed_models.dart';
import '../models/home_feed_runtime_models.dart';
import '../services/home_feed_cache_service.dart';
import '../services/home_feed_event_queue.dart';
import '../services/home_feed_interaction_service.dart';
import '../services/home_feed_runtime_service.dart';
import '../services/home_feed_service.dart';

class HomeFeedController extends ChangeNotifier {
  HomeFeedController({
    HomeFeedService? service,
    HomeFeedEventQueue? eventQueue,
    HomeFeedCacheService? cache,
    HomeFeedInteractionService? interactions,
    HomeFeedRuntimeService? runtime,
    FirebaseAuth? auth,
  })  : _service = service ?? HomeFeedService(),
        _eventQueue = eventQueue ?? HomeFeedEventQueue(),
        _cache = cache ?? HomeFeedCacheService(),
        _interactions = interactions ?? HomeFeedInteractionService(),
        _runtime = runtime ?? HomeFeedRuntimeService(),
        _auth = auth ?? FirebaseAuth.instance;

  final HomeFeedService _service;
  final HomeFeedEventQueue _eventQueue;
  final HomeFeedCacheService _cache;
  final HomeFeedInteractionService _interactions;
  final HomeFeedRuntimeService _runtime;
  final FirebaseAuth _auth;

  final List<HomeFeedItem> _items = <HomeFeedItem>[];
  final Set<String> _seen = <String>{};
  final Set<String> _impressionsSent = <String>{};
  final Set<String> _negativeContent = <String>{};
  final Set<String> _mutedCreators = <String>{};
  final Set<String> _blockedCreators = <String>{};
  final Set<String> _liked = <String>{};
  final Set<String> _saved = <String>{};

  HomeSessionState? _session;
  HomeFeedMode _mode = HomeFeedMode.personalized;
  bool _loading = false;
  bool _refreshing = false;
  bool _hasMore = true;
  Object? _error;
  double _restoredScrollOffset = 0;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  List<HomeFeedItem> get items => List.unmodifiable(_items);
  HomeFeedMode get mode => _mode;
  bool get isLoading => _loading;
  bool get isRefreshing => _refreshing;
  bool get hasMore => _hasMore;
  Object? get error => _error;
  HomeSessionState? get session => _session;
  HomeFeedRemoteConfig get remoteConfig => _runtime.config;
  HomeFeedExperimentVariant get experimentVariant => _runtime.assignExperiment();
  double get restoredScrollOffset => _restoredScrollOffset;
  List<String> get mutedCreatorIds => List.unmodifiable(_mutedCreators);
  List<String> get managedTopics => List.unmodifiable(
        _runtime.interest.topicAffinity.entries
            .where((entry) => entry.value > 0)
            .map((entry) => entry.key),
      );
  bool isLiked(String id) => _liked.contains(id);
  bool isSaved(String id) => _saved.contains(id);

  Future<void> initialize() async {
    if (_session != null) return;
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      _error = StateError('A signed-in user is required for Home Feed.');
      notifyListeners();
      return;
    }

    await _eventQueue.initialize();
    await _runtime.initialize();
    final restored = await _runtime.restoreSession();
    _restoredScrollOffset = restored?.scrollOffset.clamp(0, double.infinity) ?? 0;
    final restoredMode = restored?.mode ?? _mode;
    _mode = restoredMode == HomeFeedMode.friends && !_runtime.config.enableFriendsMode
        ? HomeFeedMode.personalized
        : restoredMode;
    _startSession(uid, _mode, sessionId: restored?.sessionId);
    _seen.addAll(restored?.seenItemIds ?? const <String>[]);
    try {
      _mutedCreators.addAll(await _interactions.loadMutedCreatorIds());
    } catch (_) {}
    await _loadCache();
    await refresh();
  }

  Future<void> setMode(HomeFeedMode mode) async {
    if (_mode == mode && _session != null) return;
    if (mode == HomeFeedMode.friends && !_runtime.config.enableFriendsMode) {
      mode = HomeFeedMode.personalized;
    }
    _mode = mode;
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    _startSession(uid, mode);
    _restoredScrollOffset = 0;
    _items.clear();
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading && !_refreshing) return;
    _refreshing = true;
    _loading = true;
    _error = null;
    _hasMore = true;
    _cursor = null;
    notifyListeners();

    try {
      final session = _session;
      if (session == null) return;
      final context = HomeFeedContext(
        sessionId: session.sessionId,
        userId: session.userId,
        mode: _mode,
        startedAt: session.startedAt,
        seenContentIds: const <String>{},
        negativeContentIds: _negativeContent,
        mutedCreatorIds: _mutedCreators,
        blockedCreatorIds: _blockedCreators,
      );
      final page = await _service.fetchPage(
        context: context,
        interest: _runtime.interest,
      );
      _items
        ..clear()
        ..addAll(page.items);
      _seen.addAll(page.items.map((item) => item.contentId));
      _impressionsSent.clear();
      _appendSession(page.items);
      _hasMore = page.hasMore && page.items.isNotEmpty;
      _cursor = page.cursor;
      await _cache.save(_items);
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    final session = _session;
    if (session == null) return;

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final context = HomeFeedContext(
        sessionId: session.sessionId,
        userId: session.userId,
        mode: _mode,
        startedAt: session.startedAt,
        cursor: _cursor,
        seenContentIds: _seen,
        negativeContentIds: _negativeContent,
        mutedCreatorIds: _mutedCreators,
        blockedCreatorIds: _blockedCreators,
      );
      final page = await _service.fetchPage(
        context: context,
        interest: _runtime.interest,
        cursor: _cursor,
      );
      _appendPage(page);
      await _cache.save(_items);
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void markImpression(HomeFeedItem item, int position) {
    if (!_impressionsSent.add(item.contentId)) return;
    _seen.add(item.contentId);
    _session?.markSeen(item.contentId);
    _eventQueue.enqueue(HomeFeedEvent(
      sessionId: _session?.sessionId ?? '',
      contentId: item.contentId,
      eventType: HomeFeedEventType.impression,
      createdAt: DateTime.now().toUtc(),
      position: position,
      metadata: <String, Object?>{
        'creatorId': item.creatorId,
        'source': item.source.name,
        'trackingToken': item.trackingToken,
      },
    ));
  }

  void markWatch(
    HomeFeedItem item, {
    required HomeFeedEventType eventType,
    required int position,
    int watchTimeMs = 0,
  }) {
    _session?.markWatched(item.contentId);
    _eventQueue.enqueue(HomeFeedEvent(
      sessionId: _session?.sessionId ?? '',
      contentId: item.contentId,
      eventType: eventType,
      createdAt: DateTime.now().toUtc(),
      position: position,
      watchTimeMs: watchTimeMs,
    ));
    if (eventType == HomeFeedEventType.completion || eventType == HomeFeedEventType.rewatch) {
      unawaited(_runtime.learn(item, eventType));
    }
  }

  Future<void> toggleLike(HomeFeedItem item) async {
    final next = !_liked.contains(item.contentId);
    if (next) {
      _liked.add(item.contentId);
    } else {
      _liked.remove(item.contentId);
    }
    notifyListeners();
    markInteraction(item, HomeFeedEventType.like);
    try {
      await _interactions.setLike(contentId: item.contentId, liked: next);
    } catch (_) {
      if (next) {
        _liked.remove(item.contentId);
      } else {
        _liked.add(item.contentId);
      }
      notifyListeners();
    }
  }

  Future<void> toggleSave(HomeFeedItem item) async {
    final next = !_saved.contains(item.contentId);
    if (next) {
      _saved.add(item.contentId);
    } else {
      _saved.remove(item.contentId);
    }
    notifyListeners();
    markInteraction(item, HomeFeedEventType.save);
    try {
      await _interactions.setSave(
        contentId: item.contentId,
        saved: next,
        liked: _liked.contains(item.contentId),
      );
    } catch (_) {
      if (next) {
        _saved.remove(item.contentId);
      } else {
        _saved.add(item.contentId);
      }
      notifyListeners();
    }
  }

  void markInteraction(HomeFeedItem item, HomeFeedEventType type) {
    _session?.markInteraction(item.contentId);
    _eventQueue.enqueue(HomeFeedEvent(
      sessionId: _session?.sessionId ?? '',
      contentId: item.contentId,
      eventType: type,
      createdAt: DateTime.now().toUtc(),
    ));
    if (type == HomeFeedEventType.like ||
        type == HomeFeedEventType.save ||
        type == HomeFeedEventType.share ||
        type == HomeFeedEventType.follow ||
        type == HomeFeedEventType.notInterested ||
        type == HomeFeedEventType.hide ||
        type == HomeFeedEventType.mute ||
        type == HomeFeedEventType.block ||
        type == HomeFeedEventType.report) {
      unawaited(_runtime.learn(item, type));
    }
  }

  void notInterested(HomeFeedItem item) {
    _negativeContent.add(item.contentId);
    _session?.markSkipped(item.contentId);
    _removeItem(item.contentId);
    markInteraction(item, HomeFeedEventType.notInterested);
    unawaited(_interactions.recordNegativeFeedback(
      contentId: item.contentId,
      type: 'not_interested',
      creatorId: item.creatorId,
    ));
  }

  void hide(HomeFeedItem item) {
    _negativeContent.add(item.contentId);
    _removeItem(item.contentId);
    markInteraction(item, HomeFeedEventType.hide);
    unawaited(_interactions.recordNegativeFeedback(
      contentId: item.contentId,
      type: 'hide',
      creatorId: item.creatorId,
    ));
  }

  void muteCreator(HomeFeedItem item) {
    _mutedCreators.add(item.creatorId);
    _items.removeWhere((candidate) => candidate.creatorId == item.creatorId);
    notifyListeners();
    markInteraction(item, HomeFeedEventType.mute);
    unawaited(_interactions.recordNegativeFeedback(
      contentId: item.contentId,
      type: 'mute_creator',
      creatorId: item.creatorId,
    ));
  }

  Future<void> unmuteCreator(String creatorId) async {
    if (creatorId.isEmpty) return;
    _mutedCreators.remove(creatorId);
    await _interactions.removeNegativeFeedbackForCreator(
      creatorId: creatorId,
      type: 'mute_creator',
    );
    notifyListeners();
  }

  void blockCreator(HomeFeedItem item) {
    _blockedCreators.add(item.creatorId);
    _items.removeWhere((candidate) => candidate.creatorId == item.creatorId);
    notifyListeners();
    markInteraction(item, HomeFeedEventType.block);
    unawaited(_interactions.recordNegativeFeedback(
      contentId: item.contentId,
      type: 'block_creator',
      creatorId: item.creatorId,
    ));
  }

  void report(HomeFeedItem item) {
    markInteraction(item, HomeFeedEventType.report);
    unawaited(_interactions.recordNegativeFeedback(
      contentId: item.contentId,
      type: 'report',
      creatorId: item.creatorId,
    ));
  }

  String whyThisPost(HomeFeedItem item) {
    if (item.recommendationReason != null && item.recommendationReason!.trim().isNotEmpty) {
      return item.recommendationReason!;
    }
    switch (item.source) {
      case HomeFeedSource.following:
        return 'This post is from a creator you follow.';
      case HomeFeedSource.favorite:
        return 'This post is related to content you saved.';
      case HomeFeedSource.interest:
        return 'This post matches interests you have interacted with.';
      case HomeFeedSource.trending:
        return 'This post is receiving strong recent engagement.';
      case HomeFeedSource.fresh:
        return 'This post was published recently.';
      case HomeFeedSource.friend:
        return 'This post is from your community.';
      case HomeFeedSource.suggested:
        return 'This post was suggested based on your recent activity.';
    }
  }

  Future<void> setManagedTopics(List<String> topics) async {
    await _runtime.setManagedTopics(topics);
    notifyListeners();
  }

  Future<void> resetRecommendations() async {
    _negativeContent.clear();
    _mutedCreators.clear();
    _blockedCreators.clear();
    _liked.clear();
    _saved.clear();
    _seen.clear();
    _impressionsSent.clear();
    _items.clear();
    _restoredScrollOffset = 0;
    await _runtime.clearSavedSession();
    await _interactions.resetRecommendationControls();
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isNotEmpty) _startSession(uid, HomeFeedMode.personalized);
    notifyListeners();
    await refresh();
  }

  Future<void> clearMutedCreator(String creatorId) => unmuteCreator(creatorId);

  Future<void> saveSession(double scrollOffset) async {
    final session = _session;
    if (session == null) return;
    await _runtime.saveSession(session, scrollOffset);
  }

  Future<void> clearSavedSession() => _runtime.clearSession();

  Future<void> flushEvents() => _eventQueue.flush();

  @override
  void dispose() {
    unawaited(_eventQueue.dispose());
    super.dispose();
  }

  void _startSession(String uid, HomeFeedMode mode, {String? sessionId}) {
    final now = DateTime.now().toUtc();
    _session = HomeSessionState(
      sessionId: sessionId ?? '${uid}_${now.microsecondsSinceEpoch}',
      userId: uid,
      mode: mode,
      startedAt: now,
    );
  }

  Future<void> _loadCache() async {
    try {
      final cached = await _cache.read();
      if (cached.isEmpty) return;
      _items
        ..clear()
        ..addAll(cached);
      notifyListeners();
    } catch (_) {}
  }

  void _appendPage(HomeFeedPage page) {
    final existing = _items.map((item) => item.contentId).toSet();
    for (final item in page.items) {
      if (existing.add(item.contentId)) _items.add(item);
    }
    _hasMore = page.hasMore && page.items.isNotEmpty;
    _cursor = page.cursor;
    _appendSession(page.items);
  }

  void _appendSession(Iterable<HomeFeedItem> pageItems) {
    _session?.markServed(pageItems);
  }

  void _removeItem(String contentId) {
    _items.removeWhere((item) => item.contentId == contentId);
    notifyListeners();
  }
}
