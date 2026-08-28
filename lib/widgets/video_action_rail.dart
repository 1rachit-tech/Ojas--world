import 'package:flutter/material.dart';

class VideoActionRail extends StatelessWidget {
  const VideoActionRail({
    required this.creator,
    required this.avatarColor,
    required this.isFollowing,
    required this.isFollowingFeed,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.isLiked,
    required this.onFollow,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMore,
    super.key,
  });

  final String creator;
  final int avatarColor;
  final bool isFollowing;
  final bool isFollowingFeed;
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;
  final VoidCallback onFollow;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 58,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Color(avatarColor),
                child: Text(
                  creator.substring(0, 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                bottom: -1,
                child: GestureDetector(
                  onTap: onFollow,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isFollowing
                          ? const Color(0xff27323a)
                          : const Color(0xfff5b942),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: SizedBox(
                      width: 19,
                      height: 19,
                      child: Icon(
                        isFollowing
                            ? (isFollowingFeed
                                  ? Icons.remove_rounded
                                  : Icons.check_rounded)
                            : Icons.add_rounded,
                        size: 14,
                        color: isFollowing ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ActionButton(
          icon: isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          count: likes,
          color: isLiked ? const Color(0xffff7185) : Colors.white,
          onTap: onLike,
          tooltip: 'Like',
        ),
        _ActionButton(
          icon: Icons.mode_comment_outlined,
          count: comments,
          onTap: onComment,
          tooltip: 'Comments',
        ),
        _ActionButton(
          icon: Icons.reply_rounded,
          count: shares,
          onTap: onShare,
          tooltip: 'Share',
        ),
        IconButton(
          onPressed: onMore,
          tooltip: 'More video options',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.count,
    required this.onTap,
    required this.tooltip,
    this.color = Colors.white,
  });

  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: color, size: 27),
        ),
        Text(
          _compactCount(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  String _compactCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}
