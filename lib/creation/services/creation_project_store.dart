import 'package:shared_preferences/shared_preferences.dart';

import '../models/creation_project.dart';

class CreationProjectStore {
  CreationProjectStore._();

  static final CreationProjectStore instance = CreationProjectStore._();

  static const String _prefix = 'ojas_creation_project_v1_';
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  String _key(String ownerId, String projectId) => '$_prefix${ownerId}_$projectId';

  Future<void> save(CreationProject project) async {
    final prefs = await _prefs;
    await prefs.setString(
      _key(project.ownerId, project.projectId),
      project.encode(),
    );
    await prefs.setString('$_prefix${project.ownerId}_last', project.projectId);
  }

  Future<CreationProject?> load({
    required String ownerId,
    required String projectId,
  }) async {
    final prefs = await _prefs;
    final encoded = prefs.getString(_key(ownerId, projectId));
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return CreationProject.fromEncoded(encoded);
    } catch (_) {
      return null;
    }
  }

  Future<CreationProject?> loadLast({required String ownerId}) async {
    final prefs = await _prefs;
    final projectId = prefs.getString('$_prefix${ownerId}_last');
    if (projectId == null || projectId.isEmpty) return null;
    return load(ownerId: ownerId, projectId: projectId);
  }

  Future<List<CreationProject>> list({required String ownerId}) async {
    final prefs = await _prefs;
    final projects = <CreationProject>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('$_prefix${ownerId}_') || key.endsWith('_last')) {
        continue;
      }
      final encoded = prefs.getString(key);
      if (encoded == null || encoded.isEmpty) continue;
      try {
        projects.add(CreationProject.fromEncoded(encoded));
      } catch (_) {}
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<void> delete({required String ownerId, required String projectId}) async {
    final prefs = await _prefs;
    await prefs.remove(_key(ownerId, projectId));
    final lastKey = '$_prefix${ownerId}_last';
    if (prefs.getString(lastKey) == projectId) {
      await prefs.remove(lastKey);
    }
  }
}
