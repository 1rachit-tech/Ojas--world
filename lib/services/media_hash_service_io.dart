import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class MediaHashService {
  MediaHashService._();

  static final MediaHashService instance = MediaHashService._();

  Future<String> sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  String sha256Bytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  String normalize(String hash) => hash.trim().toLowerCase();
}
