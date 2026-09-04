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

  static Future<void> open(
    BuildContext context, {
    required String videoUrl,
    required String title,
    required String creator,
  }) async {
    HapticFeedback.mediumImpact();
    await Navigator.push<void>(
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
  bool _isInit = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final ctrl = await VideoEngineService.instance.getOrCreateController(widget.videoUrl);
    if (!mounted) return;
    setState(() {
      _controller = ctrl;
      _isInit = ctrl.value.isInitialized;
    });
    if (_isInit) {
      await ctrl.play();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  Future<void> _restorePortraitSystemUi() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _restorePortraitSystemUi();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isInit && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white30,
                ),
              ),
            if (_showControls)
              Positioned(
                top: 16,
                left: 20,
                right: 20,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context);
                          },
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                '@${widget.creator}',
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            (_controller?.value.isPlaying ?? false)
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: const Color(0xFF111827),
                            size: 26,
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (_controller?.value.isPlaying ?? false) {
                                _controller?.pause();
                              } else {
                                _controller?.play();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_showControls && _isInit && _controller != null)
              Positioned(
                left: 30,
                right: 30,
                bottom: 24,
                child: SafeArea(
                  child: ValueListenableBuilder(
                    valueListenable: _controller!,
                    builder: (context, VideoPlayerValue val, child) {
                      final duration = val.duration.inMilliseconds.toDouble();
                      final position = val.position.inMilliseconds.toDouble();
                      final currentVal = duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;

                      return Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: currentVal,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}