import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/home_feed_models.dart';
import '../services/home_feed_event_queue.dart';
import '../services/home_feed_service.dart';

class HomeFeedController extends ChangeNotifier {
  HomeFeedController({
    HomeFeedService? service,
    HomeFeedEventQueue? eventQueue,
    FirebaseAuth? auth,
  })  : _service = service ?? HomeFeedService(),
        _eventQueue = eventQueue ?? HomeFeedEventQueue(),
        _auth = auth ?? FirebaseAuth.instance;

  final HomeFeedService _service;
  final HomeFeedEventQueue _eventQueue;
  final FirebaseAuth _auth;

  final List<HomeFeedItem> _items = <HomeFeedItem>[];
  final Set<String> _seen = <String>{};
  final Set<String> _negativeContent = <String>{};
  final Set<String> _mutedCreators = <String>{};
  final Set<String> _blockedCreators = <String>{};

  HomeSessionState? _session;
  HomeFeedMode _mode = HomeFeedMode.personalized;
  bool _loading = false;
  bool _refreshing = false;
  bool _hasMore = true;
  Object? _error;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  List<HomeFeedItem> get items => List.unmodifiable(_items);
  HomeFeedMode get mode => _mode;
  bool get isLoading => _loading;
  bool get isRefreshing => _refreshing;
  bool get hasMore => _hasMore;
  Object? get error => _error;
  HomeSessionState? get session => _session;

  Future<void> initialize() async {
    if (_session != null) return;
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      _error = StateError('A signed-in user is required for Home Feed.');
      notifyListeners();
      return;
    }
    _startSession(uid, _mode);
    await refresh();
  }

  Future<void> setMode(HomeFeedMode mode) async {
    if (_mode == mode && _session != null) return;
    _mode = mode;
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    _startSession(uid, mode);
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading && !_refreshing) return;
    _refreshing = true;
    _loading = true;
    _error = null;
    _items.clear();
    _seen.clear();
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
        seenContentIds: _seen,
        negativeContentIds: _negativeContent,
        mutedCreatorIds: _mutedCreators,
        blockedCreatorIds: _blockedCreators,
      );
      final page = await _service.fetchPage(context: context);
      _appendPage(page);
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
        cursor: _cursor,
      );
      _appendPage(page);
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void markImpression(HomeFeedItem item, int position) {
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
  }

  void markInteraction(HomeFeedItem item, HomeFeedEventType type) {
    _session?.markInteraction(item.contentId);
    _eventQueue.enqueue(HomeFeedEvent(
      sessionId: _session?.sessionId ?? '',
      contentId: item.contentId,
      eventType: type,
      createdAt: DateTime.now().toUtc(),
    ));
  }

  void notInterested(HomeFeedItem item) {
    _negativeContent.add(item.contentId);
    _session?.markSkipped(item.contentId);
    _removeItem(item.contentId);
    markInteraction(item, HomeFeedEventType.notInterested);
  }

  void hide(HomeFeedItem item) {
    _negativeContent.add(item.contentId);
    _removeItem(item.contentId);
    markInteraction(item, HomeFeedEventType.hide);
  }

  void muteCreator(HomeFeedItem item) {
    _mutedCreators.add(item.creatorId);
    _items.removeWhere((candidate) => candidate.creatorId == item.creatorId);
    markInteraction(item, HomeFeedEventType.mute);
  }

  void blockCreator(HomeFeedItem item) {
    _blockedCreators.add(item.creatorId);
    _items.removeWhere((candidate) => candidate.creatorId == item.creatorId);
    markInteraction(item, HomeFeedEventType.block);
  }

  void report(HomeFeedItem item) {
    markInteraction(item, HomeFeedEventType.report);
  }

  Future<void> flushEvents() => _eventQueue.flush();

  @override
  void dispose() {
    unawaited(_eventQueue.dispose());
    super.dispose();
  }

  void _startSession(String uid, HomeFeedMode mode) {
    final now = DateTime.now().toUtc();
    final sessionId = '${uid}_${now.microsecondsSinceEpoch}';
    _session = HomeSessionState(
      sessionId: sessionId,
      userId: uid,
      mode: mode,
      startedAt: now,
    );
  }

  void _appendPage(HomeFeedPage page) {
    final existing = _items.map((item) => item.contentId).toSet();
    for (final item in page.items) {
      if (existing.add(item.contentId)) {
        _items.add(item);
      }
    }
    _hasMore = page.hasMore && page.items.isNotEmpty;
    _cursor = page.cursor;
    _session?.markServed(page.items);
  }

  void _removeItem(String contentId) {
    _items.removeWhere((item) => item.contentId == contentId);
    notifyListeners();
  }
}
