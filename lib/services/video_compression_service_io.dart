import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

enum VideoDeliveryTier { tier360, tier480, tier720 }

class VideoCompressionResult {
  const VideoCompressionResult({
    required this.file,
    required this.originalBytes,
    required this.compressedBytes,
    required this.profile,
    required this.compressionApplied,
    this.sourceWidth,
    this.sourceHeight,
    this.outputWidth,
    this.outputHeight,
    this.durationMs,
  });

  final XFile file;
  final int originalBytes;
  final int compressedBytes;
  final VideoDeliveryTier profile;
  final bool compressionApplied;
  final int? sourceWidth;
  final int? sourceHeight;
  final int? outputWidth;
  final int? outputHeight;
  final int? durationMs;

  bool get savedBytes => compressedBytes < originalBytes;

  double get compressionRatio {
    if (originalBytes <= 0) return 1.0;
    return compressedBytes / originalBytes;
  }

  String get profileName => switch (profile) {
        VideoDeliveryTier.tier360 => '360p',
        VideoDeliveryTier.tier480 => '480p',
        VideoDeliveryTier.tier720 => '720p',
      };
}

class VideoCompressionService {
  VideoCompressionService._();

  static final VideoCompressionService instance =
      VideoCompressionService._();

  static const int maxDeliveryShortSide = 720;
  static const int _audioBitrateBps = 96 * 1000;

  static VideoDeliveryTier selectTier({
    required int? width,
    required int? height,
  }) {
    final w = width ?? 0;
    final h = height ?? 0;
    final shortSide = w > 0 && h > 0 ? (w < h ? w : h) : maxDeliveryShortSide;
    if (shortSide <= 360) return VideoDeliveryTier.tier360;
    if (shortSide <= 480) return VideoDeliveryTier.tier480;
    return VideoDeliveryTier.tier720;
  }

  int _videoBitrateBps(VideoDeliveryTier tier) {
    switch (tier) {
      case VideoDeliveryTier.tier360:
        return 800 * 1000;
      case VideoDeliveryTier.tier480:
        return 1400 * 1000;
      case VideoDeliveryTier.tier720:
        return 2400 * 1000;
    }
  }

  VideoQuality _qualityFor(VideoDeliveryTier tier) {
    switch (tier) {
      case VideoDeliveryTier.tier360:
        return VideoQuality.LowQuality;
      case VideoDeliveryTier.tier480:
        return VideoQuality.Res640x480Quality;
      case VideoDeliveryTier.tier720:
        return VideoQuality.Res1280x720Quality;
    }
  }

  int _recommendedMaxBytes(VideoDeliveryTier tier, int? durationMs) {
    final durationSeconds = durationMs != null && durationMs > 0
        ? durationMs / 1000.0
        : 60.0;
    final bitrate = _videoBitrateBps(tier) + _audioBitrateBps;
    // Allow 25% headroom for motion complexity/container overhead while still
    // preventing unusually high-bitrate delivery files from reaching cloud.
    final estimate = durationSeconds * bitrate / 8.0 * 1.25;
    final floor = switch (tier) {
      VideoDeliveryTier.tier360 => 6 * 1024 * 1024,
      VideoDeliveryTier.tier480 => 10 * 1024 * 1024,
      VideoDeliveryTier.tier720 => 16 * 1024 * 1024,
    };
    return estimate.ceil().clamp(floor, 64 * 1024 * 1024);
  }

  Future<VideoCompressionResult> prepareForUpload(
    XFile source, {
    required String projectId,
    required String assetId,
    void Function(double progress)? onProgress,
  }) async {
    final original = File(source.path);
    if (!await original.exists()) {
      throw const VideoCompressionException('Selected video is no longer available.');
    }

    final originalBytes = await original.length();
    if (originalBytes <= 0) {
      throw const VideoCompressionException('Selected video is empty.');
    }

    final info = await VideoCompress.getMediaInfo(source.path);
    final sourceWidth = info?.width;
    final sourceHeight = info?.height;
    final durationMs = info?.duration?.round();
    final profile = selectTier(width: sourceWidth, height: sourceHeight);

    final sourceShortSide = sourceWidth != null &&
            sourceHeight != null &&
            sourceWidth > 0 &&
            sourceHeight > 0
        ? (sourceWidth < sourceHeight ? sourceWidth : sourceHeight)
        : maxDeliveryShortSide + 1;
    final sourceExtension = source.path.split(RegExp(r'[\\/]')).last.toLowerCase();
    final withinResolution = sourceShortSide <= maxDeliveryShortSide;
    final withinSizeBudget = originalBytes <= _recommendedMaxBytes(profile, durationMs);
    final compatibleContainer = sourceExtension.endsWith('.mp4');

    // Only skip device encoding when the source is already a sensible MP4
    // delivery rendition. High resolution, oversized, or non-MP4 sources are
    // always normalized on-device. The original is never uploaded as a silent
    // fallback after a compression failure.
    if (withinResolution && withinSizeBudget && compatibleContainer) {
      onProgress?.call(1.0);
      return VideoCompressionResult(
        file: source,
        originalBytes: originalBytes,
        compressedBytes: originalBytes,
        profile: profile,
        compressionApplied: false,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        outputWidth: sourceWidth,
        outputHeight: sourceHeight,
        durationMs: durationMs,
      );
    }

    onProgress?.call(0.02);
    final compressed = await VideoCompress.compressVideo(
      source.path,
      quality: _qualityFor(profile),
      deleteOrigin: false,
      includeAudio: true,
      frameRate: 30,
    );
    onProgress?.call(0.90);

    final output = compressed?.file;
    if (output == null || !await output.exists()) {
      throw const VideoCompressionException(
        'Device compression failed. The original video was not uploaded.',
      );
    }

    final outputInfo = await VideoCompress.getMediaInfo(output.path);
    final outputWidth = outputInfo?.width;
    final outputHeight = outputInfo?.height;
    final outputBytes = await output.length();
    final outputShortSide = outputWidth != null &&
            outputHeight != null &&
            outputWidth > 0 &&
            outputHeight > 0
        ? (outputWidth < outputHeight ? outputWidth : outputHeight)
        : 0;
    if (outputBytes <= 0 ||
        outputShortSide <= 0 ||
        outputShortSide > maxDeliveryShortSide) {
      throw const VideoCompressionException(
        'Device compression produced an invalid delivery video. The original video was not uploaded.',
      );
    }

    final supportDirectory = await getApplicationSupportDirectory();
    final safeProject = _safePathPart(projectId);
    final safeAsset = _safePathPart(assetId);
    final directory = Directory('${supportDirectory.path}/creation-media/$safeProject');
    await directory.create(recursive: true);
    final stablePath = '${directory.path}/${safeAsset}_${profile.name}.mp4';
    final stableFile = File(stablePath);
    if (stableFile.path != output.path) {
      await output.copy(stablePath);
    }

    onProgress?.call(1.0);
    return VideoCompressionResult(
      file: XFile(stableFile.path),
      originalBytes: originalBytes,
      compressedBytes: await stableFile.length(),
      profile: profile,
      compressionApplied: true,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
      durationMs: outputInfo?.duration?.round() ?? durationMs,
    );
  }

  String _safePathPart(String value) {
    final compact = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (compact.isEmpty) return 'media';
    return compact.length > 96 ? compact.substring(0, 96) : compact;
  }
}

class VideoCompressionException implements Exception {
  const VideoCompressionException(this.message);

  final String message;

  @override
  String toString() => message;
}
