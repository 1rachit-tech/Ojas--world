from pathlib import Path

root = Path('.')

service = root / 'lib/services/reel_feed_service.dart'
service.parent.mkdir(parents=True, exist_ok=True)
service.write_text(
    '''import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reel_model.dart';

class ReelFeedService {
  ReelFeedService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int pageSize = 5;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reels =>
      _firestore.collection('reels');

  Future<ReelFeedPage> fetchPage({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    Query<Map<String, dynamic>> query = _reels
        .orderBy('algorithmScore', descending: true)
        .limit(pageSize);

    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;

    return ReelFeedPage(
      reels: docs.map(ReelModel.fromFirestore).toList(growable: false),
      cursor: docs.isEmpty ? cursor : docs.last,
      hasMore: docs.length == pageSize,
    );
  }
}

class ReelFeedPage {
  const ReelFeedPage({
    required this.reels,
    required this.cursor,
    required this.hasMore,
  });

  final List<ReelModel> reels;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}
''',
    encoding='utf-8',
)

p = root / 'lib/screens/ojs_feed_screen.dart'
s = p.read_text(encoding='utf-8')

replacements = [
    (
        "import 'package:flutter/services.dart';\nimport '../models/ojs_video.dart';\n",
        "import 'package:flutter/services.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';\nimport '../models/ojs_video.dart';\nimport '../models/reel_model.dart';\n",
        'imports',
    ),
    (
        "import '../services/video_engine_service.dart';\n",
        "import '../services/video_engine_service.dart';\nimport '../services/reel_feed_service.dart';\n",
        'service import',
    ),
]
for old, new, label in replacements:
    if s.count(old) != 1:
        raise SystemExit(f'{label} anchor mismatch')
    s = s.replace(old, new, 1)

old = '''  final Set<String> _savedVideos = <String>{};

  int _currentSelectedFeed = 0;'''
new = '''  final Set<String> _savedVideos = <String>{};

  final ReelFeedService _reelFeedService = ReelFeedService();
  final List<ReelModel> _forYouReels = <ReelModel>[];
  DocumentSnapshot<Map<String, dynamic>>? _forYouCursor;
  bool _forYouHasMore = true;
  bool _forYouLoading = false;
  int _forYouVisibleIndex = 0;

  int _currentSelectedFeed = 0;'''
if s.count(old) != 1:
    raise SystemExit('state field anchor mismatch')
s = s.replace(old, new, 1)

old = '''  @override
  void initState() {
    super.initState();
    // पहली बार ऐप खुलते ही अगले वीडियो लोड होने लगें
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchUpcoming(_forYouCurrentIndex, temporaryOjsVideos);
    });
  }'''
new = '''  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialForYouReels();
    });
  }

  Future<void> _loadInitialForYouReels() async {
    if (_forYouLoading) return;
    setState(() => _forYouLoading = true);
    try {
      final page = await _reelFeedService.fetchPage();
      if (!mounted) return;
      setState(() {
        _forYouReels
          ..clear()
          ..addAll(page.reels);
        _forYouCursor = page.cursor;
        _forYouHasMore = page.hasMore;
        _forYouVisibleIndex = page.reels.isEmpty
            ? 0
            : (_forYouCurrentIndex < page.reels.length ? _forYouCurrentIndex : 0);
        _forYouLoading = false;
      });
      await _warmForYouReel(_forYouVisibleIndex + 1);
    } catch (error) {
      if (!mounted) return;
      setState(() => _forYouLoading = false);
      debugPrint('OJAS For You feed load failed: $error');
    }
  }

  Future<void> _fetchMoreForYouReels() async {
    if (_forYouLoading || !_forYouHasMore || _forYouReels.isEmpty) {
      return;
    }
    _forYouLoading = true;
    try {
      final page = await _reelFeedService.fetchPage(cursor: _forYouCursor);
      if (!mounted) return;
      setState(() {
        _forYouReels.addAll(page.reels);
        _forYouCursor = page.cursor;
        _forYouHasMore = page.hasMore;
        _forYouLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      _forYouLoading = false;
      debugPrint('OJAS For You next page failed: $error');
    }
  }

  OjsVideo _toOjsVideo(ReelModel reel) {
    return OjsVideo(
      id: reel.id,
      creator: reel.creatorId,
      caption: reel.caption,
      videoUrl: reel.hlsUrl,
      avatarColor: 0xff5d8f8b,
      likes: reel.likes,
      comments: reel.comments,
      shares: reel.shares,
      tags: const <String>[],
      products: const <Map<String, dynamic>>[],
      isVerified: false,
      viralScore: reel.algorithmScore,
    );
  }

  Future<void> _warmForYouReel(int index) async {
    if (index < 0 || index >= _forYouReels.length) return;
    final url = _forYouReels[index].hlsUrl;
    if (url.trim().isEmpty) return;
    try {
      await VideoEngineService.instance.getOrCreateController(url);
    } catch (error) {
      debugPrint('OJAS JIT HLS warm failed for ${_forYouReels[index].id}: $error');
    }
  }

  void _setForYouVisibleIndex(int index) {
    if (_forYouVisibleIndex == index || !mounted) return;
    setState(() => _forYouVisibleIndex = index);
  }

  bool _handleForYouScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _setForYouVisibleIndex(-1);
      return false;
    }

    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      final page = _forYouController.hasClients ? _forYouController.page : null;
      if (page != null) {
        final nearest = page.round();
        if ((page - nearest).abs() > 0.001) {
          _setForYouVisibleIndex(-1);
          final target = page > _forYouCurrentIndex
              ? _forYouCurrentIndex + 1
              : _forYouCurrentIndex - 1;
          _warmForYouReel(target);
        }
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      final page = _forYouController.hasClients ? _forYouController.page : null;
      if (page != null) {
        final settledIndex = page.round();
        if ((page - settledIndex).abs() < 0.001) {
          _setForYouVisibleIndex(settledIndex);
          if (settledIndex != _forYouCurrentIndex) {
            setState(() => _forYouCurrentIndex = settledIndex);
          }
          _warmForYouReel(settledIndex + 1);
        }
      }
    }

    return false;
  }'''
