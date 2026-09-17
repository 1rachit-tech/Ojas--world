import 'package:image_picker/image_picker.dart';

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

  static VideoDeliveryTier selectTier({
    required int? width,
    required int? height,
  }) {
    final w = width ?? 0;
    final h = height ?? 0;
    final shortSide = w > 0 && h > 0 ? (w < h ? w : h) : 720;
    if (shortSide <= 360) return VideoDeliveryTier.tier360;
    if (shortSide <= 480) return VideoDeliveryTier.tier480;
    return VideoDeliveryTier.tier720;
  }

  Future<VideoCompressionResult> prepareForUpload(
    XFile source, {
    required String projectId,
    required String assetId,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);
    throw const VideoCompressionException(
      'Device video compression is required for creation publishing and is unavailable on web. Use the OJAS Android or iOS app to publish this video.',
    );
  }

  // Retained for existing chat/video callers. Creation publishing uses the
  // stricter prepareForUpload API above and never silently uploads raw web media.
  Future<VideoCompressionResult> compress(XFile source) async {
    final bytes = await source.length();
    return VideoCompressionResult(
      file: source,
      originalBytes: bytes,
      compressedBytes: bytes,
      profile: VideoDeliveryTier.tier720,
      compressionApplied: false,
    );
  }
}

class VideoCompressionException implements Exception {
  const VideoCompressionException(this.message);

  final String message;

  @override
  String toString() => message;
}
