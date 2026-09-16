import 'package:firebase_auth/firebase_auth.dart';

import '../models/home_feed_models.dart';
import '../models/home_feed_runtime_models.dart';
import 'home_feed_event_queue.dart';
import 'home_feed_interest_service.dart';
import 'home_feed_remote_config_service.dart';
import 'home_feed_session_store.dart';
import 'home_feed_navigation_service.dart';

class HomeFeedRuntimeService {
  HomeFeedRuntimeService({
    HomeFeedRemoteConfigService? remoteConfig,
    HomeFeedInterestService? interests,
    HomeFeedSessionStore? sessions,
    HomeFeedExperimentService? experiments,
    FirebaseAuth? auth,
  })  : _remoteConfig = remoteConfig ?? HomeFeedRemoteConfigService(),
        _interests = interests ?? HomeFeedInterestService(),
        _sessions = sessions ?? HomeFeedSessionStore(),
        _experiments = experiments ?? const HomeFeedExperimentService(),
        _auth = auth ?? FirebaseAuth.instance;

  final HomeFeedRemoteConfigService _remoteConfig;
  final HomeFeedInterestService _interests;
  final HomeFeedSessionStore _sessions;
  final HomeFeedExperimentService _experiments;
  final FirebaseAuth _auth;

  HomeFeedRemoteConfig config = HomeFeedRemoteConfig();
  HomeFeedInterestProfile interest = const HomeFeedInterestProfile();

  Future<void> initialize() async {
    final results = await Future.wait<Object?>([
      _remoteConfig.load(),
      _interests.load(),
    ]);
    config = results[0] as HomeFeedRemoteConfig;
    interest = results[1] as HomeFeedInterestProfile;
  }

  Future<HomeFeedSessionSnapshot?> restoreSession() => _sessions.read();

  Future<void> saveSession(HomeSessionState session, double offset) =>
      _sessions.save(session, offset);

  Future<void> clearSession() => _sessions.clear();

  Future<void> learn(HomeFeedItem item, HomeFeedEventType type) async {
    await _interests.record(item: item, type: type);
  }

  HomeFeedExperimentVariant assignExperiment() {
    return _experiments.assign(
      userId: _auth.currentUser?.uid ?? '',
    );
  }
}