if s.count(old) != 1:
    raise SystemExit('initState anchor mismatch')
s = s.replace(old, new, 1)

old = '''  Widget _buildForYouFeed() {
    final videos = temporaryOjsVideos;
    return PageView.builder(
      controller: _forYouController,
      scrollDirection: Axis.vertical,
      physics: _isCommentsOpen ? const NeverScrollableScrollPhysics() : const OjasZeroJankScrollPhysics(), // 🚀 120 FPS Vertical Swipe
      itemCount: videos.length,
      onPageChanged: (index) {
        setState(() => _forYouCurrentIndex = index);
        _prefetchUpcoming(index, videos); // 🚀 Next Video 0-Buffer Preload
      },
      itemBuilder: (context, index) {
        final video = videos[index];
        final bool isVideoVisible = widget.isActive &&
            _currentSelectedFeed == 0 &&
            _forYouCurrentIndex == index;

        return OjsVideoPage(
          video: video,
          isVisible: isVideoVisible,
          isFollowing: _followedCreators.contains(video.creator),
          isFollowingFeed: false,
          isLiked: _likedVideos.contains(video.id),
          isSaved: _savedVideos.contains(video.id),
          onFollow: () => _toggleFollowCreator(video.creator),
          onLike: () => _toggleLikeVideo(video.id),
          onComment: _toggleComments,
          onSave: () => _toggleSaveVideo(video.id),
          onShare: () {
            ShareBottomSheet.show(
              context,
              videoUrl: video.videoUrl,
              creatorName: video.creator,
            );
          },
        );
      },
    );
  }'''
new = '''  Widget _buildForYouFeed() {
    final videos = _forYouReels.isEmpty
        ? temporaryOjsVideos
        : _forYouReels.map(_toOjsVideo).toList(growable: false);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleForYouScrollNotification,
      child: PageView.builder(
        controller: _forYouController,
        scrollDirection: Axis.vertical,
        physics: _isCommentsOpen
            ? const NeverScrollableScrollPhysics()
            : const OjasZeroJankScrollPhysics(),
        itemCount: videos.length,
        onPageChanged: (index) {
          setState(() => _forYouCurrentIndex = index);
          if (_forYouReels.isNotEmpty && index >= _forYouReels.length - 2) {
            _fetchMoreForYouReels();
          }
        },
        itemBuilder: (context, index) {
          final video = videos[index];
          final bool isVideoVisible = widget.isActive &&
              _currentSelectedFeed == 0 &&
              _forYouVisibleIndex == index;

          return OjsVideoPage(
            video: video,
            isVisible: isVideoVisible,
            isFollowing: _followedCreators.contains(video.creator),
            isFollowingFeed: false,
            isLiked: _likedVideos.contains(video.id),
            isSaved: _savedVideos.contains(video.id),
            onFollow: () => _toggleFollowCreator(video.creator),
            onLike: () => _toggleLikeVideo(video.id),
            onComment: _toggleComments,
            onSave: () => _toggleSaveVideo(video.id),
            onShare: () {
              ShareBottomSheet.show(
                context,
                videoUrl: video.videoUrl,
                creatorName: video.creator,
              );
            },
          );
        },
      ),
    );
  }'''
if s.count(old) != 1:
    raise SystemExit('For You feed method mismatch')
s = s.replace(old, new, 1)

old = '''  Widget _buildCommentSheet() {
    final activeVideos = _currentSelectedFeed == 0
        ? temporaryOjsVideos
        : temporaryOjsVideos
            .where((video) => _followedCreators.contains(video.creator))
            .toList();'''
new = '''  Widget _buildCommentSheet() {
    final activeVideos = _currentSelectedFeed == 0
        ? (_forYouReels.isEmpty
            ? temporaryOjsVideos
            : _forYouReels.map(_toOjsVideo).toList(growable: false))
        : temporaryOjsVideos
            .where((video) => _followedCreators.contains(video.creator))
            .toList();'''
if s.count(old) != 1:
    raise SystemExit('comment sheet anchor mismatch')
s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')
