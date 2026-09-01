import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/video_engine_service.dart';

class OjasSmartVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final double aspectRatio;
  final bool isPortraitReel;
  final VoidCallback? onReelTap;

  const OjasSmartVideoPlayer({
    super.key,
    required this.videoUrl,
    this.aspectRatio = 16 / 9,
    this.isPortraitReel = false,
    this.onReelTap,
  });

  @override
  State<OjasSmartVideoPlayer> createState() => _OjasSmartVideoPlayerState();
}

class _OjasSmartVideoPlayerState extends State<OjasSmartVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInit = false;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    final ctrl = await VideoEngineService.instance.getOrCreateController(widget.videoUrl);
    if (!mounted) return;
    setState(() {
      _controller = ctrl;
      _isInit = ctrl.value.isInitialized;
    });
    if (_isInit) {
      await ctrl.setVolume(1.0);
      await ctrl.play();
    }
  }

  void _togglePlayback() {
    if (widget.onReelTap != null) {
      widget.onReelTap!();
      return;
    }
    if (_controller == null || !_isInit) return;
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
    return GestureDetector(
      onTap: _togglePlayback,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Container(
            color: const Color(0xFF111827),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_isInit && _controller != null)
                  ColorFiltered(
                    colorFilter: VideoEngineService.superResolutionEnhancer,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                else
                  const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),

                if (widget.isPortraitReel)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 2),
                          Text(
                            'REEL 9:16',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (!_isPlaying && _isInit)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
