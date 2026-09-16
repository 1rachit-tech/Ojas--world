class HomeFeedConfig {
  const HomeFeedConfig({
    this.pageSize = 10,
    this.candidatePageSize = 20,
    this.maxPreloadItems = 2,
    this.recommendationRatio = 0.60,
    this.autoplayVisibilityThreshold = 0.65,
    this.maxActiveVideoControllers = 1,
  });

  final int pageSize;
  final int candidatePageSize;
  final int maxPreloadItems;
  final double recommendationRatio;
  final double autoplayVisibilityThreshold;
  final int maxActiveVideoControllers;

  HomeFeedConfig copyWith({
    int? pageSize,
    int? candidatePageSize,
    int? maxPreloadItems,
    double? recommendationRatio,
    double? autoplayVisibilityThreshold,
    int? maxActiveVideoControllers,
  }) {
    return HomeFeedConfig(
      pageSize: pageSize ?? this.pageSize,
      candidatePageSize: candidatePageSize ?? this.candidatePageSize,
      maxPreloadItems: maxPreloadItems ?? this.maxPreloadItems,
      recommendationRatio: recommendationRatio ?? this.recommendationRatio,
      autoplayVisibilityThreshold:
          autoplayVisibilityThreshold ?? this.autoplayVisibilityThreshold,
      maxActiveVideoControllers:
          maxActiveVideoControllers ?? this.maxActiveVideoControllers,
    );
  }
}
