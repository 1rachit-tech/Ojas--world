import 'package:flutter/services.dart';

class LocalAudioFile {
  const LocalAudioFile({
    required this.path,
    required this.durationMs,
  });

  final String path;
  final int durationMs;
}

class LocalAudioPickerService {
  LocalAudioPickerService._();

  static final LocalAudioPickerService instance =
      LocalAudioPickerService._();

  static const MethodChannel _channel =
      MethodChannel('ojas/audio_picker');

  Future<LocalAudioFile?> pickAudio() async {
    final result =
        await _channel.invokeMethod<dynamic>('pickAudio');

    if (result == null) {
      return null;
    }

    final map = Map<String, dynamic>.from(result as Map);
    final path = map['path'] as String? ?? '';
    if (path.isEmpty) {
      return null;
    }

    return LocalAudioFile(
      path: path,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
    );
  }
}
