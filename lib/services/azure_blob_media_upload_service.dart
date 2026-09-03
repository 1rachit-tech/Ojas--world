import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AzureBlobUploadTarget {
  const AzureBlobUploadTarget({
    required this.uploadUrl,
    required this.downloadUrl,
    required this.storagePath,
    this.headers = const {},
  });

  final Uri uploadUrl;
  final String downloadUrl;
  final String storagePath;
  final Map<String, String> headers;
}

/// Secure Azure Blob uploader.
///
/// The mobile app never receives the Azure account key or connection string.
/// A trusted backend must verify the Firebase user and return a short-lived,
/// single-blob upload URL (normally a SAS URL).
class AzureBlobMediaUploadService {
  AzureBlobMediaUploadService({
    required String brokerUrl,
    FirebaseAuth? auth,
    http.Client? client,
  })  : _brokerUrl = Uri.parse(brokerUrl),
        _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  final Uri _brokerUrl;
  final FirebaseAuth _auth;
  final http.Client _client;

  Future<AzureBlobUploadTarget> requestUploadTarget({
    required String conversationId,
    required String blobName,
    required int contentLength,
    required String contentType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AzureMediaUploadException('Please sign in again.');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AzureMediaUploadException(
        'Could not verify your sign-in. Please try again.',
      );
    }

    final response = await _client
        .post(
          _brokerUrl,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'conversationId': conversationId,
            'blobName': blobName,
            'contentLength': contentLength,
            'contentType': contentType,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const AzureMediaUploadException(
        'Media upload authorization failed. Please try again.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AzureMediaUploadException(
        'Invalid media upload authorization response.',
      );
    }

    final uploadUrl = decoded['uploadUrl'];
    final downloadUrl = decoded['downloadUrl'];
    final storagePath = decoded['storagePath'];

    if (uploadUrl is! String ||
        downloadUrl is! String ||
        storagePath is! String ||
        uploadUrl.isEmpty ||
        downloadUrl.isEmpty ||
        storagePath.isEmpty) {
      throw const AzureMediaUploadException(
        'Incomplete media upload authorization response.',
      );
    }

    final headers = <String, String>{};
    final rawHeaders = decoded['headers'];
    if (rawHeaders is Map) {
      rawHeaders.forEach((key, value) {
        if (key is String && value is String) {
          headers[key] = value;
        }
      });
    }

    return AzureBlobUploadTarget(
      uploadUrl: Uri.parse(uploadUrl),
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      headers: headers,
    );
  }

  Future<void> uploadBytes({
    required AzureBlobUploadTarget target,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final headers = <String, String>{
      'x-ms-blob-type': 'BlockBlob',
      'Content-Type': contentType,
      ...target.headers,
    };

    final response = await _client
        .put(
          target.uploadUrl,
          headers: headers,
          body: bytes,
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const AzureMediaUploadException(
        'Media upload failed. Please try again.',
      );
    }
  }
}

class AzureMediaUploadException implements Exception {
  const AzureMediaUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
