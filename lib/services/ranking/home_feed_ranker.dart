import '../../models/home_feed_models.dart';
import '../../models/home_feed_runtime_models.dart';

abstract interface class HomeFeedRanker {
  List<HomeFeedItem> rank({
    required List<HomeFeedItem> candidates,
    required HomeFeedInterestProfile interest,
    required HomeFeedMode mode,
  });
}

class DefaultHomeFeedRanker implements HomeFeedRanker {
  const DefaultHomeFeedRanker();

  @override
  List<HomeFeedItem> rank({
    required List<HomeFeedItem> candidates,
    required HomeFeedInterestProfile interest,
    required HomeFeedMode mode,
  }) {
    final scored = candidates.map((item) {
      final personalization = _personalizationScore(item, interest);
      final freshness = item.rankingContext['freshness'] ?? 0.0;
      final engagement = item.rankingContext['engagement'] ?? 0.0;
      final watchQuality = item.rankingContext['watchQuality'] ?? 0.0;

      final relationshipBoost = mode == HomeFeedMode.following ? 0.55 : 0.0;
      final favoriteBoost = mode == HomeFeedMode.favorites ? 0.65 : 0.0;
      final latestBoost = mode == HomeFeedMode.latest ? 0.35 : 0.0;

      final score = (freshness * 0.18) +
          (engagement * 0.16) +
          (watchQuality * 0.14) +
          (personalization * 0.52) +
          relationshipBoost +
          favoriteBoost +
          latestBoost;

      return _ScoredItem(item, score);
    }).toList(growable: false);

    final sorted = [...scored]
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return b.item.createdAt.compareTo(a.item.createdAt);
      });

    return _diversify(sorted);
  }

  double _personalizationScore(
    HomeFeedItem item,
    HomeFeedInterestProfile interest,
  ) {
    final creator = _positiveAffinity(interest.creatorAffinity[item.creatorId]);
    final topic = item.hashtags.fold<double>(0.0, (best, tag) {
      final hashtagScore = _positiveAffinity(interest.hashtagAffinity[tag]);
      final topicScore = _positiveAffinity(interest.topicAffinity[tag]);
      return hashtagScore > best
          ? hashtagScore
          : (topicScore > best ? topicScore : best);
    });
    final sound = item.soundId == null
        ? 0.0
        : _positiveAffinity(interest.soundAffinity[item.soundId]);
    final type = _positiveAffinity(interest.contentTypeAffinity[item.contentType.name]);
    final negative = item.hashtags.fold<double>(0.0, (sum, tag) {
      return sum + _negativePenalty(interest.negativeAffinity[tag]);
    });
    final negativePenalty = negative.clamp(0.0, 1.0);

    return ((creator * 0.34) +
            (topic * 0.28) +
            (sound * 0.14) +
            (type * 0.10) -
            (negativePenalty * 0.20))
        .clamp(0.0, 1.0);
  }

  double _positiveAffinity(double? value) {
    final raw = value ?? 0.0;
    return (raw.clamp(0.0, 5.0) / 5.0).clamp(0.0, 1.0);
  }

  // Current interest storage keeps negativeAffinity as a positive magnitude.
  // Accept the legacy negative-sign representation too, so old profiles remain
  // meaningful after the ranking semantic correction.
  double _negativePenalty(double? value) {
    final raw = value ?? 0.0;
    return (raw.abs().clamp(0.0, 5.0) / 5.0).clamp(0.0, 1.0);
  }

  List<HomeFeedItem> _diversify(List<_ScoredItem> sorted) {
    final result = <HomeFeedItem>[];
    final creatorCounts = <String, int>{};
    final hashtagCounts = <String, int>{};
    final deferred = <_ScoredItem>[];

    for (final scored in sorted) {
      final item = scored.item;
      final creatorCount = creatorCounts[item.creatorId] ?? 0;
      final topic = item.hashtags.isEmpty ? '' : item.hashtags.first;
      final topicCount = topic.isEmpty ? 0 : (hashtagCounts[topic] ?? 0);

      if (creatorCount >= 2 || (topic.isNotEmpty && topicCount >= 3)) {
        deferred.add(scored);
        continue;
      }

      result.add(item);
      creatorCounts[item.creatorId] = creatorCount + 1;
      if (topic.isNotEmpty) hashtagCounts[topic] = topicCount + 1;
    }

    for (final scored in deferred) {
      result.add(scored.item);
    }
    return result;
  }
}

class _ScoredItem {
  const _ScoredItem(this.item, this.score);

  final HomeFeedItem item;
  final double score;
}
