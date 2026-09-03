import 'dart:async';
import 'package:flutter/foundation.dart';

enum NetworkTier { low2G, medium3G, high4G5G }

class NetworkQualityService {
  NetworkQualityService._();
  static final NetworkQualityService instance = NetworkQualityService._();

  NetworkTier _currentTier = NetworkTier.high4G5G;
  NetworkTier get currentTier => _currentTier;

  // Dynamically determines chunk buffer based on speed
  int get targetPreloadChunkBytes {
    switch (_currentTier) {
      case NetworkTier.low2G:
        return 512 * 1024; // 512 KB (Instant 0-buffer playback)
      case NetworkTier.medium3G:
        return 1024 * 1024; // 1 MB
      case NetworkTier.high4G5G:
        return 2 * 1024 * 1024; // 2 MB
    }
  }

  void updateConnectionSpeed(int latencyMs) {
    if (latencyMs > 500) {
      _currentTier = NetworkTier.low2G;
    } else if (latencyMs > 200) {
      _currentTier = NetworkTier.medium3G;
    } else {
      _currentTier = NetworkTier.high4G5G;
    }
    debugPrint('OJAS Network Adaptive Tier: $_currentTier');
  }
}
