import 'dart:async';

import '../models/home_feed_models.dart';

abstract interface class HomePlaybackHandle {
  Future<void> play();
  Future<void> pause();
  Future<void> release();
}

typedef HomeVisibilityProbe = double Function();

class HomePlaybackCoordinator {
  HomePlaybackCoordinator({this.maxActiveControllers = 1});

  final int maxActiveControllers;
  final Map<String, HomePlaybackHandle> _handles = <String, HomePlaybackHandle>{};
  final Map<String, HomeVisibilityProbe> _visibilityProbes = <String, HomeVisibilityProbe>{};
  final Set<String> _activeIds = <String>{};

  String? get activeContentId => _activeIds.isEmpty ? null : _activeIds.first;

  void register(String contentId, HomePlaybackHandle handle) {
    if (contentId.isEmpty) return;
    _handles[contentId] = handle;
  }

  void registerVisibilityProbe(String contentId, HomeVisibilityProbe probe) {
    if (contentId.isEmpty) return;
    _visibilityProbes[contentId] = probe;
  }

  void unregister(String contentId) {
    _visibilityProbes.remove(contentId);
    _handles.remove(contentId);
    _activeIds.remove(contentId);
  }

  Future<void> activate(String contentId) async {
    if (!_handles.containsKey(contentId)) return;

    for (final id in _activeIds.toList()) {
      if (id == contentId) continue;
      await _handles[id]?.pause();
      _activeIds.remove(id);
    }

    if (_activeIds.length >= maxActiveControllers) {
      final oldest = _activeIds.first;
      await _handles[oldest]?.pause();
      _activeIds.remove(oldest);
    }

    await _handles[contentId]?.play();
    _activeIds.add(contentId);
  }

  Future<void> pause(String contentId) async {
    await _handles[contentId]?.pause();
    _activeIds.remove(contentId);
  }

  Future<void> pauseAll() async {
    for (final id in _activeIds.toList()) {
      await _handles[id]?.pause();
    }
    _activeIds.clear();
  }

  Future<void> evaluateDominantVisibility({double activationThreshold = 0.60}) async {
    if (_visibilityProbes.isEmpty) return;

    String? dominantId;
    var dominantFraction = 0.0;
    for (final entry in _visibilityProbes.entries) {
      double fraction;
      try {
        fraction = entry.value().clamp(0.0, 1.0);
      } catch (_) {
        continue;
      }
      if (fraction > dominantFraction) {
        dominantFraction = fraction;
        dominantId = entry.key;
      }
    }

    if (dominantId == null || dominantFraction < activationThreshold) {
      await pauseAll();
      return;
    }

    await activate(dominantId);
  }

  Future<void> disposeDistant(Iterable<String> retainedIds) async {
    final retained = retainedIds.toSet();
    final disposable = _handles.keys.where((id) => !retained.contains(id)).toList(growable: false);
    for (final id in disposable) {
      await _handles[id]?.release();
      _handles.remove(id);
      _visibilityProbes.remove(id);
      _activeIds.remove(id);
    }
  }

  Future<void> disposeAll() async {
    for (final handle in _handles.values) {
      await handle.release();
    }
    _handles.clear();
    _visibilityProbes.clear();
    _activeIds.clear();
  }

  HomePlaybackState stateFor(String contentId, HomePlaybackState fallback) {
    return _activeIds.contains(contentId) ? HomePlaybackState.playing : fallback;
  }

  void scheduleDistantCleanup(Iterable<String> retainedIds) {
    unawaited(disposeDistant(retainedIds));
  }
}
