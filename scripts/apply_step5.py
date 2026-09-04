from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'marker not found in {path}: {old[:80]!r}')
    p.write_text(text.replace(old, new, 1))


# Feed -> Creator Hub route.
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

# Action rail avatar -> profile route. Keep follow badge tap behavior isolated.
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

# The profile tap wrapper needs to close its child Container before the Stack's badge.
