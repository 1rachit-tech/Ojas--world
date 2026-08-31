import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'post_preview_screen.dart';
import '../widgets/sound_picker_sheet.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;

  // Camera & Mode Controls
  int _selectedMode = 0; // 0 = VIDEO, 1 = PHOTO, 2 = STORY
  FlashMode _flashMode = FlashMode.off;
  double _currentSpeed = 1.0;
  int _timerSeconds = 0; // 0, 3, 10
  int _countdownValue = 0;
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordTimer;
  String _selectedSound = 'Original Sound';

  // Filters State
  int _selectedFilterIndex = 0;
  final List<Map<String, dynamic>> _filters = [
    {'name': 'Normal', 'icon': Icons.auto_awesome, 'colorFilter': null},
    {
      'name': 'Glow Beauty',
      'icon': Icons.face_retouching_natural_rounded,
      'colorFilter': const ColorFilter.matrix([
        1.08, 0, 0, 0, 10,
        0, 1.05, 0, 0, 8,
        0, 0, 1.02, 0, 6,
        0, 0, 0, 1, 0,
      ]),
    },
    {
      'name': 'Golden Warm',
      'icon': Icons.wb_sunny_rounded,
      'colorFilter': const ColorFilter.matrix([
        1.15, 0, 0, 0, 15,
        0, 1.05, 0, 0, 5,
        0, 0, 0.90, 0, -10,
        0, 0, 0, 1, 0,
      ]),
    },
    {
      'name': 'Night AI',
      'icon': Icons.bedtime_rounded,
      'colorFilter': const ColorFilter.matrix([
        1.25, 0, 0, 0, 25,
        0, 1.25, 0, 0, 25,
        0, 0, 1.30, 0, 30,
        0, 0, 0, 1, 0,
      ]),
    },
    {
      'name': 'B & W',
      'icon': Icons.filter_b_and_w_rounded,
      'colorFilter': const ColorFilter.matrix([
        0.33, 0.59, 0.11, 0, 0,
        0.33, 0.59, 0.11, 0, 0,
        0.33, 0.59, 0.11, 0, 0,
        0, 0, 0, 1, 0,
      ]),
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      _initCameraIndex(_selectedCameraIndex);
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _initCameraIndex(0);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _initCameraIndex(int index) async {
    if (_cameras.isEmpty) return;
    setState(() => _isCameraReady = false);
    _cameraController = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
    );
    try {
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _selectedCameraIndex = index;
          _isCameraReady = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
    }
  }

  void _flipCamera() {
    if (_cameras.length < 2) return;
    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _initCameraIndex(nextIndex);
  }

  void _toggleFlash() async {
    if (_cameraController == null) return;
    FlashMode nextMode;
    if (_flashMode == FlashMode.off) {
      nextMode = FlashMode.torch;
    } else if (_flashMode == FlashMode.torch) {
      nextMode = FlashMode.auto;
    } else {
      nextMode = FlashMode.off;
    }
    try {
      await _cameraController!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (_) {}
  }

  // Record or Capture Logic
  void _onCaptureTap() {
    if (_timerSeconds > 0 && !_isRecording) {
      _startTimerCountdown();
    } else {
      _executeCaptureAction();
    }
  }

  void _startTimerCountdown() {
    setState(() => _countdownValue = _timerSeconds);
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownValue <= 1) {
        timer.cancel();
        setState(() => _countdownValue = 0);
        _executeCaptureAction();
      } else {
        setState(() => _countdownValue--);
      }
    });
  }

  Future<void> _executeCaptureAction() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    if (_selectedMode == 1) {
      // Photo Mode
      try {
        final XFile photo = await _cameraController!.takePicture();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostPreviewScreen(mediaPath: photo.path, isVideo: false)),
        );
      } catch (e) {
        debugPrint('Photo take error: $e');
      }
    } else {
      // Video or Story Mode
      if (_isRecording) {
        // Stop recording
        try {
          final XFile video = await _cameraController!.stopVideoRecording();
          _recordTimer?.cancel();
          setState(() {
            _isRecording = false;
            _recordingDuration = 0;
          });
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PostPreviewScreen(mediaPath: video.path, isVideo: true)),
          );
        } catch (e) {
          debugPrint('Stop video error: $e');
        }
      } else {
        // Start recording
        try {
          await _cameraController!.startVideoRecording();
          setState(() {
            _isRecording = true;
            _recordingDuration = 0;
          });
          _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            setState(() => _recordingDuration++);
            if (_recordingDuration >= 60) {
              _executeCaptureAction(); // Auto stop at 60s
            }
          });
        } catch (e) {
          debugPrint('Start video error: $e');
        }
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? media = await picker.pickMedia();
    if (media != null && mounted) {
      final isVideo = media.path.endsWith('.mp4') || media.path.endsWith('.mov');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PostPreviewScreen(mediaPath: media.path, isVideo: isVideo)),
      );
    }
  }

  // Real Sound Picker Sheet Connection
  void _showSoundSheet() {
    SoundPickerSheet.show(
      context,
      currentSound: _selectedSound,
      onSoundSelected: (newSound) {
        setState(() {
          _selectedSound = newSound;
        });
      },
    );
  }

  void _cycleSpeed() {
    setState(() {
      if (_currentSpeed == 0.5) {
        _currentSpeed = 1.0;
      } else if (_currentSpeed == 1.0) {
        _currentSpeed = 2.0;
      } else if (_currentSpeed == 2.0) {
        _currentSpeed = 3.0;
      } else {
        _currentSpeed = 0.5;
      }
    });
  }

  void _cycleTimer() {
    setState(() {
      if (_timerSeconds == 0) {
        _timerSeconds = 3;
      } else if (_timerSeconds == 3) {
        _timerSeconds = 10;
      } else {
        _timerSeconds = 0;
      }
    });
  }

  void _openFiltersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: 140,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filters.length,
            itemBuilder: (context, index) {
              final f = _filters[index];
              final isSelected = _selectedFilterIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedFilterIndex = index);
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFF5B942) : const Color(0xFF21262D),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(f['icon'] as IconData, color: isSelected ? Colors.black : Colors.white, size: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(f['name'] as String, style: TextStyle(color: isSelected ? const Color(0xFFF5B942) : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. LIVE CAMERA PREVIEW WITH COLOR FILTER
          if (_isCameraReady && _cameraController != null)
            ColorFiltered(
              colorFilter: _filters[_selectedFilterIndex]['colorFilter'] ??
                  const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize?.height ?? 1,
                    height: _cameraController!.value.previewSize?.width ?? 1,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Color(0xFFF5B942))),

          // 2. RECORDING DURATION INDICATOR (TOP)
          if (_isRecording)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '00:${_recordingDuration.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. COUNTDOWN OVERLAY
          if (_countdownValue > 0)
            Center(
              child: Text(
                '$_countdownValue',
                style: const TextStyle(color: Color(0xFFF5B942), fontSize: 90, fontWeight: FontWeight.w900),
              ),
            ),

          // 4. TOP SOUND SELECTOR & FLASH
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                GestureDetector(
                  onTap: _showSoundSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(_selectedSound, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _toggleFlash,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black45,
                    child: Icon(
                      _flashMode == FlashMode.torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _flashMode == FlashMode.torch ? const Color(0xFFF5B942) : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. RIGHT ACTION RAIL (Sound, Filters, Timer, Speed, Night AI)
          Positioned(
            top: 110,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  _buildSideTool(icon: Icons.music_note_rounded, label: 'Sound', onTap: _showSoundSheet),
                  const SizedBox(height: 12),
                  _buildSideTool(
                    icon: _filters[_selectedFilterIndex]['icon'] as IconData,
                    label: _filters[_selectedFilterIndex]['name'] as String,
                    onTap: _openFiltersSheet,
                    color: _selectedFilterIndex > 0 ? const Color(0xFFF5B942) : Colors.white,
                  ),
                  const SizedBox(height: 12),
                  _buildSideTool(
                    icon: Icons.timer_rounded,
                    label: _timerSeconds == 0 ? 'Timer' : '${_timerSeconds}s',
                    onTap: _cycleTimer,
                    color: _timerSeconds > 0 ? const Color(0xFFF5B942) : Colors.white,
                  ),
                  const SizedBox(height: 12),
                  _buildSideTool(
                    icon: Icons.speed_rounded,
                    label: '${_currentSpeed}x',
                    onTap: _cycleSpeed,
                    color: _currentSpeed != 1.0 ? const Color(0xFFF5B942) : Colors.white,
                  ),
                  const SizedBox(height: 12),
                  _buildSideTool(
                    icon: Icons.bedtime_rounded,
                    label: 'Night AI',
                    onTap: () {
                      setState(() {
                        _selectedFilterIndex = _selectedFilterIndex == 3 ? 0 : 3;
                      });
                    },
                    color: _selectedFilterIndex == 3 ? const Color(0xFF4ADE80) : Colors.white,
                  ),
                ],
              ),
            ),
          ),

          // 6. BOTTOM CONTROL SECTION (Mode Selector + Shutter Button + Upload + Flip)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mode Selector (VIDEO | PHOTO | STORY)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildModeButton('VIDEO', 0),
                    const SizedBox(width: 20),
                    _buildModeButton('PHOTO', 1),
                    const SizedBox(width: 20),
                    _buildModeButton('STORY', 2),
                  ],
                ),
                const SizedBox(height: 16),

                // Controls Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Upload from Gallery
                      GestureDetector(
                        onTap: _pickFromGallery,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
                              child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
                            ),
                            const SizedBox(height: 4),
                            const Text('Upload', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),

                      // Central Shutter Button
                      GestureDetector(
                        onTap: _onCaptureTap,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _isRecording ? Colors.redAccent : Colors.white, width: 4),
                              ),
                            ),
                            Container(
                              width: _isRecording ? 32 : 62,
                              height: _isRecording ? 32 : 62,
                              decoration: BoxDecoration(
                                color: _selectedMode == 1 ? Colors.white : (_isRecording ? Colors.redAccent : const Color(0xFFF5B942)),
                                shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                                borderRadius: _isRecording ? BorderRadius.circular(6) : null,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Camera Flip
                      GestureDetector(
                        onTap: _flipCamera,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
                              child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(height: 4),
                            const Text('Flip', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideTool({required IconData icon, required String label, required VoidCallback onTap, Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildModeButton(String title, int modeIndex) {
    final isSelected = _selectedMode == modeIndex;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = modeIndex),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(width: 16, height: 2, decoration: BoxDecoration(color: const Color(0xFFF5B942), borderRadius: BorderRadius.circular(1))),
        ],
      ),
    );
  }
}
