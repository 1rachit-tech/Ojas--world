enum HomeFeedExperimentVariant { control, candidate }

enum HomeFeedNavigationTarget { post, creator, hashtag, sound, location, mention, comments }

class HomeFeedRemoteConfig {
  const HomeFeedRemoteConfig({
    this.pageSize = 10,
    this.candidatePageSize = 20,
    this.maxPreloadedVideos = 1,
    this.preloadNextCount = 1,
    this.recommendationRatio = 0.7,
    this.enableStories = true,
    this.enableFriendsMode = false,
    this.enableTelemetryUpload = false,
    this.enableRemoteRanking = false,
    this.experimentVariant = HomeFeedExperimentVariant.control,
  });

  final int pageSize;
  final int candidatePageSize;
  final int maxPreloadedVideos;
  final int preloadNextCount;
  final double recommendationRatio;
  final bool enableStories;
  final bool enableFriendsMode;
  final bool enableTelemetryUpload;
  final bool enableRemoteRanking;
  final HomeFeedExperimentVariant experimentVariant;

  HomeFeedRemoteConfig copyWith({
    int? pageSize,
    int? candidatePageSize,
    int? maxPreloadedVideos,
    int? preloadNextCount,
    double? recommendationRatio,
    bool? enableStories,
    bool? enableFriendsMode,
    bool? enableTelemetryUpload,
    bool? enableRemoteRanking,
    HomeFeedExperimentVariant? experimentVariant,
  }) {
    return HomeFeedRemoteConfig(
      pageSize: pageSize ?? this.pageSize,
      candidatePageSize: candidatePageSize ?? this.candidatePageSize,
      maxPreloadedVideos: maxPreloadedVideos ?? this.maxPreloadedVideos,
      preloadNextCount: preloadNextCount ?? this.preloadNextCount,
      recommendationRatio: recommendationRatio ?? this.recommendationRatio,
      enableStories: enableStories ?? this.enableStories,
      enableFriendsMode: enableFriendsMode ?? this.enableFriendsMode,
      enableTelemetryUpload: enableTelemetryUpload ?? this.enableTelemetryUpload,
      enableRemoteRanking: enableRemoteRanking ?? this.enableRemoteRanking,
      experimentVariant: experimentVariant ?? this.experimentVariant,
    );
  }
}

class HomeFeedInterestProfile {
  const HomeFeedInterestProfile({
    this.creatorAffinity = const <String, double>{},
    this.topicAffinity = const <String, double>{},
    this.hashtagAffinity = const <String, double>{},
    this.soundAffinity = const <String, double>{},
    this.contentTypeAffinity = const <String, double>{},
    this.negativeAffinity = const <String, double>{},
  });

  final Map<String, double> creatorAffinity;
  final Map<String, double> topicAffinity;
  final Map<String, double> hashtagAffinity;
  final Map<String, double> soundAffinity;
  final Map<String, double> contentTypeAffinity;
  final Map<String, double> negativeAffinity;
}

class HomeFeedNavigationContext {
  const HomeFeedNavigationContext({
    required this.target,
    required this.contentId,
    required this.source,
    required this.sessionId,
    required this.position,
    this.trackingToken,
  });

  final HomeFeedNavigationTarget target;
  final String contentId;
  final String source;
  final String sessionId;
  final int position;
  final String? trackingToken;

  Map<String, Object?> toMap() => <String, Object?>{
        'target': target.name,
        'contentId': contentId,
        'source': source,
        'sessionId': sessionId,
        'position': position,
        'trackingToken': trackingToken,
      };
}

class HomeFeedQualityMetrics {
  const HomeFeedQualityMetrics({
    this.impressions = 0,
    this.opens = 0,
    this.playStarts = 0,
    this.watchTimeMs = 0,
    this.completions = 0,
    this.likes = 0,
    this.saves = 0,
    this.shares = 0,
    this.follows = 0,
    this.skips = 0,
    this.notInterested = 0,
    this.reports = 0,
    this.bufferEvents = 0,
  });

  final int impressions;
  final int opens;
  final int playStarts;
  final int watchTimeMs;
  final int completions;
  final int likes;
  final int saves;
  final int shares;
  final int follows;
  final int skips;
  final int notInterested;
  final int reports;
  final int bufferEvents;

  double get openRate => impressions == 0 ? 0 : opens / impressions;
  double get completionRate => playStarts == 0 ? 0 : completions / playStarts;
  double get saveRate => impressions == 0 ? 0 : saves / impressions;
  double get shareRate => impressions == 0 ? 0 : shares / impressions;
  double get negativeFeedbackRate =>
      impressions == 0 ? 0 : (notInterested + reports) / impressions;
  double get bufferRate => playStarts == 0 ? 0 : bufferEvents / playStarts;
}
