import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  int _selectedCameraIndex = 0;
  
  // Tabs: 0 = VIDEO, 1 = PHOTO, 2 = STORY
  int _selectedMode = 0;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraSetup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_cameras![_selectedCameraIndex]);
    }
  }

  Future<void> _initializeCameraSetup() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // पिछली बार इस्तेमाल किया गया कैमरा याद रखें
        final prefs = await SharedPreferences.getInstance();
        _selectedCameraIndex = prefs.getInt('last_camera_index') ?? 0;
        
        if (_selectedCameraIndex >= _cameras!.length) {
          _selectedCameraIndex = 0;
        }
        await _initCamera(_cameras![_selectedCameraIndex]);
      }
    } catch (e) {
      debugPrint('Camera fetch error: $e');
    }
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    final previousController = _cameraController;
    
    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await previousController?.dispose();

    if (mounted) {
      setState(() => _cameraController = cameraController);
    }

    try {
      await cameraController.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } on CameraException catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    
    setState(() => _isCameraInitialized = false);
    
    _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;
    
    // यूज़र की पसंद सेव करें ताकि अगली बार वही कैमरा खुले
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_camera_index', _selectedCameraIndex);
    
    await _initCamera(_cameras![_selectedCameraIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Camera Preview with Double Tap Gesture
            Positioned.fill(
              child: GestureDetector(
                onDoubleTap: _toggleCamera,
                child: _isCameraInitialized && _cameraController != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
                          child: CameraPreview(_cameraController!),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFF5B942), // OJAS Yellow
                        ),
                      ),
              ),
            ),

            // 2. Top Bar (Original Sound & Flash)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32), // Placeholder for balance
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Original Sound',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {}, // Flash Toggle logic here
                    icon: const Icon(Icons.flash_off_rounded, color: Colors.white),
                    style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.3)),
                  ),
                ],
              ),
            ),

            // 3. Right Side Toolbar (Exactly like Image 2)
            Positioned(
              right: 16,
              top: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  children: [
                    _buildRightToolbarIcon(Icons.music_note_rounded, 'Sound'),
                    const SizedBox(height: 16),
                    _buildRightToolbarIcon(Icons.auto_awesome_rounded, 'Normal'),
                    const SizedBox(height: 16),
                    _buildRightToolbarIcon(Icons.timer_outlined, 'Timer'),
                    const SizedBox(height: 16),
                    _buildRightToolbarIcon(Icons.speed_rounded, 'Speed'),
                    const SizedBox(height: 16),
                    _buildRightToolbarIcon(Icons.nights_stay_rounded, 'Night AI', isGreen: true),
                  ],
                ),
              ),
            ),

            // 4. Bottom Controls
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tab Selector (VIDEO | PHOTO | STORY)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildModeTab(0, 'VIDEO'),
                      const SizedBox(width: 24),
                      _buildModeTab(1, 'PHOTO'),
                      const SizedBox(width: 24),
                      _buildModeTab(2, 'STORY'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Record Row (Gallery Left, Record Center, Flip Right)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Gallery / Upload Icon
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white70, width: 1.5),
                              ),
                              child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 6),
                            const Text('Upload', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),

                        // Center: Record Button
                        GestureDetector(
                          onTap: () {
                            // Recording / Capture logic
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),

                        // Right: Flip Camera Icon
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _toggleCamera,
                              child: Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 24),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text('Flip', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ],
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

  Widget _buildRightToolbarIcon(IconData icon, String label, {bool isGreen = false}) {
    return Column(
      children: [
        Icon(icon, color: isGreen ? const Color(0xFF4ADE80) : Colors.white, size: 26),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isGreen ? const Color(0xFF4ADE80) : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildModeTab(int index, String title) {
    final isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = index),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          if (isSelected)
            Container(
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFF5B942), // OJAS Active Color
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else
            const SizedBox(height: 3),
        ],
      ),
    );
  }
}
