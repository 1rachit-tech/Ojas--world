import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AzurePlaybackAsset {
  const AzurePlaybackAsset({
    required this.playbackUrl,
    this.thumbnailUrl,
  });

  final String playbackUrl;
  final String? thumbnailUrl;
}

class AzureMediaPlaybackService {
  AzureMediaPlaybackService({
    FirebaseAuth? auth,
    http.Client? client,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _client;

  String get brokerUrl => const String.fromEnvironment(
        'OJAS_AZURE_MEDIA_BROKER_URL',
      ).trim().replaceFirst(RegExp(r'/$'), '');

  bool get isConfigured => brokerUrl.isNotEmpty;

  Future<Map<String, AzurePlaybackAsset>> resolvePlaybackAssets(
    Iterable<String> reelIds,
  ) async {
    if (!isConfigured) return const <String, AzurePlaybackAsset>{};

    final ids = reelIds
        .where((id) => id.isNotEmpty)
        .take(10)
        .toList(growable: false);
    if (ids.isEmpty) return const <String, AzurePlaybackAsset>{};

    final user = _auth.currentUser;
    if (user == null) return const <String, AzurePlaybackAsset>{};

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      return const <String, AzurePlaybackAsset>{};
    }

    final response = await _client.post(
      Uri.parse('$brokerUrl/media/creation-playback-urls'),
      headers: <String, String>{
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{'reelIds': ids}),
    );

    if (response.statusCode != 200) {
      return const <String, AzurePlaybackAsset>{};
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['urls'] is! Map) {
        return const <String, AzurePlaybackAsset>{};
      }

      final result = <String, AzurePlaybackAsset>{};
      for (final entry in (decoded['urls'] as Map).entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is! Map || value['playbackUrl'] is! String) continue;
        final url = (value['playbackUrl'] as String).trim();
        if (url.isEmpty) continue;
        final thumbnail = value['thumbnailUrl'] is String
            ? (value['thumbnailUrl'] as String).trim()
            : '';
        result[key] = AzurePlaybackAsset(
          playbackUrl: url,
          thumbnailUrl: thumbnail.isEmpty ? null : thumbnail,
        );
      }
      return result;
    } catch (_) {
      return const <String, AzurePlaybackAsset>{};
    }
  }

  Future<Map<String, String>> resolvePlaybackUrls(
    Iterable<String> reelIds,
  ) async {
    final assets = await resolvePlaybackAssets(reelIds);
    return assets.map(
      (key, value) => MapEntry(key, value.playbackUrl),
    );
  }

  void dispose() => _client.close();
}
