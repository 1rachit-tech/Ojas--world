import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/ojs_video.dart';
import '../services/video_engine_service.dart';
import '../screens/fullscreen_landscape_player.dart';
import '../widgets/super_thanks_modal.dart';

class OjsVideoPage extends StatefulWidget {
  final OjsVideo video;
  final bool isVisible;
  final bool isFollowing;
  final bool isFollowingFeed;
  final bool isLiked;
  final VoidCallback onFollow;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const OjsVideoPage({
    super.key,
    required this.video,
    required this.isVisible,
    required this.isFollowing,
    required this.isFollowingFeed,
    required this.isLiked,
    required this.onFollow,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  State<OjsVideoPage> createState() => _OjsVideoPageState();
}

class _OjsVideoPageState extends State<OjsVideoPage> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInit = false;
  bool _isPlaying = true;
  bool _isSaved = false;

  // Double Tap Heart Animation
  bool _showHeartAnim = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.2).animate(
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
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _loadAndPlay();
      } else {
        _controller?.pause();
        _isPlaying = false;
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
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _showHeartAnim = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = _isInit && _controller != null && _controller!.value.aspectRatio > 1.2;

    return Container(
      color: Colors.black,
      child: GestureDetector(
        onTap: _togglePlayPause,
        onDoubleTap: _handleDoubleTap,
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

            // 4. TikTok 16:9 Landscape Fullscreen Mode Button
            if (isLandscape)
              Positioned(
                bottom: 130,
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

            // 5. Right Action Rail (Avatar, Like, Comment, Thanks, Save, Share)
            Positioned(
              right: 12,
              bottom: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile Avatar + Follow Badge
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
                          bottom: -7,
                          child: GestureDetector(
                            onTap: widget.onFollow,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Like
                  _buildActionButton(
                    icon: widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: '${widget.video.likes}',
                    color: widget.isLiked ? const Color(0xFFEF4444) : Colors.white,
                    onTap: widget.onLike,
                  ),
                  const SizedBox(height: 14),

                  // Comment
                  _buildActionButton(
                    icon: Icons.mode_comment_rounded,
                    label: '${widget.video.comments}',
                    color: Colors.white,
                    onTap: widget.onComment,
                  ),
                  const SizedBox(height: 14),

                  // Super Thanks Support
                  _buildActionButton(
                    icon: Icons.stars_rounded,
                    label: 'Thanks',
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      SuperThanksModal.show(context, creatorName: widget.video.creator);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Bookmark / Save
                  _buildActionButton(
                    icon: _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    label: 'Save',
                    color: _isSaved ? const Color(0xFFF59E0B) : Colors.white,
                    onTap: () {
                      setState(() => _isSaved = !_isSaved);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_isSaved ? 'Video saved to profile!' : 'Removed from bookmarks.'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Share
                  _buildActionButton(
                    icon: Icons.reply_rounded,
                    label: 'Share',
                    color: Colors.white,
                    onTap: widget.onShare,
                  ),
                  const SizedBox(height: 14),

                  // Rotating Vinyl Music Disc
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1F2937),
                      border: Border.all(color: Colors.white38, width: 3),
                    ),
                    child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 18),
                  ),
                ],
              ),
            ),

            // 6. Bottom Metadata (Username, Caption, Tags & Music Marquee)
            Positioned(
              left: 16,
              bottom: 24,
              right: 86,
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
                          fontSize: 15.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 15),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.video.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.music_note_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Original Audio - ${widget.video.creator} • OJAS Sound Studio',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
