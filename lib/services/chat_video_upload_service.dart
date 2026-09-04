import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_compress/flutter_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'azure_blob_media_upload_service.dart';
import 'media_deduplication_service.dart';
import 'media_hash_service.dart';

class ChatVideoUploadResult {
  const ChatVideoUploadResult({
    required this.mediaUrl,
    required this.mediaHash,
    required this.storagePath,
    required this.bytes,
  });

  final String mediaUrl;
  final String mediaHash;
  final String storagePath;
  final int bytes;
}

/// Handles chat-video preparation without AI/ML processing.
///
/// Pipeline:
/// pick -> hardware/native compression -> SHA-256 -> dedup lookup ->
/// trusted Azure upload (when configured) or Firebase Storage fallback.
class ChatVideoUploadService {
  ChatVideoUploadService._();

  static final ChatVideoUploadService instance =
      ChatVideoUploadService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  static const String _azureBrokerUrl = String.fromEnvironment(
    'OJAS_AZURE_MEDIA_BROKER_URL',
    defaultValue: '',
  );

  static const int maxSourceBytes = 150 * 1024 * 1024;
  static const int targetSizeMb = 12;
  static const int maxUploadBytes = 25 * 1024 * 1024;

  bool get isAzureUploadEnabled => _azureBrokerUrl.trim().isNotEmpty;

  Future<XFile?> pickVideo() {
    return _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
  }

  Future<ChatVideoUploadResult> prepareAndUpload({
    required XFile sourceFile,
    required String conversationId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ChatVideoUploadException('Please sign in again.');
    }

    final source = File(sourceFile.path);
    if (!await source.exists()) {
      throw const ChatVideoUploadException(
        'Selected video could not be found.',
      );
    }

    final sourceBytes = await source.length();
    if (sourceBytes <= 0) {
      throw const ChatVideoUploadException('Selected video is empty.');
    }
    if (sourceBytes > maxSourceBytes) {
      throw const ChatVideoUploadException(
        'Please choose a video smaller than 150 MB.',
      );
    }

    final compressed = await _compress(source);

    try {
      final compressedBytes = await compressed.length();
      if (compressedBytes <= 0) {
        throw const ChatVideoUploadException(
          'Video compression produced an empty file.',
        );
      }
      if (compressedBytes > maxUploadBytes) {
        throw const ChatVideoUploadException(
          'This video is still too large after compression. Try a shorter clip.',
        );
      }

      // Hash the exact bytes that would be uploaded. Existing matching assets
      // therefore skip both upload and duplicate CDN storage.
      final mediaHash = MediaHashService.instance.normalize(
        await MediaHashService.instance.sha256File(compressed),
      );

      final existingUrl = await MediaDeduplicationService(
        firestore: _firestore,
      ).findExistingMedia(
        mediaHash: mediaHash,
        mediaType: 'video',
      );

      if (existingUrl != null) {
        return ChatVideoUploadResult(
          mediaUrl: existingUrl,
          mediaHash: mediaHash,
          storagePath: '',
          bytes: compressedBytes,
        );
      }

      final videoId = _uuid.v4();

      if (isAzureUploadEnabled) {
        return _uploadToAzure(
          compressed: compressed,
          mediaHash: mediaHash,
          conversationId: conversationId,
          videoId: videoId,
          bytes: compressedBytes,
        );
      }

      return _uploadToFirebase(
        compressed: compressed,
        mediaHash: mediaHash,
        uid: uid,
        conversationId: conversationId,
        videoId: videoId,
        bytes: compressedBytes,
      );
    } finally {
      if (await compressed.exists()) {
        try {
          await compressed.delete();
        } catch (_) {}
      }
    }
  }

