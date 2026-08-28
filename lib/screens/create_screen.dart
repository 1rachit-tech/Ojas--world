import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/camera_capture_service.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _cameraService = CameraCaptureService();
  int _mode = 0;
  bool _isLoading = false;
  bool _torchEnabled = false;
  bool _nightMode = false;
  String? _error;
  XFile? _lastCapture;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  bool get _isRecording => _cameraService.isRecording;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_isLoading) return;
    if (!_cameraService.isReady) {
      await _prepareCamera();
      return;
    }

    setState(() => _error = null);
    try {
      if (_mode == 1) {
        final capture = await _cameraService.takePicture();
        if (mounted) setState(() => _lastCapture = capture);
      } else if (_isRecording) {
        final capture = await _cameraService.stopVideoRecording();
        _recordingTimer?.cancel();
        if (mounted) {
          setState(() {
            _lastCapture = capture;
            _recordingDuration = Duration.zero;
          });
        }
      } else {
        await _cameraService.startVideoRecording();
        _recordingDuration = Duration.zero;
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              _recordingDuration += const Duration(seconds: 1);
            });
          }
        });
        setState(() {});
      }
    } on CameraException catch (exception) {
      _showError(exception.description ?? 'Camera operation failed.');
    } on CameraAccessException catch (exception) {
      _showError(exception.message);
    } catch (_) {
      _showError('Camera operation failed. Please try again.');
    }
  }

  Future<void> _prepareCamera() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _cameraService.initialize();
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Camera ready. Tap the button again to capture.');
      }
    } on CameraAccessException catch (exception) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = exception.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = kIsWeb
              ? 'Full camera recording works best in the OJAS mobile app.'
              : 'Camera could not start. Check your permissions and try again.';
        });
      }
    }
  }

  Future<void> _retryOrOpenSettings() async {
    if (!kIsWeb &&
        (await Permission.camera.isPermanentlyDenied ||
            await Permission.microphone.isPermanentlyDenied)) {
      await openAppSettings();
      return;
    }
    await _prepareCamera();
  }

  Future<void> _toggleTorch() async {
    if (!_cameraService.isReady) {
      _showMessage('Start the camera before changing flash.');
      return;
    }
    try {
      final enabled = !_torchEnabled;
      await _cameraService.toggleTorch(enabled);
      if (mounted) setState(() => _torchEnabled = enabled);
    } catch (_) {
      _showMessage('Flash is not available on this camera.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  void _showComingSoon(String label) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF202020),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: Color(0xFFF5B942)),
              const SizedBox(width: 14),
              Text(
                '$label - Coming soon',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraService.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            _buildPreview(controller)
          else
            _buildFallback(),
          _buildTopBar(),
          _buildActionRail(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildPreview(CameraController controller) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return ColoredBox(
      color: const Color(0xFF111111),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 46),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.videocam_outlined,
                color: const Color(0xFFF5B942),
                size: 42,
              ),
              const SizedBox(height: 16),
              Text(
                _isLoading
                    ? 'Starting your camera...'
                    : (_error ?? 'Tap record to activate your camera.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _retryOrOpenSettings,
                  child: Text(
                    !kIsWeb && _error!.contains('needed')
                        ? 'Retry or open settings'
                        : 'Try again',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .46),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 7),
                  Text(
                    'Original Sound',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _circleButton(
              icon: _torchEnabled
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
              label: 'Flash',
              onPressed: _toggleTorch,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRail() {
    return Positioned(
      right: 12,
      top: 110,
      child: Column(
        children: [
          _railButton(Icons.music_note_outlined, 'Sound'),
          _railButton(Icons.tune_rounded, 'Normal'),
          _railButton(Icons.timer_outlined, 'Timer'),
          _railButton(Icons.speed_rounded, 'Speed'),
          _railButton(
            _nightMode ? Icons.nightlight_round : Icons.nightlight_outlined,
            'Night',
            onPressed: () => setState(() => _nightMode = !_nightMode),
          ),
        ],
      ),
    );
  }

  Widget _railButton(IconData icon, String label, {VoidCallback? onPressed}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onPressed ?? () => _showComingSoon(label),
        child: SizedBox(
          width: 52,
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 23),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 18,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['VIDEO', 'PHOTO', 'STORY'].asMap().entries.map((
                entry,
              ) {
                final selected = _mode == entry.key;
                return GestureDetector(
                  onTap: () => setState(() => _mode = entry.key),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 13),
                    padding: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: selected
                          ? const Border(
                              bottom: BorderSide(
                                color: Color(0xFFF5B942),
                                width: 2,
                              ),
                            )
                          : null,
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 86,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_lastCapture != null)
                    Positioned(left: 22, child: _buildThumbnail(_lastCapture!)),
                  GestureDetector(
                    onTap: _capture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? const Color(0xFFD94B4B)
                            : Colors.white,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: _isRecording
                          ? Center(
                              child: Text(
                                _formatDuration(_recordingDuration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(XFile capture) {
    return FutureBuilder<Uint8List>(
      future: capture.readAsBytes(),
      builder: (context, snapshot) {
        return Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
            borderRadius: BorderRadius.circular(7),
            image: snapshot.hasData
                ? DecorationImage(
                    image: MemoryImage(snapshot.data!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: snapshot.hasData
              ? null
              : const Icon(Icons.movie_outlined, color: Colors.white),
        );
      },
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      icon: Icon(icon, color: Colors.white, size: 25),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
