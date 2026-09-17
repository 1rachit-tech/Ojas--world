import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class ReelLifecycleService {
  ReelLifecycleService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw const ReelLifecycleException('Please sign in again.');
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) throw const ReelLifecycleException('Authentication token is unavailable.');

    final projectId = Firebase.app().options.projectId;
    const region = 'asia-south1';
    final uri = Uri.parse('https://$region-$projectId.cloudfunctions.net/$functionName');
    final response = await http.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{'data': data}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReelLifecycleException('Server request failed (${response.statusCode}).');
    }

    final body = jsonDecode(response.body);
    if (body is! Map) throw const ReelLifecycleException('Invalid server response.');
    final error = body['error'];
    if (error is Map && error['message'] is String) {
      throw ReelLifecycleException(error['message'] as String);
    }
    final payload = body['data'];
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return const <String, dynamic>{};
  }

  Future<void> editPost({
    required String postId,
    String? caption,
    String? visibility,
    bool? allowComments,
    bool? recommendationEligible,
    String? reusePolicy,
  }) async {
    await _call('manageReel', <String, dynamic>{
      'operation': 'edit',
      'postId': postId,
      if (caption != null) 'caption': caption,
      if (visibility != null) 'visibility': visibility,
      if (allowComments != null) 'allowComments': allowComments,
      if (recommendationEligible != null) 'recommendationEligible': recommendationEligible,
      if (reusePolicy != null) 'reusePolicy': reusePolicy,
    });
  }

  Future<void> replacePublishedMedia({
    required String postId,
    required String mediaAssetId,
    required String videoUrl,
    required String mediaStoragePath,
    required int contentLength,
    required String mediaHash,
    required Map<String, dynamic> editGraph,
    required String caption,
    required String visibility,
    required bool allowComments,
    required bool recommendationEligible,
    required String reusePolicy,
    required bool aiGeneratedDisclosure,
    required bool copyrightConfirmed,
  }) async {
    await _call('manageReel', <String, dynamic>{
      'operation': 'replace-media',
      'postId': postId,
      'mediaProvider': 'azure',
      'mediaAssetId': mediaAssetId,
      'videoUrl': videoUrl,
      'mediaStoragePath': mediaStoragePath,
      'contentLength': contentLength,
      'mediaHash': mediaHash,
      'editGraph': editGraph,
      'caption': caption,
      'visibility': visibility,
      'allowComments': allowComments,
      'recommendationEligible': recommendationEligible,
      'reusePolicy': reusePolicy,
      'aiGeneratedDisclosure': aiGeneratedDisclosure,
      'copyrightConfirmed': copyrightConfirmed,
    });
  }

  Future<void> deletePost(String postId) async {
    await _call('manageReel', <String, dynamic>{
      'operation': 'delete',
      'postId': postId,
    });
  }

  Future<String> requestReuse(String postId) async {
    final result = await _call('manageReel', <String, dynamic>{
      'operation': 'reuse',
      'postId': postId,
    });
    final requestId = result['requestId'];
    if (requestId is! String || requestId.isEmpty) {
      throw const ReelLifecycleException('Reuse request was not created.');
    }
    return requestId;
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    final result = await _call('searchReels', <String, dynamic>{'query': query});
    final raw = result['results'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}

class ReelLifecycleException implements Exception {
  const ReelLifecycleException(this.message);
  final String message;
  @override
  String toString() => message;
}
