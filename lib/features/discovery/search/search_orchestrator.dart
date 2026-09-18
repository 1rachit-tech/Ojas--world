import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import 'azure_search_client.dart';
import 'domain/search_models.dart';
import 'feature_store_client.dart';
import 'query_processor.dart';
import 'ranking/search_ranker.dart';
import 'retrieval/search_repository.dart';
import 'retrieval/semantic_retrieval.dart';
import 'safety/search_safety_service.dart';
import 'search_cache.dart';
import 'search_events.dart';
import 'search_history.dart';

class SearchOrchestrator {
  SearchOrchestrator({
    SearchRepository? repository,
    SearchFeatureStore? featureStore,
    SearchSafetyService? safety,
    SemanticRetrievalProvider? semantic,
    SearchResultCache? cache,
    SearchHistoryStore? history,
    SearchEventQueue? events,
    AzureSearchClient? azureSearch,
    FirebaseAuth? auth,
  })  : _repository = repository ?? SearchRepository(),
        _featureStore = featureStore ?? OjasSearchFeatureStore(),
        _safety = safety ?? SearchSafetyService(),
        _semantic =
            semantic ?? const DisabledSemanticRetrievalProvider(),
        _cache = cache ?? SearchResultCache(),
        _history = history ?? SearchHistoryStore(),
        _events = events ?? SearchEventQueue(),
        _azureSearch = azureSearch ?? AzureSearchClient(auth: auth),
        _auth = auth ?? FirebaseAuth.instance;

  final SearchRepository _repository;
  final SearchFeatureStore _featureStore;
  final SearchSafetyService _safety;
  final SemanticRetrievalProvider _semantic;
  final SearchResultCache _cache;
  final SearchHistoryStore _history;
  final SearchEventQueue _events;
  final AzureSearchClient _azureSearch;
  final FirebaseAuth _auth;
  final SearchQueryProcessor _processor = const SearchQueryProcessor();
  final SearchRanker _ranker = const SearchRanker();
  final Uuid _uuid = const Uuid();

  String? _sessionId;

  String get sessionId => _sessionId ??= _uuid.v4();

