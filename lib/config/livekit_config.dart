/// LiveKit free-tier wiring.
///
/// 1. Create project at https://cloud.livekit.io (free tier)
/// 2. Pass URL + API key/secret only via server token endpoint (never ship secret in app)
/// 3. Set compile-time defines:
///    --dart-define=OJAS_LIVEKIT_URL=wss://your-project.livekit.cloud
///    --dart-define=OJAS_LIVEKIT_TOKEN_URL=https://your-api/livekit-token
///
/// Client requests a short-lived room token from [tokenUrl], then connects
/// with livekit_client package (add when ready):
///   livekit_client: ^2.x
class LiveKitConfig {
  LiveKitConfig._();

  static const String serverUrl = String.fromEnvironment(
    'OJAS_LIVEKIT_URL',
    defaultValue: '',
  );

  /// Your backend that mints LiveKit JWTs for authenticated Firebase users.
  static const String tokenUrl = String.fromEnvironment(
    'OJAS_LIVEKIT_TOKEN_URL',
    defaultValue: '',
  );

  static bool get isConfigured =>
      serverUrl.trim().isNotEmpty && tokenUrl.trim().isNotEmpty;

  /// Room name convention: conversationId keeps 1:1 calls isolated & cheap.
  static String roomNameForConversation(String conversationId) =>
      'ojas_$conversationId';
}
