import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'azure_blob_media_upload_service.dart';
import 'media_deduplication_service.dart';
import 'media_hash_service.dart';
import 'video_compression_service.dart';

class ChatVideoMediaResult {
  const ChatVideoMediaResult({
    required this.mediaUrl,
    required this.mediaHash,
    required this.storagePath,
    required this.mediaBytes,
    this.width,
    this.height,
    this.durationMs,
    required this.deduplicated,
  });

  final String mediaUrl;
  final String mediaHash;
  final String storagePath;
  final int mediaBytes;
  final int? width;
  final int? height;
  final int? durationMs;
  final bool deduplicated;
}

class ChatVideoMediaService {
  ChatVideoMediaService._();

  static final ChatVideoMediaService instance =
      ChatVideoMediaService._();

  static const int maxUploadBytes = 50 * 1024 * 1024;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();
  final MediaHashService _hashService = MediaHashService.instance;
  final MediaDeduplicationService _deduplicationService =
      MediaDeduplicationService();

  static const String _azureBrokerUrl = String.fromEnvironment(
    'OJAS_AZURE_MEDIA_BROKER_URL',
    defaultValue: '',
  );

  bool get isAzureUploadEnabled => _azureBrokerUrl.trim().isNotEmpty;

  Future<ChatVideoMediaResult> prepareAndUpload({
    required XFile sourceFile,
    required String conversationId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ChatVideoMediaException('Please sign in again.');
    }

    final compressed =
        await VideoCompressionService.instance.compress(sourceFile);
    final compressedBytes = compressed.compressedBytes;

    if (compressedBytes <= 0 || compressedBytes > maxUploadBytes) {
      throw const ChatVideoMediaException(
        'Video is too large. Please choose a video under 50 MB.',
      );
    }

    final bytes = await compressed.file.readAsBytes();
    final hash = _hashService.normalize(
      _hashService.sha256Bytes(Uint8List.fromList(bytes)),
    );

    final existingUrl =
        await _deduplicationService.findExistingMedia(
      mediaHash: hash,
      mediaType: 'video',
    );

    if (existingUrl != null) {
      return ChatVideoMediaResult(
        mediaUrl: existingUrl,
        mediaHash: hash,
        storagePath: '',
        mediaBytes: compressedBytes,
        width: compressed.width,
        height: compressed.height,
        durationMs: compressed.durationMs,
        deduplicated: true,
      );
    }

    final fileName = '${_uuid.v4()}.mp4';

    if (isAzureUploadEnabled) {
      final target = await _uploadToAzure(
        conversationId: conversationId,
        fileName: fileName,
        bytes: bytes,
        contentLength: bytes.length,
      );

      return ChatVideoMediaResult(
        mediaUrl: target.downloadUrl,
        mediaHash: hash,
        storagePath: target.storagePath,
        mediaBytes: bytes.length,
        width: compressed.width,
        height: compressed.height,
        durationMs: compressed.durationMs,
        deduplicated: false,
      );
    }

    final storagePath =
        'chat_media/${user.uid}/$conversationId/videos/$fileName';
    final reference = _storage.ref().child(storagePath);

    final snapshot = await reference.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(
        contentType: 'video/mp4',
        cacheControl: 'public,max-age=2592000',
        customMetadata: {
          'conversationId': conversationId,
          'uploadedBy': user.uid,
          'mediaHash': hash,
        },
      ),
    );

    final downloadUrl = await snapshot.ref.getDownloadURL();

    return ChatVideoMediaResult(
      mediaUrl: downloadUrl,
      mediaHash: hash,
      storagePath: storagePath,
      mediaBytes: bytes.length,
      width: compressed.width,
      height: compressed.height,
      durationMs: compressed.durationMs,
      deduplicated: false,
    );
  }

  Future<AzureBlobUploadTarget> _uploadToAzure({
    required String conversationId,
    required String fileName,
    required List<int> bytes,
    required int contentLength,
  }) async {
    try {
      final uploader = AzureBlobMediaUploadService(
        brokerUrl: _azureBrokerUrl,
        auth: _auth,
      );

      final target = await uploader.requestUploadTarget(
        conversationId: conversationId,
        blobName: fileName,
        contentLength: contentLength,
        contentType: 'video/mp4',
      );

      await uploader.uploadBytes(
        target: target,
        bytes: Uint8List.fromList(bytes),
        contentType: 'video/mp4',
      );

      return target;
    } on AzureMediaUploadException catch (error) {
      throw ChatVideoMediaException(error.message);
    } catch (_) {
      throw const ChatVideoMediaException(
        'Video upload failed. Please try again.',
      );
    }
  }
}

class ChatVideoMediaException implements Exception {
  const ChatVideoMediaException(this.message);

  final String message;

  @override
  String toString() => message;
}
