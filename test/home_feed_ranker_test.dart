import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/models/home_feed_models.dart';
import 'package:ojas_app/models/home_feed_runtime_models.dart';
import 'package:ojas_app/services/ranking/home_feed_ranker.dart';

HomeFeedItem _item({
  required String id,
  required String creatorId,
  List<String> hashtags = const <String>[],
  String? soundId,
  double freshness = 0.5,
}) {
  return HomeFeedItem(
    contentId: id,
    creatorId: creatorId,
    contentType: HomeContentType.video,
    mediaType: 'video',
    createdAt: DateTime(2026, 1, 1),
    source: HomeFeedSource.suggested,
    eligibility: HomeEligibilityStatus.eligible,
    rankingScore: 0,
    hashtags: hashtags,
    soundId: soundId,
    rankingContext: <String, double>{
      'freshness': freshness,
      'engagement': 0.2,
      'watchQuality': 0.2,
    },
  );
}

void main() {
  const ranker = DefaultHomeFeedRanker();

  test('neutral affinity does not create artificial personalization boost', () {
    final candidates = <HomeFeedItem>[
      _item(id: 'neutral', creatorId: 'creator-neutral'),
      _item(id: 'fresh', creatorId: 'creator-fresh', freshness: 0.9),
    ];

    final ranked = ranker.rank(
      candidates: candidates,
      interest: const HomeFeedInterestProfile(),
      mode: HomeFeedMode.personalized,
    );

    expect(ranked.first.contentId, 'fresh');
  });

  test('positive creator affinity can reorder personalized candidates', () {
    final candidates = <HomeFeedItem>[
      _item(id: 'preferred', creatorId: 'creator-preferred', freshness: 0.4),
      _item(id: 'fresh', creatorId: 'creator-fresh', freshness: 0.9),
    ];

    final ranked = ranker.rank(
      candidates: candidates,
      interest: const HomeFeedInterestProfile(
        creatorAffinity: <String, double>{'creator-preferred': 5.0},
      ),
      mode: HomeFeedMode.personalized,
    );

    expect(ranked.first.contentId, 'preferred');
  });

  test('negative hashtag affinity penalizes matching content', () {
    final candidates = <HomeFeedItem>[
      _item(id: 'negative', creatorId: 'creator-a', hashtags: <String>['gaming']),
      _item(id: 'clean', creatorId: 'creator-b', hashtags: <String>['science']),
    ];

    final ranked = ranker.rank(
      candidates: candidates,
      interest: const HomeFeedInterestProfile(
        negativeAffinity: <String, double>{'gaming': -5.0},
      ),
      mode: HomeFeedMode.personalized,
    );

    expect(ranked.first.contentId, 'clean');
  });

  test('diversity keeps a creator from dominating the first results', () {
    final candidates = <HomeFeedItem>[
      _item(id: 'a1', creatorId: 'same'),
      _item(id: 'a2', creatorId: 'same'),
      _item(id: 'a3', creatorId: 'same'),
      _item(id: 'b1', creatorId: 'other'),
    ];

    final ranked = ranker.rank(
      candidates: candidates,
      interest: const HomeFeedInterestProfile(),
      mode: HomeFeedMode.personalized,
    );

    expect(ranked.take(3).where((item) => item.creatorId == 'same').length, lessThanOrEqualTo(2));
  });
}
