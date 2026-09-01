import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../services/video_engine_service.dart';

class FullscreenLandscapePlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String creator;

  const FullscreenLandscapePlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.creator,
  });

  static void open(BuildContext context, {required String videoUrl, required String title, required String creator}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenLandscapePlayer(
          videoUrl: videoUrl,
          title: title,
          creator: creator,
        ),
      ),
    );
  }

  @override
  State<FullscreenLandscapePlayer> createState() => _FullscreenLandscapePlayerState();
}

class _FullscreenLandscapePlayerState extends State<FullscreenLandscapePlayer> {
  VideoPlayerController? _controller;
  bool _isPlaying = true;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // 1. फोन को Landscape मोड में रोटेट करें
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initVideo();
  }

  Future<void> _initVideo() async {
    final ctrl = await VideoEngineService.instance.getOrCreateController(widget.videoUrl);
    if (!mounted) return;
    setState(() {
      _controller = ctrl;
    });
    await ctrl.play();
  }

  @override
  void dispose() {
    // 2. वापस आते समय फोन को Portrait (सीधा) करें
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center 16:9 Video
            if (_controller != null && _controller!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: ColorFiltered(
                    colorFilter: VideoEngineService.superResolutionEnhancer,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.white)),

            // Overlay Controls
            if (_showControls)
              Container(
                color: Colors.black38,
                child: Stack(
                  children: [
                    // Top Bar
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(widget.creator, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Center Play/Pause
                    Center(
                      child: IconButton(
                        iconSize: 64,
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
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
}
