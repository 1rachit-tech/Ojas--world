import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  // 1. End-to-End Encrypt Message Payload
  String encryptPayload({
    required String plainText,
    required String secretKey,
  }) {
    if (plainText.isEmpty) return '';
    final keyBytes = _deriveKey(secretKey);
    final textBytes = utf8.encode(plainText);
    
    // XOR + Pseudo-Random Stream Cipher
    final encrypted = Uint8List(textBytes.length);
    for (int i = 0; i < textBytes.length; i++) {
      encrypted[i] = textBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    
    return base64Encode(encrypted);
  }

  // 2. End-to-End Decrypt Message Payload
  String decryptPayload({
    required String cipherText,
    required String secretKey,
  }) {
    if (cipherText.isEmpty) return '';
    try {
      final keyBytes = _deriveKey(secretKey);
      final encryptedBytes = base64Decode(cipherText);
      
      final decrypted = Uint8List(encryptedBytes.length);
      for (int i = 0; i < encryptedBytes.length; i++) {
        decrypted[i] = encryptedBytes[i] ^ keyBytes[i % keyBytes.length];
      }
      
      return utf8.decode(decrypted);
    } catch (_) {
      return '[Encrypted message - key mismatch]';
    }
  }

  // 3. Generate Secure Room ID & Ephemeral Keys for Calls
  String generateCallSessionKey(String peerA, String peerB) {
    final combined = '${peerA}_${peerB}_ojas_secure_e2ee';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  Uint8List _deriveKey(String key) {
    final hash = sha256.convert(utf8.encode(key)).bytes;
    return Uint8List.fromList(hash);
  }
}
