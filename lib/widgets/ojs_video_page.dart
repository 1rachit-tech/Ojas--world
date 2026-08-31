import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/ojs_video.dart';
import 'video_action_rail.dart';

class OjsVideoPage extends StatefulWidget {
  const OjsVideoPage({
    required this.video,
    required this.isVisible,
    required this.isFollowing,
    required this.isFollowingFeed,
    required this.isLiked,
    required this.onFollow,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    super.key,
  });

  final OjsVideo video;
  final bool isVisible;
  final bool isFollowing;
  final bool isFollowingFeed;
  final bool isLiked;
  final VoidCallback onFollow;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  @override
  State<OjsVideoPage> createState() => _OjsVideoPageState();
}

class _OjsVideoPageState extends State<OjsVideoPage> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _captionExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant OjsVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.videoUrl != widget.video.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isLoading = true;
      _hasError = false;
      _initializeVideo();
    } else if (oldWidget.isVisible != widget.isVisible) {
      _setPlayback(widget.isVisible);
    }
  }

  Future<void> _initializeVideo() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
      );
      _controller = controller;
      controller.addListener(_handleControllerUpdate);
      await controller.initialize().timeout(const Duration(seconds: 15));
      await controller.setLooping(true);
      if (!mounted || _controller != controller) return;
      setState(() => _isLoading = false);
      await _setPlayback(widget.isVisible);
    } catch (error) {
      debugPrint('OJS video failed to initialize: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _handleControllerUpdate() {
    final controller = _controller;
    final errorDescription = controller?.value.errorDescription;
    if (errorDescription == null) return;
    debugPrint('OJS video player error: $errorDescription');
    if (!mounted || _hasError) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  Future<void> _setPlayback(bool shouldPlay) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (shouldPlay) {
      await controller.play();
    } else {
      await controller.pause();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ColoredBox(
      color: const Color(0xff07090b),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. FULL-SCREEN VIDEO PLAYER
          if (controller != null && controller.value.isInitialized)
            GestureDetector(
              onTap: () => _setPlayback(!controller.value.isPlaying),
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            )
          else
            _buildVideoState(),

          // 2. GRADIENT OVERLAY
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .30),
                    Colors.transparent,
                    Colors.black.withValues(alpha: .60),
                  ],
                  stops: const [0, .45, 1],
                ),
              ),
            ),
          ),

          // 3. TITLE & CAPTION (BOTTOM LEFT - EXACT POSITION)
          Positioned(
            left: 16,
            bottom: 16,
            right: 80,
            child: _buildCaption(),
          ),

          // 4. ACTION RAIL (BOTTOM RIGHT - EXACT POSITION)
          Positioned(
            right: 8,
            bottom: 12,
            child: VideoActionRail(
              creator: widget.video.creator,
              avatarColor: widget.video.avatarColor,
              isFollowing: widget.isFollowing,
              isFollowingFeed: widget.isFollowingFeed,
              isLiked: widget.isLiked,
              likes: widget.video.likes + (widget.isLiked ? 1 : 0),
              comments: widget.video.comments,
              shares: widget.video.shares,
              onFollow: widget.onFollow,
              onLike: widget.onLike,
              onComment: widget.onComment,
              onShare: widget.onShare,
              onMore: _showVideoMenu,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoState() {
    if (_hasError) {
      return Center(
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
            _initializeVideo();
          },
          icon: const Icon(Icons.refresh_rounded, color: Color(0xfff5b942)),
          label: const Text(
            'Video unavailable. Retry',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return Center(
      child: _isLoading
          ? const CircularProgressIndicator(
              color: Color(0xfff5b942),
              strokeWidth: 2,
            )
          : const Icon(
              Icons.play_circle_outline_rounded,
              color: Colors.white54,
              size: 52,
            ),
    );
  }

  Widget _buildCaption() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.video.creator,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _captionExpanded = !_captionExpanded),
          child: Text(
            widget.video.caption,
            maxLines: _captionExpanded ? 5 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
        if (!_captionExpanded && widget.video.caption.length > 70)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              '...more',
              style: TextStyle(color: Color(0xfff5b942), fontSize: 12),
            ),
          ),
      ],
    );
  }

  void _showVideoMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff171c21),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark_border, color: Colors.white),
              title: const Text('Save video'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined, color: Colors.white),
              title: const Text('Not interested'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.white),
              title: const Text('Report'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
