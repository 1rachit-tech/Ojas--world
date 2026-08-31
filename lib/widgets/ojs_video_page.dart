import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/ojs_video.dart';
import '../screens/creator_profile_screen.dart';
import '../screens/audio_detail_screen.dart';
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
      debugPrint('Video failed: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _handleControllerUpdate() {
    final controller = _controller;
    if (controller?.value.errorDescription != null && mounted && !_hasError) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
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

  Color _getAvatarColor() {
    final dynamic colorVal = widget.video.avatarColor;
    if (colorVal is Color) return colorVal;
    if (colorVal is int) return Color(colorVal);
    return const Color(0xFFF5B942);
  }

  void _openCreatorProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatorProfileScreen(
          creatorName: widget.video.creator,
          avatarColor: _getAvatarColor(),
        ),
      ),
    );
  }

  void _openAudioScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioDetailScreen(
          audioTitle: 'Original Sound - ${widget.video.creator}',
          creatorName: widget.video.creator,
        ),
      ),
    );
  }

  void _showVideoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13171D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_rounded, color: Color(0xFFF5B942)),
                title: const Text('Save to Favorites', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Video saved to bookmarks! 🔖')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Colors.white70),
                title: const Text('Download (1080p)', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Downloading video... 📥')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined, color: Colors.white70),
                title: const Text('Not Interested', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('We will show fewer videos like this.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ColoredBox(
      color: const Color(0xff07090b),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Screen Video Player
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
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Color(0xFFF5B942), strokeWidth: 2)
                  : const Icon(Icons.play_circle_outline_rounded, color: Colors.white54, size: 52),
            ),

          // 2. Gradient Overlay
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // 3. Caption & Creator Details
          Positioned(
            left: 16,
            bottom: 100,
            right: 86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _openCreatorProfile,
                  child: Text(
                    widget.video.creator,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () => setState(() => _captionExpanded = !_captionExpanded),
                  child: Text(
                    widget.video.caption,
                    maxLines: _captionExpanded ? 5 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                  ),
                ),
                if (!_captionExpanded && widget.video.caption.length > 60)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('...more', style: TextStyle(color: Color(0xFFF5B942), fontSize: 11.5)),
                  ),
              ],
            ),
          ),

          // 4. Action Rail
          Positioned(
            right: 10,
            top: 68,
            child: VideoActionRail(
              creator: widget.video.creator,
              avatarColor: _getAvatarColor(),
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
              onMore: _showVideoOptions,
              onAudioTap: _openAudioScreen,
              onProfileTap: _openCreatorProfile,
            ),
          ),
        ],
      ),
    );
  }
}
