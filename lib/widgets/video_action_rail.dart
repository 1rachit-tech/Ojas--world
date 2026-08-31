import 'package:flutter/material.dart';

class VideoActionRail extends StatefulWidget {
  final String creator;
  final Color avatarColor;
  final bool isFollowing;
  final bool isFollowingFeed;
  final bool isLiked;
  final int likes;
  final int comments;
  final int shares;
  final VoidCallback onFollow;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback onAudioTap;
  final VoidCallback onProfileTap;

  const VideoActionRail({
    super.key,
    required this.creator,
    required this.avatarColor,
    required this.isFollowing,
    required this.isFollowingFeed,
    required this.isLiked,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.onFollow,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMore,
    required this.onAudioTap,
    required this.onProfileTap,
  });

  @override
  State<VideoActionRail> createState() => _VideoActionRailState();
}

class _VideoActionRailState extends State<VideoActionRail>
    with TickerProviderStateMixin {
  late AnimationController _discAnim;
  late AnimationController _likeAnim;
  late Animation<double> _likeScale;

  @override
  void initState() {
    super.initState();
    // 1. Spinning Vinyl Audio Disc Animation
    _discAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // 2. Like Button Pop Animation
    _likeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeScale = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _likeAnim, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant VideoActionRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLiked && widget.isLiked) {
      _likeAnim.forward().then((_) => _likeAnim.reverse());
    }
  }

  @override
  void dispose() {
    _discAnim.dispose();
    _likeAnim.dispose();
    super.dispose();
  }

  String _formatCount(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return '$number';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Creator Avatar + Follow (+) Badge
        GestureDetector(
          onTap: widget.onProfileTap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: widget.avatarColor,
                  child: Text(
                    widget.creator.isNotEmpty ? widget.creator[0] : 'U',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              if (!widget.isFollowing && !widget.isFollowingFeed)
                Positioned(
                  bottom: -6,
                  child: GestureDetector(
                    onTap: widget.onFollow,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5B942),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, size: 13, color: Colors.black),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 2. Animated Like Action
        GestureDetector(
          onTap: () {
            _likeAnim.forward().then((_) => _likeAnim.reverse());
            widget.onLike();
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              ScaleTransition(
                scale: _likeScale,
                child: Icon(
                  widget.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: widget.isLiked ? const Color(0xFFFF5252) : Colors.white,
                  size: 30,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatCount(widget.likes),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. Comment Action
        _buildAction(
          icon: Icons.mode_comment_outlined,
          count: _formatCount(widget.comments),
          color: Colors.white,
          onTap: widget.onComment,
        ),

        const SizedBox(height: 14),

        // 4. Share Action
        _buildAction(
          icon: Icons.reply_rounded,
          count: _formatCount(widget.shares),
          color: Colors.white,
          onTap: widget.onShare,
        ),

        const SizedBox(height: 14),

        // 5. More Options (Three Dots)
        GestureDetector(
          onTap: widget.onMore,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Icon(
              Icons.more_horiz_rounded,
              color: Colors.white,
              size: 26,
              shadows: [
                Shadow(color: Colors.black54, blurRadius: 8),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 6. Spinning Vinyl Audio Disc
        GestureDetector(
          onTap: widget.onAudioTap,
          child: RotationTransition(
            turns: _discAnim,
            child: Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFF1E232B),
                    Color(0xFF38404B),
                    Color(0xFF1E232B),
                  ],
                ),
                border: Border.all(color: Colors.white38, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const CircleAvatar(
                backgroundColor: Color(0xFFF5B942),
                child: Icon(Icons.music_note_rounded, size: 16, color: Colors.black),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 8),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(color: Colors.black87, blurRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
