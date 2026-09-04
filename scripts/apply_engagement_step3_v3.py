from pathlib import Path

ROOT = Path('.')

p = ROOT / 'lib/services/engagement_service.dart'
s = p.read_text(encoding='utf-8')
s = s.replace(
    """  Future<void> syncInteraction({
    required String reelId,
    required bool liked,
    required bool saved,
  }) async {""",
    """  Future<void> syncInteraction({
    required String reelId,
    required bool liked,
    required bool saved,
    int likeDelta = 0,
    int saveDelta = 0,
  }) async {""",
    1,
)
s = s.replace(
    """        'likes': FieldValue.increment(liked ? 1 : -1),
        'saves': FieldValue.increment(saved ? 1 : -1),""",
    """        'likes': FieldValue.increment(likeDelta),
        'saves': FieldValue.increment(saveDelta),""",
    1,
)
p.write_text(s, encoding='utf-8')

p = ROOT / 'lib/screens/ojs_feed_screen.dart'
s = p.read_text(encoding='utf-8')
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
    old = '''  void _toggleLikeVideo(String videoId) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_likedVideos.contains(videoId)) {
        _likedVideos.remove(videoId);
      } else {
        _likedVideos.add(videoId);
      }
    });
  }'''
    new = '''  void _toggleLikeVideo(String videoId) {
    HapticFeedback.mediumImpact();
    final shouldLike = !_likedVideos.contains(videoId);
    setState(() {
      if (shouldLike) {
        _likedVideos.add(videoId);
      } else {
        _likedVideos.remove(videoId);
      }
      for (final reel in _forYouReels) {
        if (reel.id == videoId) {
          _likeDeltas[videoId] = (_likeDeltas[videoId] ?? 0) + (shouldLike ? 1 : -1);
          break;
        }
      }
    });
    for (final reel in _forYouReels) {
      if (reel.id == videoId) {
        _engagementService.syncInteraction(
          reelId: videoId,
          liked: shouldLike,
          saved: _savedVideos.contains(videoId),
          likeDelta: shouldLike ? 1 : -1,
        );
        break;
      }
    }
  }

  Future<void> _openComments(String reelId) async {
    if (_isCommentsOpen) return;
    setState(() => _isCommentsOpen = true);
    try {
      await ReelCommentsBottomSheet.show(context, reelId: reelId);
    } finally {
      if (mounted) setState(() => _isCommentsOpen = false);
    }
  }'''
    if s.count(old) != 1:
        raise SystemExit('Like method anchor mismatch')
    s = s.replace(old, new, 1)

old = '''  void _toggleSaveVideo(String videoId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_savedVideos.contains(videoId)) {
        _savedVideos.remove(videoId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from Saved'), duration: Duration(seconds: 1)),
        );
      } else {
        _savedVideos.add(videoId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved 🔖'), duration: Duration(seconds: 1)),
        );
      }
    });
  }'''
new = '''  void _toggleSaveVideo(String videoId) {
    HapticFeedback.selectionClick();
    final shouldSave = !_savedVideos.contains(videoId);
    setState(() {
      if (shouldSave) {
        _savedVideos.add(videoId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved 🔖'), duration: Duration(seconds: 1)),
        );
      } else {
        _savedVideos.remove(videoId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from Saved'), duration: Duration(seconds: 1)),
        );
      }
    });
    for (final reel in _forYouReels) {
      if (reel.id == videoId) {
        _engagementService.syncInteraction(
          reelId: videoId,
          liked: _likedVideos.contains(videoId),
          saved: shouldSave,
          saveDelta: shouldSave ? 1 : -1,
        );
        break;
      }
    }
  }'''
if s.count(old) == 1:
    s = s.replace(old, new, 1)

old = '''            if (_isCommentsOpen)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.60,
                child: _buildCommentSheet(),
              ),
'''
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
    '''    if (!widget.isLiked) {
      widget.onLike();
    }''',
    '''    widget.onLike();''',
    1,
)
marker = '                  // 🛍️ OJAS Shop Button'
if marker in s:
    start = s.index(marker)
    first = s.index('                  _buildActionButton(', start)
    next_button = s.index('                  _buildActionButton(', first + 1)
    s = s[:start] + s[next_button:]
if 'widget.video.shopItemIds.isNotEmpty' not in s:
    anchor = '''                children: [
                  Row(
                    children: [
                      Text(
                        '@${widget.video.creator}',
'''
    insert = '''                children: [
                  if (widget.video.shopItemIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ReelShopProductsBottomSheet.show(
                            context,
                            shopItemIds: widget.video.shopItemIds,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5B942).withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_bag_rounded, color: Colors.black, size: 15),
                              SizedBox(width: 6),
                              Text('Shop Products', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, color: Colors.black, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Text(
                        '@${widget.video.creator}',
'''
    if s.count(anchor) != 1:
        raise SystemExit('Metadata anchor mismatch')
    s = s.replace(anchor, insert, 1)
p.write_text(s, encoding='utf-8')
