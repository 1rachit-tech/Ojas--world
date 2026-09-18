import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class CreationAzureUploadResult {
  const CreationAzureUploadResult({
    required this.mediaUrl,
    required this.storagePath,
    required this.bytesUploaded,
  });

  final String mediaUrl;
  final String storagePath;
  final int bytesUploaded;
}

class CreationAzureMediaService {
  CreationAzureMediaService({
    FirebaseAuth? auth,
    http.Client? client,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _client;

  static const int chunkSize = 8 * 1024 * 1024;
  static const int maxVideoBytes = 512 * 1024 * 1024;
  static const int maxAudioBytes = 10 * 1024 * 1024;

  String get brokerUrl => const String.fromEnvironment(
        'OJAS_AZURE_MEDIA_BROKER_URL',
      ).trim().replaceFirst(RegExp(r'/$'), '');

  bool get isConfigured => brokerUrl.isNotEmpty;

  Future<CreationAzureUploadResult?> uploadVideo({
    required String projectId,
    required String assetId,
    required String localPath,
    required String contentType,
    bool deferProcessing = false,
    int resumeBytes = 0,
    String? resumeStoragePath,
    void Function(int uploaded, int total)? onProgress,
    FutureOr<void> Function(int uploaded, int total, String storagePath)? onCheckpoint,
  }) async {
    if (!isConfigured) return null;

    final user = _auth.currentUser;
    if (user == null) throw const CreationAzureMediaException('Authentication required.');

    final file = File(localPath);
    if (!await file.exists()) throw const CreationAzureMediaException('Selected video is no longer available.');
    final totalBytes = await file.length();
    if (totalBytes <= 0 || totalBytes > maxVideoBytes) {
      throw const CreationAzureMediaException('Video is empty or larger than the 512 MB creation limit.');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const CreationAzureMediaException('Unable to refresh authentication token.');
    }

    final targetResponse = await _client.post(
      Uri.parse('$brokerUrl/media/creation-upload-target'),
      headers: <String, String>{
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'projectId': projectId,
        'assetId': assetId,
        'blobName': '$assetId.mp4',
        'contentLength': totalBytes,
        'contentType': contentType,
      }),
    );
    if (targetResponse.statusCode != 200) {
      throw CreationAzureMediaException(_readError(targetResponse.body));
    }

    final target = jsonDecode(targetResponse.body);
    if (target is! Map) {
      throw const CreationAzureMediaException('Media broker returned an invalid upload target.');
    }
    final uploadUrl = target['uploadUrl'] as String?;
    final downloadUrl = target['downloadUrl'] as String?;
    final storagePath = target['storagePath'] as String?;
    final maxBytes = (target['maxBytes'] as num?)?.toInt() ?? maxVideoBytes;
    if (uploadUrl == null || downloadUrl == null || storagePath == null) {
      throw const CreationAzureMediaException('Media broker returned incomplete upload metadata.');
    }
    if (totalBytes > maxBytes) {
      throw const CreationAzureMediaException('Video exceeds the server upload limit.');
    }

    var uploaded = _validResumeBytes(
      resumeBytes: resumeBytes,
      totalBytes: totalBytes,
      resumeStoragePath: resumeStoragePath,
      currentStoragePath: storagePath,
    );
    if (uploaded != resumeBytes) {
      final checkpoint = onCheckpoint;
      if (checkpoint != null) await checkpoint(uploaded, totalBytes, storagePath);
    }

    final blockIds = <String>[];
    final completedBlockCount = uploaded == 0 ? 0 : (uploaded + chunkSize - 1) ~/ chunkSize;
    for (var i = 0; i < completedBlockCount; i++) {
      blockIds.add(_blockIdForIndex(i));
    }

    final randomAccessFile = await file.open(mode: FileMode.read);
    try {
      var blockIndex = completedBlockCount;
      while (uploaded < totalBytes) {
        final remaining = totalBytes - uploaded;
        final readLength = remaining < chunkSize ? remaining : chunkSize;
        await randomAccessFile.setPosition(uploaded);
        final bytes = await randomAccessFile.read(readLength);
        if (bytes.isEmpty) {
          throw const CreationAzureMediaException('Video read stopped before upload completed.');
        }

        final blockId = _blockIdForIndex(blockIndex);
        final blockUrl = '$uploadUrl&comp=block&blockid=${Uri.encodeQueryComponent(blockId)}';
        var uploadedBlock = false;
        Object? lastError;
        for (var attempt = 1; attempt <= 3; attempt++) {
          try {
            final response = await _client.put(
              Uri.parse(blockUrl),
              headers: <String, String>{
                'Content-Type': contentType,
                'Content-Length': bytes.length.toString(),
                'x-ms-version': '2023-11-03',
              },
              body: bytes,
            );
            if (response.statusCode == 201 || response.statusCode == 200) {
              uploadedBlock = true;
              break;
            }
            lastError = response.statusCode == 408 ||
                    response.statusCode == 429 ||
                    response.statusCode >= 500
                ? StateError('Transient Azure upload response ${response.statusCode}')
                : StateError(_readError(response.body));
            if (response.statusCode != 408 && response.statusCode != 429 && response.statusCode < 500) {
              break;
            }
          } catch (error) {
            lastError = error;
          }
          await Future<void>.delayed(Duration(milliseconds: 750 * (1 << (attempt - 1))));
        }
        if (!uploadedBlock) {
          throw CreationAzureMediaException(
            'Unable to upload video chunk ${blockIndex + 1}. ${lastError ?? ''}'.trim(),
          );
        }

        blockIds.add(blockId);
        uploaded += bytes.length;
        onProgress?.call(uploaded, totalBytes);
        final checkpoint = onCheckpoint;
        if (checkpoint != null) await checkpoint(uploaded, totalBytes, storagePath);
        blockIndex++;
      }
    } finally {
      await randomAccessFile.close();
    }

    if (uploaded != totalBytes) {
      throw const CreationAzureMediaException('Video upload ended before all bytes were transferred.');
    }

    final blockXml = StringBuffer('<BlockList>');
    for (final blockId in blockIds) {
      blockXml.write('<Latest>$blockId</Latest>');
    }
    blockXml.write('</BlockList>');
    final commitResponse = await _client.put(
      Uri.parse('$uploadUrl&comp=blocklist'),
      headers: const <String, String>{
        'Content-Type': 'application/xml',
        'x-ms-version': '2023-11-03',
      },
      body: blockXml.toString(),
    );
    if (commitResponse.statusCode != 201 && commitResponse.statusCode != 200) {
      if (resumeBytes > 0) {
        final checkpoint = onCheckpoint;
        if (checkpoint != null) await checkpoint(0, totalBytes, storagePath);
      }
      throw CreationAzureMediaException(_readError(commitResponse.body));
    }

    final finalizeResponse = await _client.post(
      Uri.parse('$brokerUrl/media/creation-upload-complete'),
      headers: <String, String>{
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'projectId': projectId,
        'assetId': assetId,
        'storagePath': storagePath,
        'contentLength': totalBytes,
        'contentType': contentType,
        'deferProcessing': deferProcessing,
      }),
    );
    if (finalizeResponse.statusCode != 200) {
      throw CreationAzureMediaException(_readError(finalizeResponse.body));
    }

    final finalized = jsonDecode(finalizeResponse.body);
    final finalizedUrl = finalized is Map ? finalized['downloadUrl'] as String? ?? downloadUrl : downloadUrl;
    onProgress?.call(totalBytes, totalBytes);
    return CreationAzureUploadResult(
      mediaUrl: finalizedUrl,
      storagePath: storagePath,
      bytesUploaded: totalBytes,
    );
  }

