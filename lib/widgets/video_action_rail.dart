import 'package:flutter/material.dart';

class VideoActionRail extends StatefulWidget {
  final String creator;
  final Color avatarColor;
  final bool isFollowing;
  final bool isFollowingFeed;
  final bool isLiked;
  final bool isSaved;
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
  final VoidCallback onSave;

  const VideoActionRail({
    super.key,
    required this.creator,
    required this.avatarColor,
    required this.isFollowing,
    required this.isFollowingFeed,
    required this.isLiked,
    required this.isSaved,
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
    required this.onSave,
  });

  @override
  State<VideoActionRail> createState() => _VideoActionRailState();
}

class _VideoActionRailState extends State<VideoActionRail>
    with SingleTickerProviderStateMixin {
  late AnimationController _discAnim;

  @override
  void initState() {
    super.initState();
    _discAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _discAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: widget.onProfileTap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: widget.avatarColor,
                child: Text(
                  widget.creator.isNotEmpty ? widget.creator[0] : 'U',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Positioned(
                bottom: -6,
                child: GestureDetector(
                  onTap: widget.onFollow,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: widget.isFollowing
                          ? const Color(0xFF27323A)
                          : const Color(0xFFF5B942),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Icon(
                      widget.isFollowing ? Icons.remove : Icons.add,
                      size: 12,
                      color: widget.isFollowing ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildAction(
          icon: widget.isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          count: _formatCount(widget.likes),
          color: widget.isLiked ? const Color(0xFFFF5252) : Colors.white,
          onTap: widget.onLike,
        ),
        const SizedBox(height: 14),
        _buildAction(
          icon: Icons.mode_comment_outlined,
          count: _formatCount(widget.comments),
          color: Colors.white,
          onTap: widget.onComment,
        ),
        const SizedBox(height: 14),
        _buildAction(
          icon: widget.isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          count: 'Save',
          color: widget.isSaved ? const Color(0xFFF5B942) : Colors.white,
          onTap: widget.onSave,
        ),
        const SizedBox(height: 14),
        _buildAction(
          icon: Icons.reply_rounded,
          count: _formatCount(widget.shares),
          color: Colors.white,
          onTap: widget.onShare,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: widget.onMore,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Icon(Icons.more_horiz_rounded, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: widget.onAudioTap,
          child: RotationTransition(
            turns: _discAnim,
            child: Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF222831),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: const CircleAvatar(
                backgroundColor: Color(0xFFF5B942),
                child: Icon(Icons.music_note_rounded, size: 13, color: Colors.black),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCount(int value) {
    if (value > 999999) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value > 999) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }

  Widget _buildAction({
    required IconData icon,
    required String count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 2),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
