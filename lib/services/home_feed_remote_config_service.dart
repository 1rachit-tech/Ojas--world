import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/home_feed_runtime_models.dart';

class HomeFeedRemoteConfigService {
  HomeFeedRemoteConfigService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const HomeFeedRemoteConfig defaults = HomeFeedRemoteConfig();

  Future<HomeFeedRemoteConfig> load() async {
    try {
      final snapshot = await _firestore.collection('appConfig').doc('homeFeed').get();
      final data = snapshot.data();
      if (data == null) return defaults;
      return _parse(data);
    } catch (_) {
      return defaults;
    }
  }

  HomeFeedRemoteConfig _parse(Map<String, dynamic> data) {
    HomeFeedExperimentVariant parseVariant(Object? value) {
      if (value == 'candidate') return HomeFeedExperimentVariant.candidate;
      return HomeFeedExperimentVariant.control;
    }

    double clampRatio(Object? value, double fallback) {
      final parsed = value is num ? value.toDouble() : fallback;
      return parsed.clamp(0.0, 1.0);
    }

    int positiveInt(Object? value, int fallback, {int max = 100}) {
      final parsed = value is num ? value.toInt() : fallback;
      return parsed.clamp(1, max);
    }

    return HomeFeedRemoteConfig(
      pageSize: positiveInt(data['pageSize'], defaults.pageSize),
      candidatePageSize: positiveInt(data['candidatePageSize'], defaults.candidatePageSize),
      maxPreloadedVideos: positiveInt(data['maxPreloadedVideos'], defaults.maxPreloadedVideos, max: 4),
      preloadNextCount: positiveInt(data['preloadNextCount'], defaults.preloadNextCount, max: 2),
      recommendationRatio: clampRatio(data['recommendationRatio'], defaults.recommendationRatio),
      enableStories: data['enableStories'] as bool? ?? defaults.enableStories,
      enableFriendsMode: data['enableFriendsMode'] as bool? ?? defaults.enableFriendsMode,
      enableTelemetryUpload:
          data['enableTelemetryUpload'] as bool? ?? defaults.enableTelemetryUpload,
      enableRemoteRanking:
          data['enableRemoteRanking'] as bool? ?? defaults.enableRemoteRanking,
      experimentVariant: parseVariant(data['experimentVariant']),
    );
  }
}
