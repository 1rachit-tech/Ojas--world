import 'dart:io' show File;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraAccessException implements Exception {
  const CameraAccessException(this.message, {this.canOpenSettings = false});

  final String message;
  final bool canOpenSettings;

  @override
  String toString() => message;
}

class CameraCaptureService {
  CameraController? _controller;

  CameraController? get controller => _controller;
  bool get isReady => _controller?.value.isInitialized ?? false;
  bool get isRecording => _controller?.value.isRecordingVideo ?? false;

  Future<void> initialize() async {
    if (!kIsWeb) {
      final cameraStatus = await Permission.camera.request();
      final microphoneStatus = await Permission.microphone.request();
      if (!cameraStatus.isGranted || !microphoneStatus.isGranted) {
        throw CameraAccessException(
          'Camera and microphone access are needed to create OJAS content.',
          canOpenSettings:
              cameraStatus.isPermanentlyDenied ||
              microphoneStatus.isPermanentlyDenied,
        );
      }
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw const CameraAccessException(
        'No camera is available on this device.',
      );
    }

    final camera = cameras.firstWhere(
      (device) => device.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );
    await controller.initialize();
    _controller = controller;
  }

  Future<void> toggleTorch(bool enabled) async {
    final controller = _controller;
    if (controller == null || !isReady) return;
    await controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
  }

  Future<XFile> takePicture() async {
    final controller = _requireController();
    final captured = await controller.takePicture();
    return _saveLocally(captured, 'photo');
  }

  Future<void> startVideoRecording() async {
    await _requireController().startVideoRecording();
  }

  Future<XFile> stopVideoRecording() async {
    final captured = await _requireController().stopVideoRecording();
    return _saveLocally(captured, 'video');
  }

  CameraController _requireController() {
    final controller = _controller;
    if (controller == null || !isReady) {
      throw const CameraAccessException('The camera is still starting.');
    }
    return controller;
  }

  Future<XFile> _saveLocally(XFile captured, String kind) async {
    if (kIsWeb) return captured;

    final directory = await getApplicationDocumentsDirectory();
    final extension = captured.path.split('.').last;
    final destination = File(
      '${directory.path}/ojas_${kind}_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    // TEMPORARY: uploads to Firebase Storage once Blaze plan is active, this local file will instead be uploaded
    await destination.writeAsBytes(await captured.readAsBytes());
    return XFile(destination.path);
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
