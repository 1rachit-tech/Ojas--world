import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

class VideoEngineService {
  VideoEngineService._();
  static final VideoEngineService instance = VideoEngineService._();

  final Map<String, VideoPlayerController> _controllerPool = {};
  final List<String> _poolLruKeys = [];
  static const int _maxPoolSize = 3;

  static final CacheManager _diskCache = CacheManager(
    Config(
      'ojas_video_engine_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 50,
      repo: JsonCacheInfoRepository(databaseName: 'ojas_engine_cache'),
      fileService: HttpFileService(),
    ),
  );

  static const ColorFilter superResolutionEnhancer = ColorFilter.matrix(<double>[
    1.12, -0.05, -0.05, 0.0, -2.0,
    -0.05, 1.12, -0.05, 0.0, -2.0,
    -0.05, -0.05, 1.12, 0.0, -2.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ]);

  Future<VideoPlayerController> getOrCreateController(String videoUrl) async {
    if (videoUrl.isEmpty) {
      throw ArgumentError('Video URL cannot be empty');
    }

    if (_controllerPool.containsKey(videoUrl)) {
      final ctrl = _controllerPool[videoUrl]!;
      _updateLru(videoUrl);
      return ctrl;
    }

    _evictOldControllers();

    VideoPlayerController controller;

    try {
      final fileInfo = await _diskCache.getFileFromCache(videoUrl);

      if (fileInfo != null && await fileInfo.file.exists()) {
        controller = VideoPlayerController.file(
          fileInfo.file,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        );
      } else {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        );
      }

      _controllerPool[videoUrl] = controller;
      _poolLruKeys.add(videoUrl);

      await controller.initialize().timeout(const Duration(seconds: 8));
      await controller.setLooping(true);

      return controller;
    } catch (e) {
      debugPrint('VideoEngine Init Fallback for $videoUrl: $e');
      controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _controllerPool[videoUrl] = controller;
      _poolLruKeys.add(videoUrl);
      try {
        await controller.initialize();
        await controller.setLooping(true);
      } catch (_) {}
      return controller;
    }
  }

  /// Intentionally does not download upcoming files.
  /// A prefetch would transfer the full media object even when the user never
  /// watches it, violating OJAS's usage-proportional bandwidth policy.
  void prefetchNextVideos(List<String> nextUrls) {
    debugPrint(
      'Video prefetch disabled for usage-proportional bandwidth: '
      '${nextUrls.length} candidate(s).',
    );
  }

  /// Explicitly cache a complete file only after the caller has a reason to
  /// retain it locally. This method is never called automatically by the feed.
  Future<void> cacheVideoForOfflineUse(String url) async {
    if (url.trim().isEmpty) {
      return;
    }
    await _diskCache.downloadFile(url);
  }

  void _updateLru(String key) {
    _poolLruKeys.remove(key);
    _poolLruKeys.add(key);
  }

  void _evictOldControllers() {
    while (_controllerPool.length >= _maxPoolSize && _poolLruKeys.isNotEmpty) {
      final oldestKey = _poolLruKeys.removeAt(0);
      final ctrl = _controllerPool.remove(oldestKey);
      ctrl?.pause();
      ctrl?.dispose();
    }
  }

  void pauseAll() {
    for (final ctrl in _controllerPool.values) {
      if (ctrl.value.isInitialized && ctrl.value.isPlaying) {
        ctrl.pause();
      }
    }
  }

  void disposeAll() {
    for (final ctrl in _controllerPool.values) {
      ctrl.dispose();
    }
    _controllerPool.clear();
    _poolLruKeys.clear();
  }
}
