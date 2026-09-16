import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HomeFeedEventType {
  impression,
  open,
  playStart,
  watchProgress,
  pause,
  resume,
  completion,
  rewatch,
  skip,
  like,
  comment,
  share,
  save,
  follow,
  profileVisit,
  hashtagOpen,
  soundOpen,
  topicOpen,
  notInterested,
  hide,
  mute,
  unfollow,
  block,
  report,
  buffer,
  playbackError,
}

class HomeFeedEvent {
  const HomeFeedEvent({
    required this.sessionId,
    required this.contentId,
    required this.eventType,
    required this.createdAt,
    this.position = 0,
    this.watchTimeMs = 0,
    this.metadata = const <String, Object?>{},
  });

  final String sessionId;
  final String contentId;
  final HomeFeedEventType eventType;
  final DateTime createdAt;
  final int position;
  final int watchTimeMs;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() => <String, Object?>{
        'sessionId': sessionId,
        'contentId': contentId,
        'eventType': eventType.name,
        'position': position,
        'watchTimeMs': watchTimeMs,
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
      };

  Map<String, Object?> toLocalMap() => <String, Object?>{
        'sessionId': sessionId,
        'contentId': contentId,
        'eventType': eventType.name,
        'position': position,
        'watchTimeMs': watchTimeMs,
        'metadata': metadata,
        'createdAt': createdAt.toIso8601String(),
      };

  static HomeFeedEvent? fromLocalMap(Map<String, dynamic> map) {
    final typeName = map['eventType'];
    final eventType = HomeFeedEventType.values.where((type) => type.name == typeName).firstOrNull;
    final createdAt = DateTime.tryParse(map['createdAt'] as String? ?? '');
    if (eventType == null || createdAt == null) return null;
    return HomeFeedEvent(
      sessionId: map['sessionId'] as String? ?? '',
      contentId: map['contentId'] as String? ?? '',
      eventType: eventType,
      createdAt: createdAt,
      position: (map['position'] as num?)?.toInt() ?? 0,
      watchTimeMs: (map['watchTimeMs'] as num?)?.toInt() ?? 0,
      metadata: map['metadata'] is Map
          ? Map<String, Object?>.from(map['metadata'] as Map)
          : const <String, Object?>{},
    );
  }
}

/// Local-first telemetry queue. Remote Firestore upload remains disabled by
/// default because feed telemetry is a potentially high-volume workload.
/// Events are persisted locally so disabling upload does not silently discard
/// user signals. Upload can be enabled later through remote configuration.
class HomeFeedEventQueue {
  HomeFeedEventQueue({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.flushThreshold = 12,
    this.enabled = false,
    this.maxStoredEvents = 500,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const String _storageKey = 'ojas_home_feed_event_queue_v1';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final int flushThreshold;
  final bool enabled;
  final int maxStoredEvents;
  final List<HomeFeedEvent> _pending = <HomeFeedEvent>[];
  Timer? _timer;
  Future<void> _persistChain = Future<void>.value();
  bool _flushing = false;
  bool _initialized = false;

  int get pendingCount => _pending.length;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final value in decoded) {
        if (value is! Map) continue;
        final event = HomeFeedEvent.fromLocalMap(Map<String, dynamic>.from(value));
        if (event != null && event.contentId.isNotEmpty) _pending.add(event);
      }
      if (_pending.length > maxStoredEvents) {
        _pending.removeRange(0, _pending.length - maxStoredEvents);
      }
    } catch (_) {
      _pending.clear();
    }
  }

  void enqueue(HomeFeedEvent event) {
    if (!_initialized) {
      // Keep the current event even if a caller emits before controller bootstrap.
      _initialized = true;
    }
    _pending.add(event);
    if (_pending.length > maxStoredEvents) {
      _pending.removeRange(0, _pending.length - maxStoredEvents);
    }
    unawaited(_persist());

    if (!enabled) return;

    _timer ??= Timer(const Duration(seconds: 8), () {
      _timer = null;
      unawaited(flush());
    });
    if (_pending.length >= flushThreshold) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    if (!enabled || _flushing || _pending.isEmpty) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    _flushing = true;
    final batchEvents = List<HomeFeedEvent>.from(_pending.take(450));
    try {
      final batch = _firestore.batch();
      final collection = _firestore
          .collection('users')
          .doc(uid)
          .collection('feedEvents');
      for (final event in batchEvents) {
        batch.set(collection.doc(), event.toMap());
      }
      await batch.commit();
      _pending.removeRange(0, batchEvents.length);
      await _persist();
    } catch (_) {
      // Events remain persisted for a later retry.
    } finally {
      _flushing = false;
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    if (enabled) {
      await flush();
    } else {
      await _persist();
    }
  }

  Future<void> _persist() {
    _persistChain = _persistChain.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();
        final payload = _pending.map((event) => event.toLocalMap()).toList(growable: false);
        await preferences.setString(_storageKey, jsonEncode(payload));
      } catch (_) {
        // Local persistence is best-effort and never blocks the feed.
      }
    });
    return _persistChain;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
