import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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

  static final MediaMessageService instance =
      MediaMessageService._();

  final ImagePicker _imagePicker =
      ImagePicker();

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final Uuid _uuid =
      const Uuid();

  static const int maxImageBytes =
      10 * 1024 * 1024;

  static const int maxWidth = 1440;

  static const int maxHeight = 1440;

  static const int imageQuality = 82;

  Future<XFile?> pickImageFromGallery() async {
    return _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
      requestFullMetadata: false,
    );
  }

  Future<XFile?> pickImageFromCamera() async {
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
    final uid =
        _auth.currentUser?.uid;

    if (uid == null) {
      throw const MediaMessageException(
        'Please sign in again.',
      );
    }

    final source =
        File(sourceFile.path);

    if (!await source.exists()) {
      throw const MediaMessageException(
        'Selected image could not be found.',
      );
    }

    final originalBytes =
        await source.length();

    if (originalBytes <= 0) {
      throw const MediaMessageException(
        'Selected image is empty.',
      );
    }

    if (originalBytes > maxImageBytes) {
      throw const MediaMessageException(
        'Please select an image smaller than 10 MB.',
      );
    }

    final compressedFile =
        await _compressImage(source);

    try {
      final compressedBytes =
          await compressedFile.length();

      final imageId =
          _uuid.v4();

      final storagePath =
          'chat_media/$conversationId/images/$imageId.jpg';

      final reference =
          _storage.ref().child(storagePath);

      final metadata =
          SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl:
            'public,max-age=2592000',
        customMetadata: {
          'conversationId':
              conversationId,
          'uploadedBy': uid,
          'originalBytes':
              originalBytes.toString(),
          'compressedBytes':
              compressedBytes.toString(),
        },
      );

      final uploadTask =
          reference.putFile(
        compressedFile,
        metadata,
      );

      final snapshot =
          await uploadTask;

      final downloadUrl =
          await snapshot.ref.getDownloadURL();

      final dimensions =
          await _readImageDimensions(
        compressedFile,
      );

      return MediaMessageResult(
        downloadUrl: downloadUrl,
        storagePath: storagePath,
        width: dimensions.width,
        height: dimensions.height,
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

  Future<File> _compressImage(
    File source,
  ) async {
    final tempDirectory =
        await getTemporaryDirectory();

    final targetPath =
        '${tempDirectory.path}/${_uuid.v4()}.jpg';

    final result =
        await FlutterImageCompress
            .compressAndGetFile(
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
      throw const MediaMessageException(
        'Image compression failed.',
      );
    }

    return File(result.path);
  }

  Future<_ImageDimensions>
      _readImageDimensions(
    File file,
  ) async {
    final bytes =
        await file.readAsBytes();

    final image =
        await decodeImageFromList(bytes);

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

class MediaMessageException
    implements Exception {
  const MediaMessageException(
    this.message,
  );

  final String message;

  @override
  String toString() => message;
}
