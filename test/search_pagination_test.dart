import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/features/discovery/search/domain/search_models.dart';

void main() {
  const query = SearchQuery(
    raw: 'music',
    normalized: 'music',
    tokens: <String>['music'],
    aliases: <String>['music'],
    language: 'en',
    intent: SearchEntityType.sound,
  );

  test('search page preserves opaque pagination state', () {
    const page = SearchPage(
      results: <SearchResult>[
        SearchResult(
          id: 'show-1',
          entityType: SearchEntityType.content,
          title: 'Music Show',
          subtitle: '@creator',
          score: 1,
        ),
      ],
      query: query,
      sessionId: 'session-1',
      cursor: 'opaque-cursor',
      hasMore: true,
    );

    expect(page.cursor, 'opaque-cursor');
    expect(page.hasMore, isTrue);
    expect(page.results.single.stableId, 'content:show-1');
  });

  test('entity filters map to the production search tabs', () {
    expect(SearchTab.people.entityFilter, SearchEntityType.person);
    expect(SearchTab.videos.entityFilter, SearchEntityType.content);
    expect(SearchTab.hashtags.entityFilter, SearchEntityType.hashtag);
    expect(SearchTab.sounds.entityFilter, SearchEntityType.sound);
    expect(SearchTab.topics.entityFilter, SearchEntityType.topic);
    expect(SearchTab.live.entityFilter, SearchEntityType.live);
    expect(SearchTab.places.entityFilter, SearchEntityType.place);
  });
}
