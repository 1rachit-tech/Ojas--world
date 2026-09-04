import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _OjasSmartVideoPlayerState extends State<OjasSmartVideoPlayer>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInit = false;
  bool _isPlaying = true;
  bool _showHeartAnim = false;

  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnimation;

  bool get _isNativeHls {
    if (kIsWeb) return false;
    final lower = widget.videoUrl.toLowerCase();
    return lower.contains('.m3u8');
  }

  @override
  void initState() {
    super.initState();

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _heartAnimController,
      curve: Curves.easeOutCubic,
    ));

    if (!_isNativeHls) {
      _loadVideo();
    }
  }

  @override
  void didUpdateWidget(covariant OjasSmartVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl && !_isNativeHls) {
      _loadVideo();
    }
  }

  Future<void> _loadVideo() async {
    if (widget.videoUrl.isEmpty) return;

    try {
      final ctrl = await VideoEngineService.instance.getOrCreateController(
        widget.videoUrl,
      );

      if (!mounted) return;

      setState(() {
        _controller = ctrl;
        _isInit = ctrl.value.isInitialized;
        _isPlaying = ctrl.value.isPlaying;
      });

      if (_isInit && _isPlaying) {
        await ctrl.play();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isInit = false);
      }
    }
  }

  void _togglePlayback() {
    if (widget.onReelTap != null) {
      widget.onReelTap!();
      return;
    }

    if (_controller == null || !_isInit) return;

    HapticFeedback.selectionClick();

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

  void _handleDoubleTap() {
    HapticFeedback.mediumImpact();
    setState(() => _showHeartAnim = true);
    _heartAnimController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _showHeartAnim = false);
      }
    });
  }

  Widget _buildNativeHlsPlayer() {
    final params = <String, Object>{'url': widget.videoUrl};

    Widget playerView;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        playerView = AndroidView(
          key: ValueKey(widget.videoUrl),
          viewType: 'ojas/hls_player',
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
        );
      case TargetPlatform.iOS:
        playerView = UiKitView(
          key: ValueKey(widget.videoUrl),
          viewType: 'ojas/hls_player',
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
        );
      default:
        playerView = const ColoredBox(color: Colors.black);
    }

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              playerView,
              if (widget.isPortraitReel)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFFF5B942),
                          size: 14,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'REEL 9:16',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_showHeartAnim)
                Center(
                  child: ScaleTransition(
                    scale: _heartScaleAnimation,
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFEF4444),
                      size: 80,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isNativeHls) {
      return _buildNativeHlsPlayer();
    }

    return GestureDetector(
      onTap: _togglePlayback,
      onDoubleTap: _handleDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Container(
            color: const Color(0xFF0F172A),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Hardware-Accelerated Video Surface with AI Upscaler Shader
                if (_isInit && _controller != null)
                  ColorFiltered(
                    colorFilter: VideoEngineService.superResolutionEnhancer,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: _controller!.value.size.width > 0
                            ? _controller!.value.size.width
                            : 1080,
                        height: _controller!.value.size.height > 0
                            ? _controller!.value.size.height
                            : 1920,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                else
                  const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFFF5B942),
                      ),
                    ),
                  ),

                // 2. 9:16 Reel Badge
                if (widget.isPortraitReel)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Color(0xFFF5B942),
                            size: 14,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'REEL 9:16',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 3. Play/Pause Overlay Indicator
                if (!_isPlaying && _isInit)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),

                // 4. Double Tap Heart Pop Effect
                if (_showHeartAnim)
                  Center(
                    child: ScaleTransition(
                      scale: _heartScaleAnimation,
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFEF4444),
                        size: 80,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 16,
                          ),
                        ],
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
