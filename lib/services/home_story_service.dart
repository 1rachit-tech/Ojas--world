import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/home_story_models.dart';

class HomeStoryService {
  HomeStoryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<List<HomeStoryUser>> fetchActiveStories() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return const <HomeStoryUser>[];

    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('stories')
          .where('expiresAt', isGreaterThan: now)
          .orderBy('expiresAt')
          .limit(200)
          .get();

      final byCreator = <String, List<HomeStoryItem>>{};
      for (final doc in snapshot.docs) {
        final story = HomeStoryItem.fromFirestore(doc);
        if (story.creatorId.isEmpty || story.mediaUrl.isEmpty || story.isExpired) continue;
        byCreator.putIfAbsent(story.creatorId, () => <HomeStoryItem>[]).add(story);
      }
      if (byCreator.isEmpty) return const <HomeStoryUser>[];

      final users = <HomeStoryUser>[];
      for (final entry in byCreator.entries) {
        final profile = await _firestore.collection('publicProfiles').doc(entry.key).get();
        final data = profile.data() ?? const <String, dynamic>{};
        final name = (data['displayName'] as String?)?.trim();
        final avatar = data['avatarUrl'] as String?;
        users.add(HomeStoryUser(
          creatorId: entry.key,
          displayName: name == null || name.isEmpty ? entry.key : name,
          avatarUrl: avatar,
          stories: entry.value,
          hasUnread: entry.value.any((story) => !story.viewed),
        ));
      }
      return users;
    } catch (_) {
      // Story backend may not be enabled on an existing deployment yet.
      // Returning an empty list keeps Home functional without fake stories.
      return const <HomeStoryUser>[];
    }
  }

  Future<void> markViewed(String storyId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || storyId.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('storyViews')
          .doc(storyId)
          .set(<String, dynamic>{
        'storyId': storyId,
        'viewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Viewing a story must not interrupt the story viewer.
    }
  }
}
