import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

class VideoCompressionResult {
  const VideoCompressionResult({
    required this.file,
    required this.originalBytes,
    required this.compressedBytes,
    this.width,
    this.height,
    this.durationMs,
  });

  final XFile file;
  final int originalBytes;
  final int compressedBytes;
  final int? width;
  final int? height;
  final int? durationMs;

  bool get savedBytes => compressedBytes < originalBytes;
}

class VideoCompressionService {
  VideoCompressionService._();

  static final VideoCompressionService instance =
      VideoCompressionService._();

  Future<VideoCompressionResult> compress(XFile source) async {
    final original = File(source.path);
    final originalBytes = await original.length();

    final info = await VideoCompress.getMediaInfo(source.path);
    final compressed = await VideoCompress.compressVideo(
      source.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
      frameRate: 30,
    );

    final output = compressed?.file;
    if (output == null || !await output.exists()) {
      throw const VideoCompressionException(
        'Video compression failed. Please try another video.',
      );
    }

    final outputBytes = await output.length();

    // Never make the media larger simply because compression was requested.
    final selected = outputBytes < originalBytes ? output : original;
    final selectedBytes = outputBytes < originalBytes
        ? outputBytes
        : originalBytes;

    return VideoCompressionResult(
      file: XFile(selected.path),
      originalBytes: originalBytes,
      compressedBytes: selectedBytes,
      width: info?.width,
      height: info?.height,
      durationMs: info?.duration?.round(),
    );
  }
}

class VideoCompressionException implements Exception {
  const VideoCompressionException(this.message);

  final String message;

  @override
  String toString() => message;
}
