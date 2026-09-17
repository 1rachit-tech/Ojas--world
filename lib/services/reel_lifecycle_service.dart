import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class ReelLifecycleException implements Exception {
  const ReelLifecycleException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Server-authoritative lifecycle bridge for edit/delete/reuse operations.
///
/// The callable endpoint performs creator checks, reuse-policy checks and
/// server-side moderation/index updates. No direct client write is attempted.
class ReelLifecycleService {
  ReelLifecycleService({
    FirebaseAuth? auth,
    http.Client? client,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _client;

  static const String _region = 'asia-south1';
  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> editPost({
    required String postId,
    String? caption,
    String? visibility,
    bool? allowComments,
    bool recommendationEligible = false,
  }) {
    return _call(
      operation: 'edit',
      postId: postId,
      data: <String, dynamic>{
        if (caption != null) 'caption': caption,
        if (visibility != null) 'visibility': visibility,
        if (allowComments != null) 'allowComments': allowComments,
        'recommendationEligible': recommendationEligible,
      },
    );
  }

  Future<Map<String, dynamic>> deletePost({required String postId}) {
    return _call(operation: 'delete', postId: postId);
  }

  Future<Map<String, dynamic>> requestReuse({required String postId}) {
    return _call(operation: 'reuse', postId: postId);
  }

  Future<Map<String, dynamic>> _call({
    required String operation,
    required String postId,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    if (postId.trim().isEmpty) {
      throw const ReelLifecycleException('Post ID is required.');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw const ReelLifecycleException('Please sign in again.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const ReelLifecycleException('Could not verify your sign-in. Please try again.');
    }

    final projectId = Firebase.app().options.projectId;
    if (projectId.trim().isEmpty) {
      throw const ReelLifecycleException('Firebase project configuration is missing.');
    }

    final uri = Uri.parse(
      'https://$_region-$projectId.cloudfunctions.net/manageReel',
    );
    final response = await _client
        .post(
          uri,
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'operation': operation,
              'postId': postId.trim(),
              ...data,
            },
          }),
        )
        .timeout(_timeout);

    Map<String, dynamic> body = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Fall through to a generic server error below.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      final message = error is Map && error['message'] is String
          ? error['message'] as String
          : 'The post action could not be completed.';
      throw ReelLifecycleException(message);
    }

    final result = body['data'];
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const ReelLifecycleException('The server returned an invalid lifecycle response.');
  }
}
