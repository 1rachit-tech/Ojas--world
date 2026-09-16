import 'dart:async';

import '../models/home_feed_models.dart';

abstract interface class HomePlaybackHandle {
  Future<void> play();
  Future<void> pause();
  Future<void> release();
}

class HomePlaybackCoordinator {
  HomePlaybackCoordinator({this.maxActiveControllers = 1});

  final int maxActiveControllers;
  final Map<String, HomePlaybackHandle> _handles = <String, HomePlaybackHandle>{};
  final Set<String> _activeIds = <String>{};

  String? get activeContentId => _activeIds.isEmpty ? null : _activeIds.first;

  void register(String contentId, HomePlaybackHandle handle) {
    if (contentId.isEmpty) return;
    _handles[contentId] = handle;
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

  Future<void> disposeDistant(Iterable<String> retainedIds) async {
    final retained = retainedIds.toSet();
    final disposable = _handles.keys.where((id) => !retained.contains(id)).toList(growable: false);
    for (final id in disposable) {
      await _handles[id]?.release();
      _handles.remove(id);
      _activeIds.remove(id);
    }
  }

  Future<void> disposeAll() async {
    for (final handle in _handles.values) {
      await handle.release();
    }
    _handles.clear();
    _activeIds.clear();
  }

  HomePlaybackState stateFor(String contentId, HomePlaybackState fallback) {
    return _activeIds.contains(contentId) ? HomePlaybackState.playing : fallback;
  }

  void scheduleDistantCleanup(Iterable<String> retainedIds) {
    unawaited(disposeDistant(retainedIds));
  }
}
