import 'dart:async';
import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
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
    var value = _configuredBaseUrl.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.isEmpty) return '';
    // Azure Functions uses the standard /api route prefix.
    if (!value.endsWith('/api')) {
      value += '/api';
    }
    return value;
  }

  bool get isConfigured => baseUrl.isNotEmpty;

  Future<SearchPage> search({
    required String query,
    required SearchTab tab,
    int pageSize = 20,
    String? cursor,
  }) async {
    final safePageSize = _boundedPageSize(pageSize);
    final payload = await _postJson(
      '/v1/search',
      <String, dynamic>{
        'query': query,
        'tab': tab.name,
        'pageSize': safePageSize,
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
            .where(_isUsableResult)
            .take(safePageSize)
            .toList(growable: false)
        : const <SearchResult>[];

    return SearchPage(
      results: results,
      query: _queryFromJson(payload['query'], query),
      sessionId: _string(payload['sessionId']),
      cursor: _nullableString(payload['cursor']),
      hasMore: payload['hasMore'] == true,
      fromCache: payload['fromCache'] == true,
      offline: payload['offline'] == true,
      didYouMean: _nullableString(payload['didYouMean']),
    );
  }

  Future<List<SearchSuggestion>> suggestions(
    String query, {
    int limit = 8,
  }) async {
    final safeLimit = _boundedPageSize(limit, max: 20);
    final payload = await _postJson(
      '/v1/search/suggestions',
      <String, dynamic>{
        'query': query,
        'limit': safeLimit,
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
            text: _string(map['text']),
            subtitle: _string(map['subtitle']),
            entityType: _entityType(map['entityType']),
            id: _string(map['id']),
            imageUrl: _string(map['imageUrl']),
          );
        })
        .where((item) => item.text.trim().isNotEmpty)
        .take(safeLimit)
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

    String appCheckToken;
    try {
      appCheckToken = await FirebaseAppCheck.instance.getToken() ?? '';
    } catch (error) {
      throw AzureSearchException(
        'App verification unavailable: $error',
      );
    }

    if (appCheckToken.isEmpty) {
      throw const AzureSearchException(
        'App verification token is unavailable.',
      );
    }

    final response = await _http
        .post(
          Uri.parse(baseUrl + path),
          headers: <String, String>{
            'content-type': 'application/json',
            'authorization': 'Bearer ' + token,
            'x-firebase-appcheck': appCheckToken,
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
      id: _string(map['id']),
      entityType: _entityType(map['entityType']),
      title: _string(map['title']),
      subtitle: _string(map['subtitle']),
      score: _number(map['score']),
      queryScore: _number(map['queryScore']),
      personalScore: _number(map['personalScore']),
      qualityScore: _number(map['qualityScore']),
      popularityScore: _number(map['popularityScore']),
      freshnessScore: _number(map['freshnessScore']),
      trendScore: _number(map['trendScore']),
      imageUrl: _string(map['imageUrl']),
      creatorId: _string(map['creatorId']),
      contentUrl: _string(map['contentUrl']),
      audioTrackId: _string(map['audioTrackId']),
      createdAt: DateTime.tryParse(_string(map['createdAt'])),
      tags: map['tags'] is List
          ? (map['tags'] as List)
              .whereType<String>()
              .toList(growable: false)
          : const <String>[],
      extra: map['extra'] is Map
          ? Map<String, dynamic>.from(map['extra'] as Map)
          : const <String, dynamic>{},
    );
  }

  bool _isUsableResult(SearchResult result) =>
      result.id.trim().isNotEmpty && result.title.trim().isNotEmpty;

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
    if (value is! String) return SearchEntityType.generic;
    return SearchEntityType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => SearchEntityType.generic,
    );
  }

  String _string(Object? value) => value is String ? value : '';

  String? _nullableString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  int _boundedPageSize(int value, {int max = 50}) => value.clamp(1, max).toInt();

  double _number(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
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
