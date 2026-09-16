import '../models/home_feed_models.dart';
import '../models/home_feed_runtime_models.dart';

class HomeFeedNavigationService {
  const HomeFeedNavigationService();

  HomeFeedNavigationContext contextFor({
    required HomeFeedItem item,
    required HomeFeedSessionState session,
    required int position,
    required HomeFeedNavigationTarget target,
  }) {
    return HomeFeedNavigationContext(
      target: target,
      contentId: item.contentId,
      source: item.source.name,
      sessionId: session.sessionId,
      position: position,
      trackingToken: item.trackingToken,
    );
  }
}

class HomeFeedExperimentService {
  const HomeFeedExperimentService();

  HomeFeedExperimentVariant assign({required String userId}) {
    if (userId.isEmpty) return HomeFeedExperimentVariant.control;
    var hash = 0;
    for (final codeUnit in userId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash.isEven
        ? HomeFeedExperimentVariant.control
        : HomeFeedExperimentVariant.candidate;
  }
}