  int _validResumeBytes({
    required int resumeBytes,
    required int totalBytes,
    required String? resumeStoragePath,
    required String currentStoragePath,
  }) {
    if (resumeStoragePath == null || resumeStoragePath != currentStoragePath) return 0;
    if (resumeBytes <= 0 || resumeBytes > totalBytes) return 0;
    if (resumeBytes != totalBytes && resumeBytes % chunkSize != 0) return 0;
    return resumeBytes;
  }

  String _blockIdForIndex(int index) => base64.encode(
        utf8.encode('ojas-${index.toString().padLeft(8, '0')}'),
      );

  Future<CreationAzureUploadResult?> uploadAudio({
    required String projectId,
    required String layerId,
    required String localPath,
    required String blobName,
    required String contentType,
  }) async {
    if (!isConfigured) return null;
    final user = _auth.currentUser;
    if (user == null) throw const CreationAzureMediaException('Authentication required.');

    final file = File(localPath);
    if (!await file.exists()) throw const CreationAzureMediaException('Selected audio is no longer available.');
    final totalBytes = await file.length();
    if (totalBytes <= 0 || totalBytes > maxAudioBytes) throw const CreationAzureMediaException('Audio is empty or larger than the 10 MB creation limit.');
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) throw const CreationAzureMediaException('Unable to refresh authentication token.');

    final targetResponse = await _client.post(
      Uri.parse('$brokerUrl/media/creation-audio-upload-target'),
      headers: <String, String>{'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{'projectId': projectId, 'layerId': layerId, 'blobName': blobName, 'contentLength': totalBytes, 'contentType': contentType}),
    );
    if (targetResponse.statusCode != 200) throw CreationAzureMediaException(_readError(targetResponse.body));
    final target = jsonDecode(targetResponse.body);
    if (target is! Map) throw const CreationAzureMediaException('Media broker returned an invalid audio upload target.');
    final uploadUrl = target['uploadUrl'] as String?;
    final downloadUrl = target['downloadUrl'] as String?;
    final storagePath = target['storagePath'] as String?;
    if (uploadUrl == null || downloadUrl == null || storagePath == null) throw const CreationAzureMediaException('Media broker returned incomplete audio metadata.');

    final bytes = await file.readAsBytes();
    final uploadResponse = await _client.put(
      Uri.parse(uploadUrl),
      headers: <String, String>{'Content-Type': contentType, 'Content-Length': bytes.length.toString(), 'x-ms-blob-type': 'BlockBlob', 'x-ms-version': '2023-11-03'},
      body: bytes,
    );
    if (uploadResponse.statusCode != 201 && uploadResponse.statusCode != 200) throw CreationAzureMediaException(_readError(uploadResponse.body));

    final finalizeResponse = await _client.post(
      Uri.parse('$brokerUrl/media/creation-audio-upload-complete'),
      headers: <String, String>{'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{'projectId': projectId, 'layerId': layerId, 'storagePath': storagePath, 'contentLength': totalBytes, 'contentType': contentType}),
    );
    if (finalizeResponse.statusCode != 200) throw CreationAzureMediaException(_readError(finalizeResponse.body));
    final finalized = jsonDecode(finalizeResponse.body);
    final finalizedUrl = finalized is Map ? finalized['downloadUrl'] as String? ?? downloadUrl : downloadUrl;
    return CreationAzureUploadResult(mediaUrl: finalizedUrl, storagePath: storagePath, bytesUploaded: totalBytes);
  }

  String _readError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) return decoded['error'] as String;
    } catch (_) {}
    return 'Media service request failed.';
  }

  void dispose() => _client.close();
}

class CreationAzureMediaException implements Exception {
  const CreationAzureMediaException(this.message);
  final String message;
  @override
  String toString() => message;
}
