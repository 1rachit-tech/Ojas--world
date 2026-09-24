import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'domain/search_models.dart';

class SearchResultCache {
  SearchResultCache({
    this.maxEntries = 12,
    this.ttl = const Duration(minutes: 20),
  });

  final int maxEntries;
  final Duration ttl;

  String _key(String? uid) =>
      'ojas_search_cache_v2_' + (uid == null || uid.isEmpty ? 'signed_out' : uid);

  Future<void> write({
    required String queryKey,
    required List<SearchResult> results,
    String? uid,
  }) async {
    if (results.isEmpty) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      final current = await _readRaw(preferences, uid);
      final existingIndex = current.indexWhere(
        (entry) => entry['queryKey'] == queryKey,
      );
      if (existingIndex >= 0) {
        current.removeAt(existingIndex);
      }
      current.insert(0, <String, dynamic>{
        'queryKey': queryKey,
        'savedAt': DateTime.now().toIso8601String(),
        'results': results.map((result) => result.toCacheMap()).toList(),
      });
      if (current.length > maxEntries) {
        current.removeRange(maxEntries, current.length);
      }
      await preferences.setString(_key(uid), jsonEncode(current));
    } catch (_) {}
  }

  Future<List<SearchResult>?> read({
    required String queryKey,
    String? uid,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final entries = await _readRaw(preferences, uid);
      for (final entry in entries) {
        if (entry['queryKey'] != queryKey) continue;
        final savedAt = DateTime.tryParse(entry['savedAt'] as String? ?? '');
        if (savedAt == null ||
            DateTime.now().difference(savedAt) > ttl) {
          return null;
        }
        final rawResults = entry['results'];
        if (rawResults is! List) return null;
        final results = <SearchResult>[];
        for (final raw in rawResults) {
          if (raw is! Map) continue;
          final result = SearchResult.fromCacheMap(
            Map<String, dynamic>.from(raw),
          );
          if (result != null) results.add(result);
        }
        return results;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _readRaw(
    SharedPreferences preferences,
    String? uid,
  ) async {
    final raw = preferences.getString(_key(uid));
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Map<String, dynamic>>[];

    return decoded
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: true);
  }
}
