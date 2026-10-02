import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Client-side LiveKit entrypoint.
///
/// Security rules:
/// - API key/secret NEVER ship in the app
/// - Token is minted by Cloud Function `createLiveKitToken`
/// - Function verifies Firebase Auth + conversation membership + blocks
class LiveKitCallService {
  LiveKitCallService._();
  static final LiveKitCallService instance = LiveKitCallService._();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Returns short-lived room credentials from the server.
  Future<LiveKitSession> createSession({
    required String conversationId,
    bool isVideo = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const LiveKitCallException('Please sign in to start a call.');
    }
    if (conversationId.trim().isEmpty) {
      throw const LiveKitCallException('Invalid conversation.');
    }

    try {
      final callable = _functions.httpsCallable(
        'createLiveKitToken',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call(<String, dynamic>{
        'conversationId': conversationId.trim(),
        'isVideo': isVideo,
      });

      final data = result.data;
      if (data is! Map) {
        throw const LiveKitCallException('Invalid server response.');
      }

      final token = data['token']?.toString() ?? '';
      final url = data['url']?.toString() ?? '';
      final roomName = data['roomName']?.toString() ?? '';
      final identity = data['identity']?.toString() ?? '';

      if (token.isEmpty || url.isEmpty || roomName.isEmpty) {
        throw const LiveKitCallException('Call credentials incomplete.');
      }

      return LiveKitSession(
        token: token,
        url: url,
        roomName: roomName,
        identity: identity,
        isVideo: isVideo,
      );
    } on FirebaseFunctionsException catch (e) {
      final code = e.code;
      if (code == 'unauthenticated') {
        throw const LiveKitCallException('Please sign in again.');
      }
      if (code == 'permission-denied') {
        throw const LiveKitCallException('You cannot call this user.');
      }
      if (code == 'failed-precondition') {
        throw const LiveKitCallException(
          'Calling is not configured yet. Try again later.',
        );
      }
      throw LiveKitCallException(e.message ?? 'Unable to start call.');
    } catch (e) {
      if (e is LiveKitCallException) rethrow;
      throw const LiveKitCallException('Unable to start call.');
    }
  }
}

class LiveKitSession {
  const LiveKitSession({
    required this.token,
    required this.url,
    required this.roomName,
    required this.identity,
    required this.isVideo,
  });

  final String token;
  final String url;
  final String roomName;
  final String identity;
  final bool isVideo;
}

class LiveKitCallException implements Exception {
  const LiveKitCallException(this.message);
  final String message;
  @override
  String toString() => message;
}
