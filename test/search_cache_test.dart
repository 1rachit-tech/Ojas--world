import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ojas_app/features/discovery/search/domain/search_models.dart';
import 'package:ojas_app/features/discovery/search/search_cache.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const result = SearchResult(
    id: 'show-1',
    entityType: SearchEntityType.content,
    title: 'Music Show',
    subtitle: '@creator',
    score: 1,
    creatorId: 'creator-1',
  );

  test('writes and restores a search result from local cache', () async {
    final cache = SearchResultCache();
    await cache.write(
      queryKey: '["music","en","all"]',
      results: const <SearchResult>[result],
      uid: 'user-1',
    );

    final restored = await cache.read(
      queryKey: '["music","en","all"]',
      uid: 'user-1',
    );

    expect(restored, isNotNull);
    expect(restored, hasLength(1));
    expect(restored!.single.id, 'show-1');
    expect(restored.single.stableId, 'content:show-1');
  });

  test('keeps caches isolated by authenticated user', () async {
    final cache = SearchResultCache();
    await cache.write(
      queryKey: 'music',
      results: const <SearchResult>[result],
      uid: 'user-a',
    );

    expect(
      await cache.read(queryKey: 'music', uid: 'user-b'),
      isNull,
    );
  });

  test('ignores malformed cached JSON instead of crashing search', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ojas_search_cache_v2_user-1',
      '[{"queryKey":"music","savedAt":"bad-date","results":[]}]',
    );

    final cache = SearchResultCache();
    expect(
      await cache.read(queryKey: 'music', uid: 'user-1'),
      isNull,
    );
  });
}
