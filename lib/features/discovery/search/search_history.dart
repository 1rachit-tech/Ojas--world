import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStore {
  SearchHistoryStore({this.maxItems = 20, this.expiry = const Duration(days: 30)});

  final int maxItems;
  final Duration expiry;

  String _key(String? uid) =>
      'ojas_search_history_v2_' + (uid == null || uid.isEmpty ? 'signed_out' : uid);

  Future<List<String>> load({String? uid}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key(uid));
      if (raw == null || raw.isEmpty) return const <String>[];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];

      final now = DateTime.now();
      final entries = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final query = item['query'];
        final createdAt = DateTime.tryParse(item['createdAt'] as String? ?? '');
        if (query is! String || query.trim().isEmpty || createdAt == null) continue;
        if (now.difference(createdAt) > expiry) continue;
        entries.add({
          'query': query.trim(),
          'createdAt': createdAt.toIso8601String(),
        });
      }

      entries.sort((a, b) =>
          (DateTime.parse(b['createdAt'] as String))
              .compareTo(DateTime.parse(a['createdAt'] as String)));

      final result = <String>[];
      final seen = <String>{};
      for (final entry in entries) {
        final value = entry['query'] as String;
        final key = value.toLowerCase();
        if (seen.add(key)) result.add(value);
        if (result.length >= maxItems) break;
      }
      return result;
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> add(String query, {String? uid}) async {
    final value = query.trim();
    if (value.isEmpty) return;

    final current = await load(uid: uid);
    final next = <Map<String, dynamic>>[
      {
        'query': value,
        'createdAt': DateTime.now().toIso8601String(),
      },
    ];

    for (final item in current) {
      if (item.toLowerCase() == value.toLowerCase()) continue;
      next.add({
        'query': item,
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (next.length >= maxItems) break;
    }

    await _write(next, uid);
  }

  Future<void> remove(String query, {String? uid}) async {
    final current = await load(uid: uid);
    final next = current
        .where((item) => item.toLowerCase() != query.trim().toLowerCase())
        .map((item) => <String, dynamic>{
              'query': item,
              'createdAt': DateTime.now().toIso8601String(),
            })
        .toList(growable: false);
    await _write(next, uid);
  }

  Future<void> clear({String? uid}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_key(uid));
    } catch (_) {}
  }

  Future<void> _write(List<Map<String, dynamic>> values, String? uid) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_key(uid), jsonEncode(values.take(maxItems).toList()));
    } catch (_) {}
  }
}
