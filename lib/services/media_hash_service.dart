import 'dart:io';

import 'package:crypto/crypto.dart';

class MediaHashService {
  MediaHashService._();

  static final MediaHashService instance = MediaHashService._();

  /// Computes SHA-256 incrementally so large media files are not loaded
  /// completely into memory on low-end devices.
  Future<String> sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  String normalize(String hash) => hash.trim().toLowerCase();
}
