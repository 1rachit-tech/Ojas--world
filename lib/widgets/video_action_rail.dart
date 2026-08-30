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
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              CircleAvatar(
                radius: 18,
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
                bottom: 0,
                child: _FollowButton(isFollowing: isFollowing, onTap: onFollow),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _ActionButton(
          icon: isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          count: likes,
          color: isLiked ? const Color(0xffff7185) : Colors.white,
          onTap: onLike,
          tooltip: 'Like',
        ),
        const SizedBox(height: 8),
        _ActionButton(
          icon: Icons.mode_comment_outlined,
          count: comments,
          onTap: onComment,
          tooltip: 'Comments',
        ),
        const SizedBox(height: 8),
        _ActionButton(
          icon: Icons.reply_rounded,
          count: shares,
          onTap: onShare,
          tooltip: 'Share',
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 44,
          height: 28,
          child: IconButton(
            onPressed: onMore,
            tooltip: 'More video options',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        const _AudioDisc(),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isFollowing, required this.onTap});

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 24,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isFollowing
                  ? const Color(0xff27323a)
                  : const Color(0xfff5b942),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: SizedBox(
              width: 20,
              height: 20,
              child: Icon(
                isFollowing ? Icons.remove_rounded : Icons.add_rounded,
                size: 13,
                color: isFollowing ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioDisc extends StatefulWidget {
  const _AudioDisc();

  @override
  State<_AudioDisc> createState() => _AudioDiscState();
}

class _AudioDiscState extends State<_AudioDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: RotationTransition(
          turns: _controller,
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xff15191d),
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: Colors.white54, width: 1),
              ),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Color(0xfff5b942),
              size: 14,
            ),
          ),
        ),
      ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 30,
          child: IconButton(
            onPressed: onTap,
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            icon: Icon(icon, color: color, size: 25),
          ),
        ),
        Text(
          _compactCount(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _compactCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}
