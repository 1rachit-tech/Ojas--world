import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'domain/search_models.dart';

class AzureSearchException implements Exception {
  const AzureSearchException(this.message);

  final String message;

  @override
  String toString() => 'AzureSearchException: ' + message;
}

class AzureSearchClient {
  AzureSearchClient({
    FirebaseAuth? auth,
    http.Client? httpClient,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _http = httpClient ?? http.Client();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'OJAS_SEARCH_API_BASE_URL',
    defaultValue: '',
  );

  static const bool _allowRemoteEvents = bool.fromEnvironment(
    'OJAS_SEARCH_REMOTE_EVENTS',
    defaultValue: true,
  );

  final FirebaseAuth _auth;
  final http.Client _http;

  String get baseUrl {
    final value = _configuredBaseUrl.trim();
    return value.endsWith('/')
        ? value.substring(0, value.length - 1)
        : value;
  }

  bool get isConfigured => baseUrl.isNotEmpty;

  Future<SearchPage> search({
    required String query,
    required SearchTab tab,
    int pageSize = 20,
    String? cursor,
  }) async {
    final payload = await _postJson(
      '/v1/search',
      <String, dynamic>{
        'query': query,
        'tab': tab.name,
        'pageSize': pageSize,
        'cursor': cursor,
      },
      timeout: const Duration(milliseconds: 800),
    );

    final rawResults = payload['results'];
    final results = rawResults is List
        ? rawResults
            .whereType<Map>()
            .map(
              (item) => _resultFromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false)
        : const <SearchResult>[];

    return SearchPage(
      results: results,
      query: _queryFromJson(payload['query'], query),
      sessionId: payload['sessionId'] as String? ?? '',
      cursor: payload['cursor'] as String?,
      hasMore: payload['hasMore'] == true,
      fromCache: payload['fromCache'] == true,
      offline: payload['offline'] == true,
      didYouMean: payload['didYouMean'] as String?,
    );
  }

  Future<List<SearchSuggestion>> suggestions(
    String query, {
    int limit = 8,
  }) async {
    final payload = await _postJson(
      '/v1/search/suggestions',
      <String, dynamic>{
        'query': query,
        'limit': limit,
      },
      timeout: const Duration(milliseconds: 400),
    );

    final raw = payload['suggestions'];
    if (raw is! List) return const <SearchSuggestion>[];

    return raw
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return SearchSuggestion(
            text: map['text'] as String? ?? '',
            subtitle: map['subtitle'] as String? ?? '',
            entityType: _entityType(map['entityType']),
            id: map['id'] as String? ?? '',
            imageUrl: map['imageUrl'] as String? ?? '',
          );
        })
        .where((item) => item.text.trim().isNotEmpty)
        .take(limit)
        .toList(growable: false);
  }

  Future<void> recordEvents(
    List<SearchEventPayload> events,
  ) async {
    if (!isConfigured ||
        !_allowRemoteEvents ||
        events.isEmpty) {
      return;
    }

    try {
      await _postJson(
        '/v1/search/events',
        <String, dynamic>{
          'events': events.map((event) => event.toJson()).toList(),
        },
        timeout: const Duration(milliseconds: 900),
      );
    } catch (_) {
      // Analytics must never block search.
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    required Duration timeout,
  }) async {
    if (!isConfigured) {
      throw const AzureSearchException(
        'OJAS_SEARCH_API_BASE_URL is not configured.',
      );
    }

    final user = _auth.currentUser;
    final token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const AzureSearchException(
        'An authenticated Firebase user is required.',
      );
    }

    final response = await _http
        .post(
          Uri.parse(baseUrl + path),
          headers: <String, String>{
            'content-type': 'application/json',
            'authorization': 'Bearer ' + token,
            'x-ojas-client': 'flutter',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AzureSearchException(
        'HTTP ' +
            response.statusCode.toString() +
            ': ' +
            response.body,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AzureSearchException(
        'Azure Search API returned invalid JSON.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  SearchResult _resultFromJson(Map<String, dynamic> map) {
    return SearchResult(
      id: map['id'] as String? ?? '',
      entityType: _entityType(map['entityType']),
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      score: _number(map['score']),
      queryScore: _number(map['queryScore']),
      personalScore: _number(map['personalScore']),
      qualityScore: _number(map['qualityScore']),
      popularityScore: _number(map['popularityScore']),
      freshnessScore: _number(map['freshnessScore']),
      trendScore: _number(map['trendScore']),
      imageUrl: map['imageUrl'] as String? ?? '',
      creatorId: map['creatorId'] as String? ?? '',
      contentUrl: map['contentUrl'] as String? ?? '',
      audioTrackId: map['audioTrackId'] as String? ?? '',
      createdAt: DateTime.tryParse(
        map['createdAt'] as String? ?? '',
      ),
      tags: map['tags'] is List
          ? List<String>.from(
              (map['tags'] as List).whereType<String>(),
            )
          : const <String>[],
      extra: map['extra'] is Map
          ? Map<String, dynamic>.from(map['extra'] as Map)
          : const <String, dynamic>{},
    );
  }

  SearchQuery _queryFromJson(
    Object? value,
    String fallback,
  ) {
    final raw = value is String && value.trim().isNotEmpty
        ? value
        : fallback;

    return SearchQuery(
      raw: raw,
      normalized: raw.trim().toLowerCase(),
      tokens: raw
          .trim()
          .split(RegExp(r'\s+'))
          .where((token) => token.isNotEmpty)
          .toList(growable: false),
      aliases: <String>[raw.trim()],
      language: 'auto',
      intent: SearchEntityType.generic,
    );
  }

  SearchEntityType _entityType(Object? value) {
    final name = value as String?;
    return SearchEntityType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => SearchEntityType.generic,
    );
  }

  double _number(Object? value) {
    if (value is num) return value.toDouble();
    return 0;
  }
}

class SearchEventPayload {
  const SearchEventPayload({
    required this.sessionId,
    required this.eventType,
    required this.createdAt,
    this.query = '',
    this.resultId = '',
    this.resultType = '',
    this.position = 0,
    this.metadata = const <String, Object?>{},
  });

  final String sessionId;
  final String eventType;
  final DateTime createdAt;
  final String query;
  final String resultId;
  final String resultType;
  final int position;
  final Map<String, Object?> metadata;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'eventType': eventType,
      'createdAt': createdAt.toIso8601String(),
      'query': query,
      'resultId': resultId,
      'resultType': resultType,
      'position': position,
      'metadata': metadata,
    };
  }
}
