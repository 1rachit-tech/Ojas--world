import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/creation_publish_state.dart';

class CreationPublishStateStore {
  const CreationPublishStateStore._();

  static const CreationPublishStateStore instance = CreationPublishStateStore._();
  static const String _prefix = 'ojas.creation.publish-state.';

  String _key(String projectId) => '$_prefix$projectId';

  Future<void> save(CreationPublishState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(state.projectId), jsonEncode(state.toMap()));
  }

  Future<CreationPublishState?> load(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key(projectId));
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      return CreationPublishState.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(projectId));
  }
}
