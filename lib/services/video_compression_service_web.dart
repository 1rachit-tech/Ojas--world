import 'package:image_picker/image_picker.dart';

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
    final bytes = await source.length();

    return VideoCompressionResult(
      file: source,
      originalBytes: bytes,
      compressedBytes: bytes,
    );
  }
}