  void beginSession() {
    _sessionId = _uuid.v4();
    _events.enqueue(
      SearchEvent(
        sessionId: sessionId,
        eventType: SearchEventType.searchOpen,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> initialize() async {
    await _events.initialize(uid: _auth.currentUser?.uid);
  }

  Future<List<SearchSuggestion>> suggestions(String rawQuery) async {
    final query = rawQuery.trim();
    final history = await _history.load(uid: _auth.currentUser?.uid);

    if (query.isEmpty) {
      final results = <SearchSuggestion>[];
      final seen = <String>{};
      for (final item in history) {
        final key = item.toLowerCase();
        if (!seen.add(key)) continue;
        results.add(
          SearchSuggestion(
            text: item,
            subtitle: 'Recent',
            entityType: SearchEntityType.generic,
          ),
        );
      }
      return results.take(8).toList(growable: false);
    }

    final repositorySuggestions = await _repository.suggest(
      query,
      limit: 8,
    );

    final output = <SearchSuggestion>[];
    final seen = <String>{};

    for (final item in history) {
      if (!item.toLowerCase().contains(query.toLowerCase())) continue;
      if (!seen.add(item.toLowerCase())) continue;
      output.add(
        SearchSuggestion(
          text: item,
          subtitle: 'Recent',
          entityType: SearchEntityType.generic,
        ),
      );
    }

    for (final item in repositorySuggestions) {
      if (seen.add(item.text.toLowerCase())) {
        output.add(item);
      }
      if (output.length >= 8) break;
    }

    for (var index = 0; index < output.length; index++) {
      _events.enqueue(
        SearchEvent(
          sessionId: sessionId,
          eventType: SearchEventType.suggestionImpression,
          createdAt: DateTime.now(),
          query: query,
          position: index,
          resultType: output[index].entityType.name,
          resultId: output[index].id,
        ),
      );
    }

    return output.take(8).toList(growable: false);
  }

  Future<void> recordSuggestionClick(
    SearchSuggestion suggestion,
    String query,
  ) async {
    _events.enqueue(
      SearchEvent(
        sessionId: sessionId,
        eventType: SearchEventType.suggestionClick,
        createdAt: DateTime.now(),
        query: query,
        resultId: suggestion.id,
        resultType: suggestion.entityType.name,
      ),
    );
    if (suggestion.text.trim().isNotEmpty &&
        suggestion.subtitle != 'Recent') {
      await _history.add(
        suggestion.text,
        uid: _auth.currentUser?.uid,
      );
    }
  }

  Future<SearchPage> search(
    String rawQuery, {
    SearchTab tab = SearchTab.all,
    int pageSize = 20,
    String? cursor,
  }) async {
    final query = _processor.process(rawQuery);
    if (query.normalized.isEmpty) {
      return SearchPage(
        results: const <SearchResult>[],
        query: query,
        sessionId: sessionId,
      );
    }

    _events.enqueue(
      SearchEvent(
        sessionId: sessionId,
        eventType: SearchEventType.searchSubmit,
        createdAt: DateTime.now(),
        query: query.normalized,
      ),
    );

    await _history.add(
      query.raw,
      uid: _auth.currentUser?.uid,
    );

    final uid = _auth.currentUser?.uid;
    final queryKey = _queryKey(query, tab);

    if (_azureSearch.isConfigured) {
      try {
        return await _searchAzure(
          query: query,
          tab: tab,
          pageSize: pageSize,
          cursor: cursor,
          uid: uid,
          queryKey: queryKey,
        );
      } on StateError catch (error) {
        if (error.message == 'Search safety context unavailable.') {
          return SearchPage(
            results: const <SearchResult>[],
            query: query,
            sessionId: sessionId,
          );
        }
        rethrow;
      } catch (_) {
        // Azure is the production path, but the legacy path remains a
        // controlled migration fallback until Azure is fully configured.
      }
    }

    try {
      final contextFuture = _featureStore.loadUserContext();
      final blockedFuture = _safety.blockedCreatorIds().timeout(
        const Duration(milliseconds: 120),
        onTimeout: () => null,
      );
      final lexicalFuture = _repository
          .retrieve(
            query,
            entityFilter: tab.entityFilter,
            limit: 100,
          )
          .timeout(
            const Duration(milliseconds: 220),
            onTimeout: () => const <SearchIndexRow>[],
          );
      final semanticFuture = _semantic
          .retrieve(query, limit: 60)
          .timeout(
            const Duration(milliseconds: 120),
            onTimeout: () => const <SearchIndexRow>[],
          )
          .catchError((_) => const <SearchIndexRow>[]);

      final values = await Future.wait<dynamic>([
        contextFuture,
        blockedFuture,
        lexicalFuture,
        semanticFuture,
      ]);

      final userContext = values[0] as SearchUserContext;
      final blockedValue = values[1] as Set<String>?;
      if (blockedValue == null) {
        throw StateError('Search safety context unavailable.');
      }
      final blocked = blockedValue;
      final lexical = values[2] as List<SearchIndexRow>;
      final semantic = values[3] as List<SearchIndexRow>;

      final merged = <String, SearchIndexRow>{};
      for (final candidate in lexical) {
        merged[candidate.entityType.name + ':' + candidate.id] = candidate;
      }
      for (final candidate in semantic) {
        final key = candidate.entityType.name + ':' + candidate.id;
        merged[key] = candidate;
      }

      final enrichedContext = SearchUserContext(
        creatorAffinity: userContext.creatorAffinity,
        topicAffinity: userContext.topicAffinity,
        hashtagAffinity: userContext.hashtagAffinity,
        soundAffinity: userContext.soundAffinity,
        contentTypeAffinity: userContext.contentTypeAffinity,
        negativeAffinity: userContext.negativeAffinity,
        blockedCreatorIds: blocked,
      );

      var ranked = _ranker.rank(
        query: query,
        candidates: merged.values,
        userContext: enrichedContext,
        entityFilter: tab.entityFilter,
        limit: 100,
      );

      ranked = _ranker.blend(
        tab: tab,
        results: ranked,
        limit: 100,
      );

      var startIndex = 0;
      if (cursor != null && cursor.isNotEmpty) {
        startIndex = ranked.indexWhere((result) => result.stableId == _decodeCursor(cursor));
        if (startIndex >= 0) {
          startIndex++;
        } else {
          startIndex = 0;
        }
      }

      final pageResults = ranked
          .skip(startIndex)
          .take(pageSize)
          .toList(growable: false);

      for (var index = 0; index < pageResults.length; index++) {
        _events.enqueue(
          SearchEvent(
            sessionId: sessionId,
            eventType: SearchEventType.resultImpression,
            createdAt: DateTime.now(),
            query: query.normalized,
            resultId: pageResults[index].id,
            resultType: pageResults[index].entityType.name,
            position: startIndex + index,
          ),
        );
      }

      final hasMore = startIndex + pageResults.length < ranked.length;
      final nextCursor = hasMore && pageResults.isNotEmpty
          ? _encodeCursor(pageResults.last.stableId)
          : null;

      if (pageResults.isNotEmpty) {
        await _cache.write(
          queryKey: queryKey,
          results: pageResults,
          uid: uid,
        );
      }

      if (pageResults.isEmpty) {
        _events.enqueue(
          SearchEvent(
            sessionId: sessionId,
            eventType: SearchEventType.searchZeroResult,
            createdAt: DateTime.now(),
            query: query.normalized,
          ),
        );
      }

      final didYouMean = pageResults.isEmpty
          ? await _didYouMean(query)
          : null;

      return SearchPage(
        results: pageResults,
        query: query,
        sessionId: sessionId,
        cursor: nextCursor,
        hasMore: hasMore,
        didYouMean: didYouMean,
      );
    } catch (error) {
      if (error is StateError &&
          error.message == 'Search safety context unavailable.') {
        return SearchPage(
          results: const <SearchResult>[],
          query: query,
          sessionId: sessionId,
        );
      }

      final cached = await _cache.read(
        queryKey: queryKey,
        uid: uid,
      );

      if (cached != null && cached.isNotEmpty) {
        return SearchPage(
          results: cached,
          query: query,
          sessionId: sessionId,
          fromCache: true,
          offline: true,
          didYouMean: await _didYouMean(query),
        );
      }

      rethrow;
    }
  }

  Future<void> recordResultClick(
  Future<SearchPage> _searchAzure({
    required SearchQuery query,
    required SearchTab tab,
    required int pageSize,
    required String? cursor,
    required String? uid,
    required String queryKey,
  }) async {
    final blockedFuture = _safety.blockedCreatorIds().timeout(
      const Duration(milliseconds: 120),
      onTimeout: () => null,
    );

    final azureFuture = _azureSearch.search(
      query: query.raw,
      tab: tab,
      pageSize: pageSize,
      cursor: cursor,
    );

    final values = await Future.wait<dynamic>([
      blockedFuture,
      azureFuture,
    ]);

    final blocked = values[0] as Set<String>?;
    if (blocked == null) {
      throw StateError('Search safety context unavailable.');
    }

    final remotePage = values[1] as SearchPage;

    final safeResults = remotePage.results
        .where((result) => !blocked.contains(result.creatorId))
        .toList(growable: false);

    for (var index = 0; index < safeResults.length; index++) {
      _events.enqueue(
        SearchEvent(
          sessionId: sessionId,
          eventType: SearchEventType.resultImpression,
          createdAt: DateTime.now(),
          query: query.normalized,
          resultId: safeResults[index].id,
          resultType: safeResults[index].entityType.name,
          position: index,
        ),
      );
    }

    if (safeResults.isNotEmpty) {
      await _cache.write(
        queryKey: queryKey,
        results: safeResults,
        uid: uid,
      );
    } else {
      _events.enqueue(
        SearchEvent(
          sessionId: sessionId,
          eventType: SearchEventType.searchZeroResult,
          createdAt: DateTime.now(),
          query: query.normalized,
        ),
      );
    }

    return SearchPage(
      results: safeResults,
      query: query,
      sessionId: sessionId,
      cursor: remotePage.cursor,
      hasMore: remotePage.hasMore,
      fromCache: remotePage.fromCache,
      offline: remotePage.offline,
      didYouMean: remotePage.didYouMean ??
          (safeResults.isEmpty ? await _didYouMean(query) : null),
    );
  }

    SearchResult result,
    int position,
    String query,
  ) async {
    final type = result.entityType;
    final eventType = switch (type) {
      SearchEntityType.person => SearchEventType.profileOpenFromSearch,
      SearchEntityType.content => SearchEventType.contentOpenFromSearch,
      SearchEntityType.hashtag => SearchEventType.hashtagOpenFromSearch,
      SearchEntityType.sound => SearchEventType.soundOpenFromSearch,
      SearchEntityType.topic => SearchEventType.topicOpenFromSearch,
      SearchEntityType.place => SearchEventType.placeOpenFromSearch,
      SearchEntityType.live => SearchEventType.resultClick,
      SearchEntityType.generic => SearchEventType.resultClick,
    };

    _events.enqueue(
      SearchEvent(
        sessionId: sessionId,
        eventType: eventType,
        createdAt: DateTime.now(),
        query: query,
        resultId: result.id,
        resultType: type.name,
        position: position,
      ),
    );
  }

  Future<void> recordPostClickSignal({
    required SearchEventType type,
    required SearchResult result,
    required String query,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async {
    _events.enqueue(
      SearchEvent(
        sessionId: sessionId,
        eventType: type,
        createdAt: DateTime.now(),
        query: query,
        resultId: result.id,
        resultType: result.entityType.name,
        metadata: metadata,
      ),
    );
  }

  Future<void> refine(String query) async {
    _events.enqueue(
      SearchEvent(
        sessionId: sessionId,
        eventType: SearchEventType.searchRefine,
        createdAt: DateTime.now(),
        query: query,
      ),
    );
  }

  Future<void> cancel(String query) async {
    _events.enqueue(
      SearchEvent(
        sessionId: sessionId,
        eventType: SearchEventType.searchCancel,
        createdAt: DateTime.now(),
        query: query,
      ),
    );
  }

  Future<void> removeHistory(String query) =>
      _history.remove(query, uid: _auth.currentUser?.uid);

  Future<void> clearHistory() =>
      _history.clear(uid: _auth.currentUser?.uid);

  Future<String?> _didYouMean(SearchQuery query) async {
    final suggestions = await _repository.suggest(query.normalized, limit: 12);
    return SearchQueryProcessor.didYouMean(
      query.raw,
      suggestions.map((item) => item.text),
    );
  }

  String _queryKey(SearchQuery query, SearchTab tab) =>
      jsonEncode(<String>[query.normalized, query.language, tab.name]);

  String _encodeCursor(String value) => base64Url.encode(
    utf8.encode(value),
  );

  String _decodeCursor(String cursor) {
    try {
      return utf8.decode(base64Url.decode(cursor));
    } catch (_) {
      return cursor;
    }
  }
}
