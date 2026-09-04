import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class MediaHashService {
  MediaHashService._();

  static final MediaHashService instance = MediaHashService._();

  /// Computes SHA-256 incrementally so large mobile media files are not loaded
  /// completely into memory.
  Future<String> sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  /// Computes SHA-256 for picker/blob bytes when dart:io is unavailable,
  /// such as on Flutter Web.
  String sha256Bytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  String normalize(String hash) => hash.trim().toLowerCase();
}
