from pathlib import Path

ROOT = Path('.')

p = ROOT / 'lib/models/ojs_video.dart'
s = p.read_text(encoding='utf-8')
if 'final List<String> shopItemIds;' not in s:
    s = s.replace(
        '''    this.isVerified = false,\n    this.viralScore = 0.0,\n  })''',
        '''    this.isVerified = false,\n    this.viralScore = 0.0,\n    this.shopItemIds = const [],\n  })''',
        1,
    )
    s = s.replace(
        '''  final bool isVerified;\n  final double viralScore;\n}''',
        '''  final bool isVerified;\n  final double viralScore;\n  final List<String> shopItemIds;\n}''',
        1,
    )
    p.write_text(s, encoding='utf-8')

p = ROOT / 'lib/screens/ojs_feed_screen.dart'
s = p.read_text(encoding='utf-8')
if "package:firebase_auth/firebase_auth.dart" not in s:
    s = s.replace(
        "import 'package:flutter/services.dart';\n",
        "import 'package:flutter/services.dart';\nimport 'package:firebase_auth/firebase_auth.dart';\n",
        1,
    )
if "../services/engagement_service.dart" not in s:
    s = s.replace(
        "import '../services/reel_feed_service.dart';\n",
        "import '../services/reel_feed_service.dart';\nimport '../services/engagement_service.dart';\n",
        1,
    )
if "../widgets/reel_comments_bottom_sheet.dart" not in s:
    s = s.replace(
        "import '../widgets/ojs_video_page.dart';\n",
        "import '../widgets/ojs_video_page.dart';\nimport '../widgets/reel_comments_bottom_sheet.dart';\n",
        1,
    )
if '_engagementService' not in s:
    s = s.replace(
        "  final ReelFeedService _reelFeedService = ReelFeedService();\n",
        "  final ReelFeedService _reelFeedService = ReelFeedService();\n  final EngagementService _engagementService = EngagementService();\n",
        1,
    )
if '_likeDeltas' not in s:
    s = s.replace(
        "  final List<ReelModel> _forYouReels = <ReelModel>[];\n",
        "  final List<ReelModel> _forYouReels = <ReelModel>[];\n  final Map<String, int> _likeDeltas = <String, int>{};\n",
        1,
    )
if 'likes: reel.likes + (_likeDeltas[reel.id] ?? 0),' not in s:
    s = s.replace('      likes: reel.likes,\n', '      likes: reel.likes + (_likeDeltas[reel.id] ?? 0),\n', 1)
if 'shopItemIds: reel.shopItemIds,' not in s:
    s = s.replace('      viralScore: reel.algorithmScore,\n', '      viralScore: reel.algorithmScore,\n      shopItemIds: reel.shopItemIds,\n', 1)

if 'Future<void> _openComments(String reelId)' not in s:
    old = '''  void _toggleLikeVideo(String videoId) {\n    HapticFeedback.mediumImpact();\n    setState(() {\n      if (_likedVideos.contains(videoId)) {\n        _likedVideos.remove(videoId);\n      } else {\n        _likedVideos.add(videoId);\n      }\n    });\n  }'''
    new = '''  void _toggleLikeVideo(String videoId) {\n    HapticFeedback.mediumImpact();\n    final shouldLike = !_likedVideos.contains(videoId);\n    setState(() {\n      if (shouldLike) {\n        _likedVideos.add(videoId);\n      } else {\n        _likedVideos.remove(videoId);\n      }\n      for (final reel in _forYouReels) {\n        if (reel.id == videoId) {\n          _likeDeltas[videoId] = (_likeDeltas[videoId] ?? 0) + (shouldLike ? 1 : -1);\n          break;\n        }\n      }\n    });\n    for (final reel in _forYouReels) {\n      if (reel.id == videoId) {\n        _engagementService.syncInteraction(\n          reelId: videoId,\n          liked: shouldLike,\n          saved: _savedVideos.contains(videoId),\n        );\n        break;\n      }\n    }\n  }\n\n  Future<void> _openComments(String reelId) async {\n    if (_isCommentsOpen) return;\n    setState(() => _isCommentsOpen = true);\n    try {\n      await ReelCommentsBottomSheet.show(context, reelId: reelId);\n    } finally {\n      if (mounted) setState(() => _isCommentsOpen = false);\n    }\n  }'''
    if s.count(old) != 1:
        raise SystemExit('Like method anchor mismatch')
    s = s.replace(old, new, 1)

