import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'post_creation_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.audioId});

  final String audioId;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  XFile? _capturedFile;
  String? _error;
  bool _initializing = true;
  bool _isRecording = false;
  bool _shutterBusy = false;
  String _currentShaderMode = 'Natural';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<bool> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final microphoneStatus = await Permission.microphone.request();

    return cameraStatus.isGranted && microphoneStatus.isGranted;
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }

    try {
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        if (!mounted) return;
        setState(() {
          _error = 'Camera and microphone permission are required.';
          _initializing = false;
        });
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'Camera unavailable.';
          _initializing = false;
        });
        return;
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final presets = <ResolutionPreset>[
        ResolutionPreset.veryHigh,
        ResolutionPreset.high,
        ResolutionPreset.medium,
      ];

      CameraController? initializedController;

      for (final preset in presets) {
        CameraController? candidate;
        try {
          candidate = CameraController(
            camera,
            preset,
            enableAudio: true,
          );
          await candidate.initialize();
          initializedController = candidate;
          break;
        } catch (_) {
          await candidate?.dispose();
        }
      }

      if (initializedController == null) {
        throw CameraException(
          'camera_initialization_failed',
          'Unable to initialize a supported camera resolution.',
        );
      }

      if (!mounted) {
        await initializedController.dispose();
        return;
      }

      setState(() {
        _controller = initializedController;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to open camera.';
        _initializing = false;
      });
      debugPrint('CameraScreen initialization failed: $error');
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isRecording ||
        _shutterBusy) {
      return;
    }

    setState(() {
      _shutterBusy = true;
      _error = null;
    });

    try {
      final file = await controller.takePicture();
      _capturedFile = file;
      debugPrint('Photo saved to: ${file.path}');

      // TODO: Pass the captured photo/video through video_compress or the
      // appropriate local media pipeline before any upload is introduced.
    } on CameraException catch (error) {
      _showCaptureError(error);
    } catch (error) {
      debugPrint('Camera photo capture failed: $error');
      _showCaptureError();
    } finally {
      if (mounted) {
        setState(() {
          _shutterBusy = false;
        });
      }
    }
  }

  Future<void> _startVideoRecording() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isRecording ||
        _shutterBusy) {
      return;
    }

    setState(() {
      _shutterBusy = true;
      _error = null;
    });

    try {
      await controller.startVideoRecording();
      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _shutterBusy = false;
      });
    } on CameraException catch (error) {
      _showCaptureError(error);
      if (mounted) {
        setState(() {
          _shutterBusy = false;
        });
      }
    } catch (error) {
      debugPrint('Camera video start failed: $error');
      _showCaptureError();
      if (mounted) {
        setState(() {
          _shutterBusy = false;
        });
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    final controller = _controller;
    if (controller == null || !_isRecording || _shutterBusy) {
      return;
    }

    setState(() {
      _shutterBusy = true;
    });

    try {
      final file = await controller.stopVideoRecording();
      _capturedFile = file;
      debugPrint('Video saved to: ${file.path}');

      // TODO: Process the captured video locally with video_compress before
      // any upload or remote processing is added to this screen.
      if (!mounted) return;

      setState(() {
        _isRecording = false;
        _shutterBusy = false;
      });

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostCreationScreen(
            videoPath: file.path,
            selectedShader: _currentShaderMode,
          ),
        ),
      );
    } on CameraException catch (error) {
      _showCaptureError(error);
      if (mounted) {
        setState(() {
          _isRecording = false;
          _shutterBusy = false;
        });
      }
    } catch (error) {
      debugPrint('Camera video stop failed: $error');
      _showCaptureError();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _shutterBusy = false;
        });
      }
    }
  }

  void _showCaptureError([CameraException? error]) {
    final message = error?.description;
    debugPrint('Camera capture failed: ${error?.code ?? 'unknown'}');

    if (!mounted) return;
    setState(() {
      _error = message == null || message.isEmpty
          ? 'Unable to capture media. Please try again.'
          : message;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final previewReady = controller?.value.isInitialized == true;
    final showChrome = !_isRecording;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: previewReady ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: previewReady
                ? CameraPreview(controller!)
                : const SizedBox.expand(),
          ),
          if (_error != null && !previewReady)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          if (_error == null || previewReady)
            AnimatedOpacity(
              opacity: showChrome ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !showChrome,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.music_note_rounded,
                              color: Color(0xFFF5B942),
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 220),
                              child: Text(
                                widget.audioId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (previewReady)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedOpacity(
                        opacity: showChrome ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: IgnorePointer(
                          ignoring: !showChrome,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ShaderChip(
                                label: 'Natural',
                                selected: _currentShaderMode == 'Natural',
                                onTap: () => _setShaderMode('Natural'),
                              ),
                              const SizedBox(width: 8),
                              _ShaderChip(
                                label: '4K Ultra HDR',
                                selected:
                                    _currentShaderMode == '4K Ultra HDR',
                                onTap: () =>
                                    _setShaderMode('4K Ultra HDR'),
                              ),
                              const SizedBox(width: 8),
                              _ShaderChip(
                                label: '8K Hyper Clarity',
                                selected:
                                    _currentShaderMode == '8K Hyper Clarity',
                                onTap: () =>
                                    _setShaderMode('8K Hyper Clarity'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildShutterButton(),
                    ],
                  ),
                ),
              ),
            ),
          if (_initializing)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _setShaderMode(String mode) {
    if (_currentShaderMode == mode || _isRecording || _shutterBusy) {
      return;
    }
    setState(() {
      _currentShaderMode = mode;
    });
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTap: _isRecording || _shutterBusy ? null : _takePicture,
      onLongPress: _isRecording || _shutterBusy
          ? null
          : _startVideoRecording,
      onLongPressUp: _isRecording ? _stopVideoRecording : null,
      child: AnimatedScale(
        scale: _isRecording ? 0.88 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 78,
          height: 78,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _isRecording ? Colors.redAccent : Colors.white,
              width: 4,
            ),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _isRecording ? 30 : 58,
              height: _isRecording ? 30 : 58,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.redAccent : Colors.white,
                borderRadius: BorderRadius.circular(_isRecording ? 7 : 30),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShaderChip extends StatelessWidget {
  const _ShaderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? Colors.white24 : Colors.black54,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
