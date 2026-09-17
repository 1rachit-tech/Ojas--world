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

  CreationProject? _decodeLatest(List<String>? entries) {
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

  Future<CreationProject?> recoverLatest({
    required String ownerId,
    required String projectId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeLatest(prefs.getStringList(_key(ownerId, projectId)));
  }

  /// Returns the newest recoverable checkpoint for every project owner.
  /// This also discovers checkpoint-only projects whose primary draft record
  /// disappeared after a crash or partial write.
  Future<List<CreationProject>> listLatest({required String ownerId}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_prefix$ownerId.';
    final projects = <CreationProject>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final project = _decodeLatest(prefs.getStringList(key));
      if (project == null || project.ownerId != ownerId) continue;
      projects.add(project);
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<void> clear({required String ownerId, required String projectId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(ownerId, projectId));
  }
}
