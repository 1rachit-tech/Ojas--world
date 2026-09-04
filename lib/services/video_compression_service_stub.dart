import 'package:image_picker/image_picker.dart';

import 'video_compression_service.dart';

Future<VideoCompressionResult> compressVideoFile(XFile source) async {
  // Web does not use the mobile native video encoder. Keep the original file
  // so browser chat remains functional; mobile uses the native compressor.
  final bytes = await source.length();

  return VideoCompressionResult(
    file: source,
    originalBytes: bytes,
    compressedBytes: bytes,
  );
}
