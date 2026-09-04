from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'marker not found in {path}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1))


# Keep the pre-existing CreatorProfileScreen call sites source-compatible while
# upgrading the screen to the Creator Hub contract used by the feed.
replace_once(
    'lib/screens/creator_profile_screen.dart',
    "class CreatorProfileScreen extends StatefulWidget {\n  const CreatorProfileScreen({\n    super.key,\n    required this.creatorId,\n    required this.username,\n    this.isFollowing = false,\n    this.initialFollowers = 0,\n    this.initialFollowing = 0,\n    this.initialLikes = 0,\n    this.onFollowChanged,\n  });\n\n  final String creatorId;\n  final String username;\n",
    "class CreatorProfileScreen extends StatefulWidget {\n  const CreatorProfileScreen({\n    super.key,\n    String? creatorId,\n    String? username,\n    String? creatorName,\n    this.avatarColor = const Color(0xFFE5E7EB),\n    this.isFollowing = false,\n    this.initialFollowers = 0,\n    this.initialFollowing = 0,\n    this.initialLikes = 0,\n    this.onFollowChanged,\n  })  : creatorId = creatorId ?? '',\n        username = username ?? creatorName ?? 'OJAS Creator';\n\n  final String creatorId;\n  final String username;\n  final Color avatarColor;\n",
)
replace_once(
    'lib/screens/creator_profile_screen.dart',
    "errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.shopping_bag_rounded, color: Color(0xFFF5B942), size: 32))),\n            Padding(",
    "errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.shopping_bag_rounded, color: Color(0xFFF5B942), size: 32))),\n            ),\n            Padding(",
)
replace_once(
    'lib/screens/creator_profile_screen.dart',
    "color: const Color(0xFF111827),\n                alignment: Alignment.center,",
    "color: widget.avatarColor.withValues(alpha: 0.35),\n                alignment: Alignment.center,",
)
replace_once(
    'lib/screens/creator_profile_screen.dart',
    "color: const Color(0xFF111827),\n                  alignment: Alignment.center,",
    "color: widget.avatarColor.withValues(alpha: 0.35),\n                  alignment: Alignment.center,",
)

replace_once(
    'lib/screens/ojs_feed_screen.dart',
    "import '../screens/audio_reels_screen.dart';\n",
    "import '../screens/audio_reels_screen.dart';\nimport '../screens/creator_profile_screen.dart';\n",
)
replace_once(
    'lib/screens/ojs_feed_screen.dart',
    "            onFollow: () {\n              final next = !_followedCreators.contains(video.creator);\n              _syncFollow(video.creatorId, video.creator, next);\n            },\n            onAudio:",
    "            onFollow: () {\n              final next = !_followedCreators.contains(video.creator);\n              _syncFollow(video.creatorId, video.creator, next);\n            },\n            onProfile: () {\n              Navigator.of(context).push(\n                MaterialPageRoute<void>(\n                  builder: (_) => CreatorProfileScreen(\n                    creatorId: video.creatorId,\n                    username: video.creator,\n                    isFollowing: _followedCreators.contains(video.creator),\n                    onFollowChanged: (following) {\n                      _syncFollow(video.creatorId, video.creator, following);\n                    },\n                  ),\n                ),\n              );\n            },\n            onAudio:",
)
replace_once(
    'lib/screens/ojs_feed_screen.dart',
    "          onFollow: () {\n            final next = !_followedCreators.contains(video.creator);\n            _syncFollow(video.creatorId, video.creator, next);\n          },\n          onAudio:",
    "          onFollow: () {\n            final next = !_followedCreators.contains(video.creator);\n            _syncFollow(video.creatorId, video.creator, next);\n          },\n          onProfile: () {\n            Navigator.of(context).push(\n              MaterialPageRoute<void>(\n                builder: (_) => CreatorProfileScreen(\n                  creatorId: video.creatorId,\n                  username: video.creator,\n                  isFollowing: _followedCreators.contains(video.creator),\n                  onFollowChanged: (following) {\n                    _syncFollow(video.creatorId, video.creator, following);\n                  },\n                ),\n              ),\n            );\n          },\n          onAudio:",
)

replace_once(
    'lib/widgets/ojs_video_page.dart',
    "  final VoidCallback? onAudio;\n",
    "  final VoidCallback? onAudio;\n  final VoidCallback? onProfile;\n",
)
replace_once(
    'lib/widgets/ojs_video_page.dart',
    "    this.onAudio,\n  });",
    "    this.onAudio,\n    this.onProfile,\n  });",
)
replace_once(
    'lib/widgets/ojs_video_page.dart',
    "                      Container(\n                        padding: const EdgeInsets.all(1.5),\n                        decoration: BoxDecoration(\n",
    "                      GestureDetector(\n                        onTap: () {\n                          if (widget.onProfile == null) return;\n                          HapticFeedback.selectionClick();\n                          widget.onProfile!();\n                        },\n                        child: Container(\n                          padding: const EdgeInsets.all(1.5),\n                          decoration: BoxDecoration(\n",
)
replace_once(
    'lib/widgets/ojs_video_page.dart',
    "                        child: CircleAvatar(\n                          radius: 21,\n                          backgroundColor: const Color(0xFF111827),\n                          child: Text(\n                            widget.video.creator.isNotEmpty\n                                ? widget.video.creator[0].toUpperCase()\n                                : 'U',\n                            style: const TextStyle(\n                              color: Colors.white,\n                              fontWeight: FontWeight.bold,\n                              fontSize: 16,\n                            ),\n                          ),\n                        ),\n                      ),\n",
    "                          child: CircleAvatar(\n                            radius: 21,\n                            backgroundColor: const Color(0xFF111827),\n                            child: Text(\n                              widget.video.creator.isNotEmpty\n                                  ? widget.video.creator[0].toUpperCase()\n                                  : 'U',\n                              style: const TextStyle(\n                                color: Colors.white,\n                                fontWeight: FontWeight.bold,\n                                fontSize: 16,\n                              ),\n                            ),\n                          ),\n                        ),\n                      ),\n",
)
