import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
}

/// Local-first event queue. Firestore upload is intentionally disabled by
/// default because feed telemetry can become a high-volume, billable workload.
/// Enable it only after the backend rules, retention and budget are approved.
class HomeFeedEventQueue {
  HomeFeedEventQueue({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.flushThreshold = 12,
    this.enabled = false,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final int flushThreshold;
  final bool enabled;
  final List<HomeFeedEvent> _pending = <HomeFeedEvent>[];
  Timer? _timer;
  bool _flushing = false;

  int get pendingCount => _pending.length;

  void enqueue(HomeFeedEvent event) {
    _pending.add(event);
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
    } catch (_) {
      // Events remain queued so transient/network failures do not lose signals.
    } finally {
      _flushing = false;
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    if (enabled) await flush();
    _pending.clear();
  }
}
