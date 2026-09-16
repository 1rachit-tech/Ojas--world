import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_feed_models.dart';

class HomeFeedSessionSnapshot {
  const HomeFeedSessionSnapshot({
    required this.sessionId,
    required this.mode,
    required this.scrollOffset,
    required this.servedItemIds,
    required this.seenItemIds,
  });

  final String sessionId;
  final HomeFeedMode mode;
  final double scrollOffset;
  final List<String> servedItemIds;
  final List<String> seenItemIds;

  Map<String, Object?> toMap() => <String, Object?>{
        'sessionId': sessionId,
        'mode': mode.name,
        'scrollOffset': scrollOffset,
        'servedItemIds': servedItemIds,
        'seenItemIds': seenItemIds,
      };

  static HomeFeedSessionSnapshot? fromMap(Map<String, dynamic> data) {
    final sessionId = data['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) return null;
    final modeName = data['mode'] as String? ?? HomeFeedMode.personalized.name;
    final mode = HomeFeedMode.values.firstWhere(
      (value) => value.name == modeName,
      orElse: () => HomeFeedMode.personalized,
    );
    return HomeFeedSessionSnapshot(
      sessionId: sessionId,
      mode: mode,
      scrollOffset: (data['scrollOffset'] as num?)?.toDouble() ?? 0,
      servedItemIds: _strings(data['servedItemIds']),
      seenItemIds: _strings(data['seenItemIds']),
    );
  }

  static List<String> _strings(Object? value) => value is List
      ? value.whereType<String>().toList(growable: false)
      : const <String>[];
}

class HomeFeedSessionStore {
  static const String _key = 'ojas_home_session_v1';

  Future<void> save(HomeSessionState session, double scrollOffset) async {
    final preferences = await SharedPreferences.getInstance();
    final snapshot = HomeFeedSessionSnapshot(
      sessionId: session.sessionId,
      mode: session.mode,
      scrollOffset: scrollOffset,
      servedItemIds: session.servedItems.toList(growable: false),
      seenItemIds: session.seenItems.toList(growable: false),
    );
    await preferences.setString(_key, jsonEncode(snapshot.toMap()));
  }

  Future<HomeFeedSessionSnapshot?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return HomeFeedSessionSnapshot.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