old = '''  void _toggleSaveVideo(String videoId) {\n    HapticFeedback.selectionClick();\n    setState(() {\n      if (_savedVideos.contains(videoId)) {\n        _savedVideos.remove(videoId);\n        ScaffoldMessenger.of(context).showSnackBar(\n          const SnackBar(content: Text('Removed from Saved'), duration: Duration(seconds: 1)),\n        );\n      } else {\n        _savedVideos.add(videoId);\n        ScaffoldMessenger.of(context).showSnackBar(\n          const SnackBar(content: Text('Saved 🔖'), duration: Duration(seconds: 1)),\n        );\n      }\n    });\n  }'''
new = '''  void _toggleSaveVideo(String videoId) {\n    HapticFeedback.selectionClick();\n    final shouldSave = !_savedVideos.contains(videoId);\n    setState(() {\n      if (shouldSave) {\n        _savedVideos.add(videoId);\n        ScaffoldMessenger.of(context).showSnackBar(\n          const SnackBar(content: Text('Saved 🔖'), duration: Duration(seconds: 1)),\n        );\n      } else {\n        _savedVideos.remove(videoId);\n        ScaffoldMessenger.of(context).showSnackBar(\n          const SnackBar(content: Text('Removed from Saved'), duration: Duration(seconds: 1)),\n        );\n      }\n    });\n    for (final reel in _forYouReels) {\n      if (reel.id == videoId) {\n        _engagementService.syncInteraction(\n          reelId: videoId,\n          liked: _likedVideos.contains(videoId),\n          saved: shouldSave,\n        );\n        break;\n      }\n    }\n  }'''
if s.count(old) == 1:
    s = s.replace(old, new, 1)

old = '''            if (_isCommentsOpen)\n              Positioned(\n                bottom: 0,\n                left: 0,\n                right: 0,\n                height: MediaQuery.of(context).size.height * 0.60,\n                child: _buildCommentSheet(),\n              ),\n'''
if old in s:
    s = s.replace(old, '', 1)

s = s.replace('            onComment: _toggleComments,\n', '            onComment: () => _openComments(video.id),\n')
p.write_text(s, encoding='utf-8')

p = ROOT / 'lib/widgets/ojs_video_page.dart'
s = p.read_text(encoding='utf-8')
if "reel_shop_products_bottom_sheet.dart" not in s:
    s = s.replace(
        "import '../widgets/ojas_shop_sheet.dart'; // 🚀 Zero-Cost Affiliate E-Commerce\n",
        "import 'reel_shop_products_bottom_sheet.dart';\n",
        1,
    )
s = s.replace(
    '''    if (!widget.isLiked) {\n      widget.onLike();\n    }''',
    '''    widget.onLike();''',
    1,
)
if 'label: \'Shop\'' in s:
    start = s.index('                  // 🛍️ OJAS Shop Button')
    end = s.index('                  _buildActionButton(', start)
    # The first action button after this block is the Like button; remove only the fake shop block.
    s = s[:start] + s[end:]
if 'widget.video.shopItemIds.isNotEmpty' not in s:
    anchor = '''                children: [\n                  Row(\n                    children: [\n                      Text(\n                        '@${widget.video.creator}',\n'''
    insert = '''                children: [\n                  if (widget.video.shopItemIds.isNotEmpty)\n                    Padding(\n                      padding: const EdgeInsets.only(bottom: 8),\n                      child: GestureDetector(\n                        onTap: () {\n                          HapticFeedback.lightImpact();\n                          ReelShopProductsBottomSheet.show(\n                            context,\n                            shopItemIds: widget.video.shopItemIds,\n                          );\n                        },\n                        child: Container(\n                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),\n                          decoration: BoxDecoration(\n                            color: const Color(0xFFF5B942).withValues(alpha: 0.94),\n                            borderRadius: BorderRadius.circular(18),\n                          ),\n                          child: const Row(\n                            mainAxisSize: MainAxisSize.min,\n                            children: [\n                              Icon(Icons.shopping_bag_rounded, color: Colors.black, size: 15),\n                              SizedBox(width: 6),\n                              Text('Shop Products', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),\n                              SizedBox(width: 4),\n                              Icon(Icons.chevron_right_rounded, color: Colors.black, size: 16),\n                            ],\n                          ),\n                        ),\n                      ),\n                    ),\n                  Row(\n                    children: [\n                      Text(\n                        '@${widget.video.creator}',\n'''
    if s.count(anchor) != 1:
        raise SystemExit('Metadata anchor mismatch')
    s = s.replace(anchor, insert, 1)
p.write_text(s, encoding='utf-8')
