import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'video_editor_screen.dart';
import '../widgets/sound_picker_sheet.dart';
import '../widgets/audio_trimmer_sheet.dart';
import '../widgets/filter_store_sheet.dart';
import '../widgets/camera_settings_sheet.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, this.audioTrackId});

  final String? audioTrackId;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  bool _hasCameraPermissionError = false;

  int _selectedMode = 0; // 0 = VIDEO, 1 = PHOTO, 2 = STORY
  FlashMode _flashMode = FlashMode.off;
  double _currentSpeed = 1.0;
  int _timerSeconds = 0;
  int _countdownValue = 0;
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordTimer;
  String _selectedSound = 'Original Sound';
  double _soundStartSec = 0.0;
  double _soundEndSec = 0.0;
  bool _isBeautyEnabled = false;
  bool _isFrontCamera = false;
  OjasFilter _activeFilter = kAllOjasFilters.isNotEmpty
      ? kAllOjasFilters[0]
      : const OjasFilter(
          id: 0,
          name: 'Normal',
          category: 'Popular',
          icon: Icons.auto_awesome,
          previewColor: Colors.white24,
        );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.audioTrackId?.trim().isNotEmpty == true) {
      _selectedSound = widget.audioTrackId!.trim();
    }
    
    // 🚀 FIXED: Added ALL required parameters (including category & previewColor)
    _activeFilter = kAllOjasFilters.isNotEmpty
        ? kAllOjasFilters[0]
        : const OjasFilter(
            id: 0,
            name: 'Normal',
            category: 'Popular',
            icon: Icons.auto_awesome,
            previewColor: Colors.white24, // Fixed: previewColor added
          );
          
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameras();
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _hasCameraPermissionError = true);
        return;
      }
      _selectedCameraIndex = _isFrontCamera
          ? (_cameras.indexWhere((camera) => camera.lensDirection == CameraLensDirection.front) == -1
              ? 0
              : _cameras.indexWhere((camera) => camera.lensDirection == CameraLensDirection.front))
          : (_cameras.indexWhere((camera) => camera.lensDirection == CameraLensDirection.back) == -1
              ? 0
              : _cameras.indexWhere((camera) => camera.lensDirection == CameraLensDirection.back));
      await _initializeCamera(_cameras[_selectedCameraIndex]);
    } catch (error) {
      debugPrint('Camera init failed: $error');
      if (mounted) setState(() => _hasCameraPermissionError = true);
    }
  }

  Future<void> _initializeCamera(CameraDescription description) async {
    await _cameraController?.dispose();
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: true,
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
        _hasCameraPermissionError = false;
      });
    } catch (error) {
      await controller.dispose();
      debugPrint('Camera controller init failed: $error');
      if (mounted) setState(() => _hasCameraPermissionError = true);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isCameraReady = false);
    _isFrontCamera = !_isFrontCamera;
    await _initCameras();
  }

  Future<void> _capture() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isRecording) return;
    try {
      if (_selectedMode == 1) {
        final file = await controller.takePicture();
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VideoEditorScreen(filePath: file.path),
          ),
        );
        return;
      }
      await controller.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordingDuration++);
      });
    } catch (error) {
      debugPrint('Capture failed: $error');
    }
  }

  Future<void> _stopRecording() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isRecording) return;
    try {
      _recordTimer?.cancel();
      final file = await controller.stopVideoRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoEditorScreen(filePath: file.path),
        ),
      );
    } catch (error) {
      debugPrint('Stop recording failed: $error');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _capture();
    }
  }

  Future<void> _openSoundPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SoundPickerSheet(),
    );
    if (!mounted || selected == null || selected.trim().isEmpty) return;
    setState(() => _selectedSound = selected.trim());
  }

  Future<void> _openTrimSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AudioTrimmerSheet(
        initialStartSeconds: _soundStartSec,
        initialEndSeconds: _soundEndSec,
        onChanged: (start, end) {
          _soundStartSec = start;
          _soundEndSec = end;
        },
      ),
    );
  }

  Future<void> _openFilters() async {
    final filter = await showModalBottomSheet<OjasFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterStoreSheet(selectedFilter: _activeFilter),
    );
    if (!mounted || filter == null) return;
    setState(() => _activeFilter = filter);
  }

  Future<void> _openCameraSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CameraSettingsSheet(
        flashMode: _flashMode,
        speed: _currentSpeed,
        beautyEnabled: _isBeautyEnabled,
        onChanged: ({required flashMode, required speed, required beautyEnabled}) {
          if (!mounted) return;
          setState(() {
            _flashMode = flashMode;
            _currentSpeed = speed;
            _isBeautyEnabled = beautyEnabled;
          });
          _cameraController?.setFlashMode(flashMode);
        },
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isCameraReady && _cameraController != null)
              Center(
                child: CameraPreview(_cameraController!),
              )
            else
              const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (_hasCameraPermissionError)
              Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Camera access is unavailable.',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              top: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  if (_selectedSound != 'Original Sound')
                    GestureDetector(
                      onTap: _openTrimSheet,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _selectedSound,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: _openCameraSettings,
                    icon: const Icon(Icons.settings_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 26,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: _openSoundPicker,
                        icon: const Icon(Icons.music_note_rounded, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: _openFilters,
                        icon: Icon(_activeFilter.icon, color: Colors.white),
                      ),
                      GestureDetector(
                        onTap: _toggleRecording,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            decoration: BoxDecoration(
                              color: _isRecording ? Colors.red : Colors.white,
                              shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                              borderRadius: _isRecording ? BorderRadius.circular(14) : null,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _switchCamera,
                        icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: _openSoundPicker,
                        icon: const Icon(Icons.library_music_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isRecording ? _formatDuration(_recordingDuration) : _selectedMode == 0 ? 'VIDEO' : 'PHOTO',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}