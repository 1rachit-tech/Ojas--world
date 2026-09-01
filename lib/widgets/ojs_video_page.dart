import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/ojs_video.dart';
import '../services/video_engine_service.dart';
import '../screens/fullscreen_landscape_player.dart';
import '../screens/sound_detail_screen.dart';
import '../widgets/super_thanks_modal.dart';

class OjsVideoPage extends StatefulWidget {
  final OjsVideo video;
  final bool isVisible;
  final bool isFollowing;
  final bool isFollowingFeed;
  final bool isLiked;
  final bool isSaved;
  final VoidCallback onFollow;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onSave;

  const OjsVideoPage({
    super.key,
    required this.video,
    required this.isVisible,
    required this.isFollowing,
    required this.isFollowingFeed,
    required this.isLiked,
    this.isSaved = false,
    required this.onFollow,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.onSave,
  });

  @override
  State<OjsVideoPage> createState() => _OjsVideoPageState();
}

class _OjsVideoPageState extends State<OjsVideoPage> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInit = false;
  bool _isPlaying = true;
  late bool _isSavedLocal;

  // Double Tap Heart Animation
  bool _showHeartAnim = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  // Scrubbing & Timeline Tracking
  bool _isScrubbing = false;
  double _scrubPosition = 0.0;

  // 2X Speed on Long Press
  bool _isSpeedBoosted = false;

  @override
  void initState() {
    super.initState();
    _isSavedLocal = widget.isSaved;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.25).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    if (widget.isVisible) {
      _loadAndPlay();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OjsVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSaved != oldWidget.isSaved) {
      _isSavedLocal = widget.isSaved;
    }
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _loadAndPlay();
      } else {
        _controller?.pause();
        _isPlaying = false;
        _resetSpeed();
      }
    }
  }

  Future<void> _loadAndPlay() async {
    final ctrl = await VideoEngineService.instance.getOrCreateController(widget.video.videoUrl);
    if (!mounted) return;
    setState(() {
      _controller = ctrl;
      _isInit = ctrl.value.isInitialized;
      _isPlaying = true;
    });
    if (_isInit && widget.isVisible) {
      await ctrl.setPlaybackSpeed(1.0);
      await ctrl.play();
    }
  }

  void _togglePlayPause() {
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

  void _handleDoubleTap() {
    if (!widget.isLiked) {
      widget.onLike();
    }
    setState(() => _showHeartAnim = true);
    _animController.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _showHeartAnim = false);
      });
    });
  }

  void _start2xSpeed() {
    if (_controller == null || !_isInit) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSpeedBoosted = true);
    _controller?.setPlaybackSpeed(2.0);
  }

  void _resetSpeed() {
    if (_isSpeedBoosted && _controller != null && _isInit) {
      setState(() => _isSpeedBoosted = false);
      _controller?.setPlaybackSpeed(1.0);
    }
  }

  void _openSoundHub() {
    SoundDetailScreen.open(
      context,
      soundTitle: 'Original Audio - ${widget.video.creator}',
      creatorName: widget.video.creator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = _isInit && _controller != null && _controller!.value.aspectRatio > 1.2;

    return Container(
      color: Colors.black,
      child: GestureDetector(
        onTap: _togglePlayPause,
        onDoubleTap: _handleDoubleTap,
        onLongPressStart: (_) => _start2xSpeed(),
        onLongPressEnd: (_) => _resetSpeed(),
        onLongPressCancel: () => _resetSpeed(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Center Video Engine
            if (_isInit && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: isLandscape ? _controller!.value.aspectRatio : 9 / 16,
                  child: ColorFiltered(
                    colorFilter: VideoEngineService.superResolutionEnhancer,
                    child: FittedBox(
                      fit: isLandscape ? BoxFit.contain : BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30),
                ),
              ),

            // 2. Play/Pause Big Center Indicator
            if (!_isPlaying && _isInit)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 54),
                ),
              ),

            // 3. Double Tap Heart Pop Animation
            if (_showHeartAnim)
              Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFEF4444),
                    size: 110,
                  ),
                ),
              ),

            // 4. 2X Playback Speed Top Minimal Banner
            if (_isSpeedBoosted)
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fast_forward_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '2X Speed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 5. TikTok 16:9 Landscape Fullscreen Button
            if (isLandscape)
              Positioned(
                bottom: 180,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      FullscreenLandscapePlayer.open(
                        context,
                        videoUrl: widget.video.videoUrl,
                        title: widget.video.caption,
                        creator: widget.video.creator,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.screen_rotation_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Full screen (Rotate)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 6. Right Action Rail
            Positioned(
              right: 10,
              bottom: 84,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: CircleAvatar(
                          radius: 21,
                          backgroundColor: const Color(0xFF111827),
                          child: Text(
                            widget.video.creator.isNotEmpty ? widget.video.creator[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      if (!widget.isFollowing)
                        Positioned(
                          bottom: -6,
                          child: GestureDetector(
                            onTap: widget.onFollow,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 13),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildActionButton(
                    icon: widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: '${widget.video.likes}',
                    color: widget.isLiked ? const Color(0xFFEF4444) : Colors.white,
                    onTap: widget.onLike,
                  ),
                  const SizedBox(height: 12),

                  _buildActionButton(
                    icon: Icons.mode_comment_rounded,
                    label: '${widget.video.comments}',
                    color: Colors.white,
                    onTap: widget.onComment,
                  ),
                  const SizedBox(height: 12),

                  _buildActionButton(
                    icon: Icons.stars_rounded,
                    label: 'Thanks',
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      SuperThanksModal.show(context, creatorName: widget.video.creator);
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildActionButton(
                    icon: _isSavedLocal ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    label: 'Save',
                    color: _isSavedLocal ? const Color(0xFFF59E0B) : Colors.white,
                    onTap: () {
                      setState(() => _isSavedLocal = !_isSavedLocal);
                      if (widget.onSave != null) {
                        widget.onSave!();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_isSavedLocal ? 'Video saved to profile!' : 'Removed from bookmarks.'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildActionButton(
                    icon: Icons.reply_rounded,
                    label: 'Share',
                    color: Colors.white,
                    onTap: widget.onShare,
                  ),
                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: _openSoundHub,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1F2937),
                        border: Border.all(color: Colors.white38, width: 2.5),
                      ),
                      child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            // 7. Bottom Metadata
            Positioned(
              left: 14,
              bottom: 84,
              right: 84,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '@${widget.video.creator}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 14),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.video.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _openSoundHub,
                    child: Row(
                      children: [
                        const Icon(Icons.music_note_rounded, color: Colors.white70, size: 13),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Original Audio - ${widget.video.creator} • OJAS Sound Studio',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 8. Interactive Timeline Video Scrubber (Bottom Line)
            if (_isInit && _controller != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 60,
                child: ValueListenableBuilder(
                  valueListenable: _controller!,
                  builder: (context, VideoPlayerValue val, child) {
                    final duration = val.duration.inMilliseconds.toDouble();
                    final position = val.position.inMilliseconds.toDouble();
                    final currentVal = _isScrubbing ? _scrubPosition : (duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0);

                    return GestureDetector(
                      onHorizontalDragStart: (details) {
                        setState(() {
                          _isScrubbing = true;
                          _controller?.pause();
                        });
                      },
                      onHorizontalDragUpdate: (details) {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final relative = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                        setState(() {
                          _scrubPosition = relative;
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        if (duration > 0) {
                          final targetMs = (_scrubPosition * duration).toInt();
                          _controller?.seekTo(Duration(milliseconds: targetMs));
                        }
                        setState(() {
                          _isScrubbing = false;
                          _controller?.play();
                        });
                      },
                      child: Container(
                        height: 14,
                        color: Colors.transparent,
                        alignment: Alignment.bottomCenter,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: _isScrubbing ? 4 : 2,
                              color: Colors.white24,
                            ),
                            FractionallySizedBox(
                              widthFactor: currentVal,
                              child: Container(
                                height: _isScrubbing ? 4 : 2,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
