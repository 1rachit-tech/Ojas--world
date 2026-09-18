import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/features/discovery/search/domain/search_models.dart';
import 'package:ojas_app/features/discovery/search/ranking/search_ranker.dart';
import 'package:ojas_app/features/discovery/search/query_processor.dart';

void main() {
  const processor = SearchQueryProcessor();
  const ranker = SearchRanker();

  test('query relevance dominates personalization', () {
    final query = processor.process('classical music');
    final candidates = <SearchIndexRow>[
      SearchIndexRow(
        id: 'gaming',
        entityType: SearchEntityType.content,
        title: 'Gaming montage',
        subtitle: 'creator',
        text: 'gaming montage',
      ),
      SearchIndexRow(
        id: 'classical',
        entityType: SearchEntityType.content,
        title: 'Classical music concert',
        subtitle: 'creator',
        text: 'classical music',
      ),
    ];

    final ranked = ranker.rank(
      query: query,
      candidates: candidates,
      userContext: const SearchUserContext(
        topicAffinity: <String, double>{'gaming': 5},
      ),
      limit: 10,
    );

    expect(ranked.first.id, 'classical');
  });

  test('blocked creators are filtered', () {
    final query = processor.process('music');
    final candidates = <SearchIndexRow>[
      SearchIndexRow(
        id: 'blocked',
        entityType: SearchEntityType.content,
        title: 'Music',
        subtitle: 'creator',
        text: 'music',
        creatorId: 'blocked-user',
      ),
    ];

    final ranked = ranker.rank(
      query: query,
      candidates: candidates,
      userContext: const SearchUserContext(
        blockedCreatorIds: <String>{'blocked-user'},
      ),
    );

    expect(ranked, isEmpty);
  });
}
