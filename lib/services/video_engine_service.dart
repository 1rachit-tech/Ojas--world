import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoEngineService {
  VideoEngineService._();
  static final VideoEngineService instance = VideoEngineService._();

  final Map<String, VideoPlayerController> _controllerPool = {};
  final List<String> _poolLruKeys = [];
  static const int _maxPoolSize = 6;

  Future<VideoPlayerController> getOrCreateController(String videoUrl) async {
    if (_controllerPool.containsKey(videoUrl)) {
      final ctrl = _controllerPool[videoUrl]!;
      _updateLru(videoUrl);
      return ctrl;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );

    _controllerPool[videoUrl] = controller;
    _poolLruKeys.add(videoUrl);
    _evictOldControllers();

    try {
      await controller.initialize().timeout(const Duration(seconds: 12));
      await controller.setLooping(true);
    } catch (e) {
      debugPrint('Pre-cache error for $videoUrl: $e');
    }

    return controller;
  }

  void prefetchNextVideos(List<String> nextUrls) {
    for (final url in nextUrls.take(3)) {
      if (!_controllerPool.containsKey(url)) {
        getOrCreateController(url);
      }
    }
  }

  void _updateLru(String key) {
    _poolLruKeys.remove(key);
    _poolLruKeys.add(key);
  }

  void _evictOldControllers() {
    while (_controllerPool.length > _maxPoolSize && _poolLruKeys.isNotEmpty) {
      final oldestKey = _poolLruKeys.removeAt(0);
      final ctrl = _controllerPool.remove(oldestKey);
      ctrl?.dispose();
    }
  }

  static const ColorFilter superResolutionEnhancer = ColorFilter.matrix(<double>[
    1.12, -0.05, -0.05, 0.0, -2.0,
    -0.05, 1.12, -0.05, 0.0, -2.0,
    -0.05, -0.05, 1.12, 0.0, -2.0,
    0.0,   0.0,   0.0,   1.0,  0.0,
  ]);
}