  Future<File> _compress(File source) async {
    final tempDirectory = await getTemporaryDirectory();
    final outputName = 'ojas_chat_${_uuid.v4()}';

    final result = await FlutterCompress.instance.compress(
      source.path,
      const VideoCompressConfig(
        targetSizeMB: targetSizeMb,
        codec: VideoCodec.h264,
        maxWidth: 1280,
        maxHeight: 1280,
        frameRate: 30,
        keepOriginalIfLarger: true,
        minSavingsPercent: 5,
        container: VideoContainer.mp4,
      ),
      outputDirectory: tempDirectory.path,
      outputName: outputName,
    );

    final file = File(result.outputPath);
    if (!await file.exists()) {
      throw const ChatVideoUploadException(
        'Video compression failed. Please try again.',
      );
    }

    return file;
  }

  Future<ChatVideoUploadResult> _uploadToAzure({
    required File compressed,
    required String mediaHash,
    required String conversationId,
    required String videoId,
    required int bytes,
  }) async {
    try {
      final uploader = AzureBlobMediaUploadService(
        brokerUrl: _azureBrokerUrl,
        auth: _auth,
      );

      final target = await uploader.requestUploadTarget(
        conversationId: conversationId,
        blobName: '$videoId.mp4',
        contentLength: bytes,
        contentType: 'video/mp4',
      );

      final Uint8List data = await compressed.readAsBytes();

      await uploader.uploadBytes(
        target: target,
        bytes: data,
        contentType: 'video/mp4',
      );

      return ChatVideoUploadResult(
        mediaUrl: target.downloadUrl,
        mediaHash: mediaHash,
        storagePath: target.storagePath,
        bytes: bytes,
      );
    } on AzureMediaUploadException catch (error) {
      throw ChatVideoUploadException(error.message);
    } catch (_) {
      throw const ChatVideoUploadException(
        'Video upload failed. Please try again.',
      );
    }
  }

  Future<ChatVideoUploadResult> _uploadToFirebase({
    required File compressed,
    required String mediaHash,
    required String uid,
    required String conversationId,
    required String videoId,
    required int bytes,
  }) async {
    final storagePath =
        'chat_media/$conversationId/videos/$videoId.mp4';

    final reference = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: 'video/mp4',
      cacheControl: 'public,max-age=2592000',
      customMetadata: {
        'conversationId': conversationId,
        'uploadedBy': uid,
        'mediaHash': mediaHash,
      },
    );

    final snapshot = await reference.putFile(
      compressed,
      metadata,
    );

    final downloadUrl = await snapshot.ref.getDownloadURL();

    return ChatVideoUploadResult(
      mediaUrl: downloadUrl,
      mediaHash: mediaHash,
      storagePath: storagePath,
      bytes: bytes,
    );
  }

  Future<void> sendVideoMessage({
    required String conversationId,
    required String receiverId,
    required ChatVideoUploadResult media,
    String? caption,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ChatVideoUploadException('Please sign in again.');
    }
    if (receiverId.trim().isEmpty || media.mediaUrl.trim().isEmpty) {
      throw const ChatVideoUploadException('Invalid video message.');
    }

    final cleanCaption = caption?.trim() ?? '';
    final messageReference = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();
    final conversationReference =
        _firestore.collection('conversations').doc(conversationId);

    final batch = _firestore.batch();

    // text is intentionally always present, even without a caption.
    batch.set(messageReference, {
      'conversationId': conversationId,
      'senderId': uid,
      'type': 'video',
      'text': cleanCaption,
      'mediaUrl': media.mediaUrl,
      'mediaHash': media.mediaHash,
      if (media.storagePath.isNotEmpty)
        'mediaStoragePath': media.storagePath,
      'status': 'sent',
      'isDeleted': false,
      'reactions': <String, String>{},
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      conversationReference,
      {
        'lastMessage': cleanCaption.isEmpty ? 'Video' : cleanCaption,
        'lastMessageSenderId': uid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts.$uid': 0,
        'lastReadAtBy.$uid': FieldValue.serverTimestamp(),
        'typingBy.$uid': false,
        'unreadCounts.$receiverId': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}

class ChatVideoUploadException implements Exception {
  const ChatVideoUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
