import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.audioId});

  final String audioId;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  String? _error;
  bool _initializing = true;

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
    setState(() {
      _initializing = true;
      _error = null;
    });

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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final previewReady = controller?.value.isInitialized == true;

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
            SafeArea(
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
                          constraints: const BoxConstraints(maxWidth: 220),
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
          if (previewReady)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ShaderChip(label: 'Natural'),
                          SizedBox(width: 8),
                          _ShaderChip(label: 'Crisp'),
                          SizedBox(width: 8),
                          _ShaderChip(label: 'Vivid'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () {
                          // Recording intentionally deferred to a later Studio step.
                          // TODO: Pass the captured video file through video_compress
                          // before any upload or remote processing occurs.
                        },
                        child: Container(
                          width: 78,
                          height: 78,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
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
}

class _ShaderChip extends StatelessWidget {
  const _ShaderChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
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
    );
  }
}
