import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class VideoExportResult {
  const VideoExportResult({
    required this.requestId,
    required this.outputPath,
    required this.bytes,
  });

  final String requestId;
  final String outputPath;
  final int bytes;
}

class VideoExportException implements Exception {
  const VideoExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Local-first Android video export bridge.
///
/// Heavy media processing stays on-device through Android Media3 Transformer.
class VideoExportService {
  VideoExportService._();

  static final VideoExportService instance = VideoExportService._();

  static const MethodChannel _methods =
      MethodChannel('ojas/video_transformer/methods');
  static const EventChannel _events =
      EventChannel('ojas/video_transformer/events');

  Stream<Map<String, dynamic>> get _eventStream =>
      _events.receiveBroadcastStream().map(
            (event) => Map<String, dynamic>.from(event as Map),
          );

  Future<VideoExportResult> exportTrimmedVideo({
    required String inputPath,
    required String projectId,
    required int startMs,
    required int endMs,
  }) async {
    final input = File(inputPath);
    if (!await input.exists()) {
      throw const VideoExportException(
        'The source video is no longer available.',
      );
    }

    if (startMs < 0 || endMs <= startMs) {
      throw const VideoExportException(
        'The selected trim range is invalid.',
      );
    }

    final documents = await getApplicationDocumentsDirectory();
    final exportDirectory = Directory(
      documents.path + '/ojas/exports',
    );
    await exportDirectory.create(recursive: true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath =
        exportDirectory.path + '/' + projectId + '_' + timestamp.toString() + '.mp4';

    final completer = Completer<VideoExportResult>();
    late final StreamSubscription<Map<String, dynamic>> subscription;

    subscription = _eventStream.listen(
      (event) {
        final type = event['type'] as String? ?? '';
        final eventRequestId = event['requestId'] as String? ?? '';

        if (type == 'completed' && eventRequestId.isNotEmpty) {
          if (!completer.isCompleted) {
            final path = event['outputPath'] as String? ?? outputPath;
            final bytes = (event['bytes'] as num?)?.toInt() ?? 0;
            completer.complete(
              VideoExportResult(
                requestId: eventRequestId,
                outputPath: path,
                bytes: bytes,
              ),
            );
          }
          return;
        }

        if (type == 'error' && eventRequestId.isNotEmpty) {
          if (!completer.isCompleted) {
            completer.completeError(
              VideoExportException(
                event['message'] as String? ??
                    'Local video export failed.',
              ),
            );
          }
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        }
      },
    );

    try {
      final requestId = await _methods.invokeMethod<String>(
        'startExport',
        <String, dynamic>{
          'inputPath': inputPath,
          'outputPath': outputPath,
          'startMs': startMs,
          'endMs': endMs,
          'removeAudio': false,
        },
      );

      if (requestId == null || requestId.isEmpty) {
        throw const VideoExportException(
          'The Android video export engine did not start.',
        );
      }

      final result = await completer.future.timeout(
        const Duration(hours: 2),
        onTimeout: () => throw const VideoExportException(
          'Video export timed out. Your draft is still safe locally.',
        ),
      );

      final output = File(result.outputPath);
      if (!await output.exists()) {
        throw const VideoExportException(
          'Video export completed without an output file.',
        );
      }

      return result;
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> cancelActiveExport() async {
    try {
      await _methods.invokeMethod<void>('cancelExport');
    } on PlatformException catch (error) {
      throw VideoExportException(
        error.message ?? 'Unable to cancel video export.',
      );
    }
  }
}