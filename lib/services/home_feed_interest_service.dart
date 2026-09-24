import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/home_feed_models.dart';
import '../models/home_feed_runtime_models.dart';
import 'home_feed_event_queue.dart';

class HomeFeedInterestService {
  HomeFeedInterestService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<HomeFeedInterestProfile> load() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return const HomeFeedInterestProfile();
    try {
      final doc = await _firestore.collection('users').doc(uid).collection('feedProfile').doc('interest').get();
      return _fromMap(doc.data() ?? const <String, dynamic>{});
    } catch (_) {
      return const HomeFeedInterestProfile();
    }
  }

  Future<void> record({required HomeFeedItem item, required HomeFeedEventType type}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final delta = _deltaFor(type);
    if (delta == 0) return;
    final ref = _firestore.collection('users').doc(uid).collection('feedProfile').doc('interest');
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final data = snapshot.data() ?? const <String, dynamic>{};
        final creators = _doubleMap(data['creatorAffinity']);
        final topics = _doubleMap(data['topicAffinity']);
        final hashtags = _doubleMap(data['hashtagAffinity']);
        final sounds = _doubleMap(data['soundAffinity']);
        final types = _doubleMap(data['contentTypeAffinity']);
        final negative = _doubleMap(data['negativeAffinity']);
        _adjust(creators, item.creatorId, delta);
        for (final tag in item.hashtags) _adjust(hashtags, tag, delta);
        if (item.soundId != null && item.soundId!.isNotEmpty) _adjust(sounds, item.soundId!, delta);
        _adjust(types, item.contentType.name, delta);
        if (delta < 0) {
          for (final tag in item.hashtags) _adjust(negative, tag, -delta);
        }
        if (item.hashtags.isNotEmpty) _adjust(topics, item.hashtags.first, delta);
        transaction.set(ref, <String, dynamic>{
          'creatorAffinity': creators,
          'topicAffinity': topics,
          'hashtagAffinity': hashtags,
          'soundAffinity': sounds,
          'contentTypeAffinity': types,
          'negativeAffinity': negative,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // Interest learning is non-critical and must not block Home.
    }
  }

  Future<void> setManagedTopics(List<String> topics) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final cleaned = topics
        .map((topic) => topic.trim())
        .where((topic) => topic.isNotEmpty)
        .take(30)
        .toSet();
    final affinity = <String, double>{
      for (final topic in cleaned) topic: 2.0,
    };
    final ref = _firestore.collection('users').doc(uid).collection('feedProfile').doc('interest');
    await ref.set(<String, dynamic>{
      'topicAffinity': affinity,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  double _deltaFor(HomeFeedEventType type) {
    switch (type) {
      case HomeFeedEventType.completion:
      case HomeFeedEventType.rewatch:
        return 0.25;
      case HomeFeedEventType.like:
      case HomeFeedEventType.save:
      case HomeFeedEventType.share:
      case HomeFeedEventType.follow:
        return 0.5;
      case HomeFeedEventType.notInterested:
      case HomeFeedEventType.hide:
      case HomeFeedEventType.mute:
      case HomeFeedEventType.block:
      case HomeFeedEventType.report:
        return -0.75;
      case HomeFeedEventType.skip:
        return -0.15;
      default:
        return 0;
    }
  }

  HomeFeedInterestProfile _fromMap(Map<String, dynamic> data) {
    return HomeFeedInterestProfile(
      creatorAffinity: _doubleMap(data['creatorAffinity']),
      topicAffinity: _doubleMap(data['topicAffinity']),
      hashtagAffinity: _doubleMap(data['hashtagAffinity']),
      soundAffinity: _doubleMap(data['soundAffinity']),
      contentTypeAffinity: _doubleMap(data['contentTypeAffinity']),
      negativeAffinity: _doubleMap(data['negativeAffinity']),
    );
  }

  Map<String, double> _doubleMap(Object? value) {
    if (value is! Map) return <String, double>{};
    return value.map((key, value) => MapEntry(key.toString(), value is num ? value.toDouble() : 0.0));
  }

  void _adjust(Map<String, double> map, String key, double delta) {
    if (key.isEmpty) return;
    map[key] = ((map[key] ?? 0) + delta).clamp(-5.0, 5.0);
  }
}
