import '../../../services/home_feed_interest_service.dart';
import 'domain/search_models.dart';

abstract interface class SearchFeatureStore {
  Future<SearchUserContext> loadUserContext();
}

class OjasSearchFeatureStore implements SearchFeatureStore {
  OjasSearchFeatureStore({
    HomeFeedInterestService? interestService,
  }) : _interestService = interestService ?? HomeFeedInterestService();

  final HomeFeedInterestService _interestService;

  @override
  Future<SearchUserContext> loadUserContext() async {
    try {
      final profile = await _interestService.load();
      return SearchUserContext(
        creatorAffinity: profile.creatorAffinity,
        topicAffinity: profile.topicAffinity,
        hashtagAffinity: profile.hashtagAffinity,
        soundAffinity: profile.soundAffinity,
        contentTypeAffinity: profile.contentTypeAffinity,
        negativeAffinity: profile.negativeAffinity,
      );
    } catch (_) {
      return const SearchUserContext();
    }
  }
}
