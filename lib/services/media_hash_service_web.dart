import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class MediaHashService {
  MediaHashService._();

  static final MediaHashService instance = MediaHashService._();

  String sha256Bytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  String normalize(String hash) => hash.trim().toLowerCase();
}
