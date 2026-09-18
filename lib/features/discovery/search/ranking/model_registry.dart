enum SearchModelStage {
  production,
  shadow,
  canary,
}

class SearchModelVersion {
  const SearchModelVersion({
    required this.id,
    required this.stage,
    this.rolloutPercent = 100,
  });

  final String id;
  final SearchModelStage stage;
  final int rolloutPercent;
}

class SearchModelRegistry {
  const SearchModelRegistry({
    this.production = const SearchModelVersion(
      id: 'rule-linear-v2',
      stage: SearchModelStage.production,
      rolloutPercent: 100,
    ),
    this.shadow,
    this.canary,
  });

  final SearchModelVersion production;
  final SearchModelVersion? shadow;
  final SearchModelVersion? canary;

  SearchModelVersion forBucket(int bucket) {
    final normalized = bucket.clamp(0, 99);

    final candidate = canary;
    if (candidate != null &&
        normalized < candidate.rolloutPercent.clamp(0, 100)) {
      return candidate;
    }

    return production;
  }

  bool shouldLogShadow(int bucket) {
    final model = shadow;
    if (model == null) return false;
    return bucket.clamp(0, 99) < model.rolloutPercent.clamp(0, 100);
  }
}
