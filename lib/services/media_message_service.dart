import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'azure_blob_media_upload_service.dart';

class MediaMessageResult {
  const MediaMessageResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.width,
    required this.height,
    required this.originalBytes,
    required this.compressedBytes,
  });

  final String downloadUrl;
  final String storagePath;
  final int width;
  final int height;
  final int originalBytes;
  final int compressedBytes;
}

class MediaMessageService {
  MediaMessageService._();

  static final MediaMessageService instance = MediaMessageService._();

  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  /// Optional trusted endpoint that verifies the signed-in user and returns
  /// a short-lived Azure Blob upload URL. Leave empty during migration to keep
  /// the existing provider active and avoid breaking current app builds.
  static const String _azureBrokerUrl = String.fromEnvironment(
    'OJAS_AZURE_MEDIA_BROKER_URL',
    defaultValue: '',
  );

  bool get isAzureUploadEnabled => _azureBrokerUrl.trim().isNotEmpty;

  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxWidth = 1440;
  static const int maxHeight = 1440;
  static const int imageQuality = 82;

  Future<XFile?> pickImageFromGallery() {
    return _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
      requestFullMetadata: false,
    );
  }

  Future<XFile?> pickImageFromCamera() {
    return _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
      requestFullMetadata: false,
    );
  }

  Future<MediaMessageResult> uploadChatImage({
    required String conversationId,
    required XFile sourceFile,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const MediaMessageException('Please sign in again.');
    }

    final source = File(sourceFile.path);
    if (!await source.exists()) {
      throw const MediaMessageException(
        'Selected image could not be found.',
      );
    }

    final originalBytes = await source.length();
    if (originalBytes <= 0) {
      throw const MediaMessageException('Selected image is empty.');
    }

    if (originalBytes > maxImageBytes) {
      throw const MediaMessageException(
        'Please select an image smaller than 10 MB.',
      );
    }

    final compressedFile = await _compressImage(source);

    try {
      final compressedBytes = await compressedFile.length();
      final dimensions = await _readImageDimensions(compressedFile);
      final imageId = _uuid.v4();
      final legacyStoragePath =
          'chat_media/$conversationId/images/$imageId.jpg';

      if (isAzureUploadEnabled) {
        return _uploadToAzure(
          conversationId: conversationId,
          compressedFile: compressedFile,
          imageId: imageId,
          dimensions: dimensions,
          originalBytes: originalBytes,
          compressedBytes: compressedBytes,
        );
      }

      return _uploadToCurrentProvider(
        compressedFile: compressedFile,
        uid: uid,
        conversationId: conversationId,
        storagePath: legacyStoragePath,
        dimensions: dimensions,
        originalBytes: originalBytes,
        compressedBytes: compressedBytes,
      );
    } finally {
      if (await compressedFile.exists()) {
        try {
          await compressedFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<MediaMessageResult> _uploadToAzure({
    required String conversationId,
    required File compressedFile,
    required String imageId,
    required _ImageDimensions dimensions,
    required int originalBytes,
    required int compressedBytes,
  }) async {
    try {
      final uploader = AzureBlobMediaUploadService(
        brokerUrl: _azureBrokerUrl,
        auth: _auth,
      );

      final target = await uploader.requestUploadTarget(
        conversationId: conversationId,
        blobName: '$imageId.jpg',
        contentLength: compressedBytes,
        contentType: 'image/jpeg',
      );

      final bytes = await compressedFile.readAsBytes();

      await uploader.uploadBytes(
        target: target,
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      return MediaMessageResult(
        downloadUrl: target.downloadUrl,
        storagePath: target.storagePath,
        width: dimensions.width,
        height: dimensions.height,
        originalBytes: originalBytes,
        compressedBytes: compressedBytes,
      );
    } on AzureMediaUploadException catch (error) {
      throw MediaMessageException(error.message);
    } catch (_) {
      throw const MediaMessageException(
        'Image upload failed. Please try again.',
      );
    }
  }

  Future<MediaMessageResult> _uploadToCurrentProvider({
    required File compressedFile,
    required String uid,
    required String conversationId,
    required String storagePath,
    required _ImageDimensions dimensions,
    required int originalBytes,
    required int compressedBytes,
  }) async {
    throw const MediaMessageException(
      'Media storage is being initialized. Please try again shortly.',
    );
  }

  Future<File> _compressImage(File source) async {
    final tempDirectory = await getTemporaryDirectory();
    final targetPath = '${tempDirectory.path}/${_uuid.v4()}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      source.path,
      targetPath,
      format: CompressFormat.jpeg,
      quality: imageQuality,
      minWidth: maxWidth,
      minHeight: maxHeight,
      keepExif: false,
      autoCorrectionAngle: true,
    );

    if (result == null) {
      throw const MediaMessageException('Image compression failed.');
    }

    return File(result.path);
  }

  Future<_ImageDimensions> _readImageDimensions(File file) async {
    final bytes = await file.readAsBytes();
    final image = await decodeImageFromList(bytes);

    return _ImageDimensions(
      width: image.width,
      height: image.height,
    );
  }
}

class _ImageDimensions {
  const _ImageDimensions({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
}

class MediaMessageException implements Exception {
  const MediaMessageException(this.message);

  final String message;

  @override
  String toString() => message;
}
