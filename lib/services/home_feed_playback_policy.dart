import '../models/home_feed_models.dart';
import '../models/home_feed_runtime_models.dart';

class HomeFeedPlaybackPolicy {
  const HomeFeedPlaybackPolicy({
    this.activationFraction = 0.65,
    this.preloadNext = 1,
    this.keepAdjacent = 2,
  });

  final double activationFraction;
  final int preloadNext;
  final int keepAdjacent;

  bool shouldAutoplay({required double visibleFraction, required bool isVideo}) {
    return isVideo && visibleFraction >= activationFraction;
  }

  Set<String> retainedContentIds(List<HomeFeedItem> items, int dominantIndex) {
    if (items.isEmpty || dominantIndex < 0 || dominantIndex >= items.length) {
      return const <String>{};
    }
    final ids = <String>{items[dominantIndex].contentId};
    for (var offset = 1; offset <= keepAdjacent; offset++) {
      final before = dominantIndex - offset;
      final after = dominantIndex + offset;
      if (before >= 0) ids.add(items[before].contentId);
      if (after < items.length) ids.add(items[after].contentId);
    }
    return ids;
  }

  List<String> preloadCandidates(List<HomeFeedItem> items, int dominantIndex) {
    final result = <String>[];
    for (var i = dominantIndex + 1;
        i < items.length && result.length < preloadNext;
        i++) {
      final item = items[i];
      if (item.isVideo && (item.mediaUrl?.isNotEmpty == true || item.mediaSources.isNotEmpty)) {
        result.add(item.contentId);
      }
    }
    return result;
  }

  HomePlaybackState fallbackState({required bool loading, required bool failed}) {
    if (failed) return HomePlaybackState.failed;
    if (loading) return HomePlaybackState.loading;
    return HomePlaybackState.idle;
  }
}
