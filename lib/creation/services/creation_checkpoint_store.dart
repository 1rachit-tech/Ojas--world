import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/creation_project.dart';

/// Keeps a tiny rolling set of project checkpoints on-device.
/// Originals are never copied here; only project JSON and references are stored.
class CreationCheckpointStore {
  const CreationCheckpointStore._();

  static const CreationCheckpointStore instance = CreationCheckpointStore._();
  static const int _maxCheckpoints = 3;
  static const String _prefix = 'ojas.creation.checkpoints.v1.';

  String _key(String ownerId, String projectId) => '$_prefix$ownerId.$projectId';

  Future<void> save(CreationProject project) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(project.ownerId, project.projectId);
    final existing = prefs.getStringList(key) ?? <String>[];
    final encoded = jsonEncode(project.toMap());
    final next = <String>[encoded, ...existing.where((entry) => entry != encoded)];
    if (next.length > _maxCheckpoints) {
      next.removeRange(_maxCheckpoints, next.length);
    }
    await prefs.setStringList(key, next);
  }

  Future<CreationProject?> recoverLatest({
    required String ownerId,
    required String projectId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_key(ownerId, projectId));
    if (entries == null) return null;
    for (final entry in entries) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map) {
          return CreationProject.fromMap(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Ignore one bad checkpoint and try the next consistent snapshot.
      }
    }
    return null;
  }

  Future<void> clear({required String ownerId, required String projectId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(ownerId, projectId));
  }
}
