import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ojs_video.dart';
import '../models/reel_model.dart';
import '../services/reel_feed_service.dart';
import '../services/engagement_service.dart';
import '../services/video_engine_service.dart';
import '../screens/audio_reels_screen.dart';
import '../screens/creator_profile_screen.dart';
import '../widgets/ojs_video_page.dart';
import '../widgets/reel_comments_bottom_sheet.dart';
import '../widgets/ojas_scroll_physics.dart';
import '../widgets/share_bottom_sheet.dart';

class CommentItem {
  CommentItem({
    required this.id,
    required this.userName,
    required this.text,
    required this.time,
    required this.likes,
    this.isLiked = false,
    this.isSuperThanks = false,
  });

  final String id;
  final String userName;
  final String text;
  final String time;
  int likes;
  bool isLiked;
  final bool isSuperThanks;
}

class OjsFeedScreen extends StatefulWidget {
  const OjsFeedScreen({required this.isActive, super.key});

  final bool isActive;

  @override
  State<OjsFeedScreen> createState() => _OjsFeedScreenState();
}

class _OjsFeedScreenState extends State<OjsFeedScreen> {
  final PageController _horizontalFeedController = PageController();
  final PageController _forYouController = PageController();
  final PageController _followingController = PageController();
  final ReelFeedService _reelFeedService = ReelFeedService();
  final EngagementService _engagementService = EngagementService();

  final Set<String> _followedCreators = {'Rohan Mehta', 'Nia Okafor'};
  final Set<String> _notInterestedReels = <String>{};
  final Set<String> _likedVideos = <String>{};
  final Set<String> _savedVideos = <String>{};
  final Set<String> _seenReelIds = <String>{};
  final List<ReelModel> _forYouReels = <ReelModel>[];
  final Map<String, int> _likeDeltas = <String, int>{};
  final Map<String, int> _watchTimeMs = <String, int>{};
  final Map<String, bool> _completionPending = <String, bool>{};
  DateTime? _visibleSince;

  DocumentSnapshot<Map<String, dynamic>>? _forYouCursor;
  int _currentSelectedFeed = 0;
  int _forYouCurrentIndex = 0;
  int _forYouVisibleIndex = 0;
  int _followingCurrentIndex = 0;
  bool _forYouHasMore = true;
  bool _forYouLoading = false;
  bool _isCommentsOpen = false;
  bool _isSuperViewActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadInitialForYouReels(),
    );
  }

  @override
  void dispose() {
    _horizontalFeedController.dispose();
    _forYouController.dispose();
    _followingController.dispose();
    if (_forYouVisibleIndex >= 0) _flushWatchMetrics(_forYouVisibleIndex);
    super.dispose();
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
          ..addAll(page.reels.where((reel) => !_seenReelIds.contains(reel.id)));
        _forYouCursor = page.cursor;
        _forYouHasMore = page.hasMore;
        _forYouVisibleIndex = page.reels.isEmpty
            ? 0
            : (_forYouCurrentIndex < page.reels.length
                  ? _forYouCurrentIndex
                  : 0);
        _forYouLoading = false;
      });
      _markReelSeen(_forYouVisibleIndex);
      await _warmForYouReel(_forYouVisibleIndex + 1);
    } catch (error) {
      if (!mounted) return;
      setState(() => _forYouLoading = false);
      debugPrint('OJAS For You feed load failed: $error');
    }
  }

  Future<void> _fetchMoreForYouReels() async {
    if (_forYouLoading || !_forYouHasMore || _forYouReels.isEmpty) return;
    _forYouLoading = true;
    try {
      final page = await _reelFeedService.fetchPage(cursor: _forYouCursor);
      if (!mounted) return;
      setState(() {
        _forYouReels.addAll(page.reels.where((reel) => !_seenReelIds.contains(reel.id)));
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
      likes: reel.likes + (_likeDeltas[reel.id] ?? 0),
      comments: reel.comments,
      shares: reel.shares,
      tags: const <String>[],
      products: const <Map<String, dynamic>>[],
      isVerified: false,
      viralScore: reel.algorithmScore,
      shopItemIds: reel.shopItemIds,
      creatorId: reel.creatorId,
      audioTrackId: reel.audioTrackId,
    );
  }

  Future<void> _warmForYouReel(int index) async {
    if (index < 0 || index >= _forYouReels.length) return;
    final url = _forYouReels[index].hlsUrl;
    if (url.trim().isEmpty) return;
    try {
      await VideoEngineService.instance.getOrCreateController(url);
    } catch (error) {
      debugPrint(
        'OJAS JIT HLS warm failed for ${_forYouReels[index].id}: $error',
      );
    }
  }

  void _setForYouVisibleIndex(int index) {
    if (_forYouVisibleIndex == index || !mounted) return;
    if (_forYouVisibleIndex >= 0) _flushWatchMetrics(_forYouVisibleIndex);
    setState(() => _forYouVisibleIndex = index);
    if (index >= 0) _visibleSince = DateTime.now();
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
  }

  void _markReelSeen(int index) {
    if (index >= 0 && index < _forYouReels.length) {
      _seenReelIds.add(_forYouReels[index].id);
    }
  }

  Future<void> _flushWatchMetrics(int index) async {
    if (index < 0 || index >= _forYouReels.length) return;
    final reel = _forYouReels[index];
    final started = _visibleSince;
    if (started != null) {
      _watchTimeMs[reel.id] = (_watchTimeMs[reel.id] ?? 0) +
          DateTime.now().difference(started).inMilliseconds;
      _visibleSince = null;
    }
    final watchMs = _watchTimeMs.remove(reel.id) ?? 0;
    final completed = _completionPending.remove(reel.id) ?? false;
    if (watchMs > 0 || completed) {
      await _engagementService.syncWatchMetrics(
        reelId: reel.id,
        watchTimeMs: watchMs,
        completionDelta: completed ? 1 : 0,
      );
    }
  }

  void _toggleComments() {
    HapticFeedback.lightImpact();
    setState(() => _isCommentsOpen = !_isCommentsOpen);
  }

  void _syncFollow(String creatorId, String creator, bool following) {
    setState(() {
      if (following) {
        _followedCreators.add(creator);
      } else {
        _followedCreators.remove(creator);
      }
    });
    _engagementService.syncFollow(creatorId: creatorId, following: following);
  }

  void _markCurrentNotInterested() {
    if (_forYouReels.isEmpty ||
        _forYouVisibleIndex < 0 ||
        _forYouVisibleIndex >= _forYouReels.length) {
      return;
    }
    final reel = _forYouReels[_forYouVisibleIndex];
    setState(() => _notInterestedReels.add(reel.id));
    if (_forYouController.hasClients &&
        _forYouVisibleIndex < _forYouReels.length - 1) {
      _forYouController.nextPage(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _showOptionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF13171D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.visibility_rounded, color: Color(0xFFF5B942)),
              title: const Text('Super View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: const Text('Maximize the video while keeping commerce visible', style: TextStyle(color: Colors.white54)),
              onTap: () {
                Navigator.pop(context);
                if (!mounted) return;
                setState(() => _isSuperViewActive = true);
                HapticFeedback.lightImpact();
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined, color: Colors.white70),
              title: const Text('Not Interested', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Tune your feed locally', style: TextStyle(color: Colors.white54)),
              onTap: () {
                Navigator.pop(context);
                _markCurrentNotInterested();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.white70),
              title: const Text('Report', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted for review')),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _toggleLikeVideo(String videoId) {
    HapticFeedback.lightImpact();
    final shouldLike = !_likedVideos.contains(videoId);
    setState(() {
      if (shouldLike) {
        _likedVideos.add(videoId);
      } else {
        _likedVideos.remove(videoId);
      }
      for (final reel in _forYouReels) {
        if (reel.id == videoId) {
          _likeDeltas[videoId] =
              (_likeDeltas[videoId] ?? 0) + (shouldLike ? 1 : -1);
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
  }

  void _toggleSaveVideo(String videoId) {
    HapticFeedback.selectionClick();
    final shouldSave = !_savedVideos.contains(videoId);
    setState(() {
      if (shouldSave) {
        _savedVideos.add(videoId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved 🔖'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        _savedVideos.remove(videoId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from Saved'),
            duration: Duration(seconds: 1),
          ),
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
  }

  void _selectFeed(int index) {
    if (_currentSelectedFeed == index) return;
    HapticFeedback.selectionClick();
    _horizontalFeedController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final followingVideos = temporaryOjsVideos
        .where((video) => _followedCreators.contains(video.creator))
        .toList();

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xfff5b942),
          brightness: Brightness.dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView(
              controller: _horizontalFeedController,
              physics: _isCommentsOpen
                  ? const NeverScrollableScrollPhysics()
                  : const OjasZeroJankScrollPhysics(),
              onPageChanged: (index) => setState(() {
                _currentSelectedFeed = index;
                _isSuperViewActive = false;
              }),
              children: [
                _buildForYouFeed(),
                _buildFollowingFeed(followingVideos),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FeedTab(
                              label: 'For You',
                              isActive: _currentSelectedFeed == 0,
                              onTap: () => _selectFeed(0),
                            ),
                            _FeedTab(
                              label: 'Following',
                              isActive: _currentSelectedFeed == 1,
                              onTap: () => _selectFeed(1),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          tooltip: _isSuperViewActive ? 'Restore UI' : 'More options',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            if (_isSuperViewActive) {
                              setState(() => _isSuperViewActive = false);
                              HapticFeedback.lightImpact();
                            } else {
                              _showOptionsSheet();
                            }
                          },
                          icon: Icon(
                            _isSuperViewActive ? Icons.visibility_rounded : Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForYouFeed() {
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
          setState(() {
            _forYouCurrentIndex = index;
            _isSuperViewActive = false;
          });
          if (_forYouReels.isNotEmpty && index >= _forYouReels.length - 2) {
            _fetchMoreForYouReels();
          }
        },
        itemBuilder: (context, index) {
          final video = videos[index];
          final isVideoVisible =
              widget.isActive &&
              _currentSelectedFeed == 0 &&
              _forYouVisibleIndex == index;

          return OjsVideoPage(
            video: video,
            isVisible: isVideoVisible,
            isFollowing: _followedCreators.contains(video.creator),
            isFollowingFeed: false,
            isLiked: _likedVideos.contains(video.id),
            isSaved: _savedVideos.contains(video.id),\n            isSuperViewActive: _isSuperViewActive,
            onLike: () => _toggleLikeVideo(video.id),
            onComment: () => _openComments(video.id),
            onSave: () => _toggleSaveVideo(video.id),
            onFollow: () {
              final next = !_followedCreators.contains(video.creator);
              _syncFollow(video.creatorId, video.creator, next);
            },
            onProfile: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CreatorProfileScreen(
                    creatorId: video.creatorId,
                    username: video.creator,
                    isFollowing: _followedCreators.contains(video.creator),
                    onFollowChanged: (following) {
                      _syncFollow(video.creatorId, video.creator, following);
                    },
                  ),
                ),
              );
            },
            onAudio: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AudioReelsScreen(
                  audioTrackId: video.audioTrackId.isEmpty
                      ? video.id
                      : video.audioTrackId,
                  creatorName: video.creator,
                ),
              ),
            ),
            onShare: () => ShareBottomSheet.show(
              context,
              videoUrl: video.videoUrl,
              creatorName: video.creator,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFollowingFeed(List<OjsVideo> followingVideos) {
    if (followingVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_add_alt_1_rounded,
              size: 48,
              color: Color(0xFFF5B942),
            ),
            const SizedBox(height: 12),
            const Text(
              'Follow Creators to see their clips here',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5B942),
                foregroundColor: Colors.black,
              ),
              onPressed: () => _selectFeed(0),
              child: const Text(
                'Back to For You',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: _followingController,
      scrollDirection: Axis.vertical,
      physics: _isCommentsOpen
          ? const NeverScrollableScrollPhysics()
          : const OjasZeroJankScrollPhysics(),
      itemCount: followingVideos.length,
      onPageChanged: (index) => setState(() {
        _followingCurrentIndex = index;
        _isSuperViewActive = false;
      }),
      itemBuilder: (context, index) {
        final video = followingVideos[index];
        final isVideoVisible =
            widget.isActive &&
            _currentSelectedFeed == 1 &&
            _followingCurrentIndex == index;

        return OjsVideoPage(
          video: video,
          isVisible: isVideoVisible,
          isFollowing: true,
          isFollowingFeed: true,
          isLiked: _likedVideos.contains(video.id),
          isSaved: _savedVideos.contains(video.id),\n          isSuperViewActive: _isSuperViewActive,
          onLike: () => _toggleLikeVideo(video.id),
          onComment: _toggleComments,
          onSave: () => _toggleSaveVideo(video.id),
          onFollow: () {
            final next = !_followedCreators.contains(video.creator);
            _syncFollow(video.creatorId, video.creator, next);
          },
          onProfile: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CreatorProfileScreen(
                  creatorId: video.creatorId,
                  username: video.creator,
                  isFollowing: _followedCreators.contains(video.creator),
                  onFollowChanged: (following) {
                    _syncFollow(video.creatorId, video.creator, following);
                  },
                ),
              ),
            );
          },
          onAudio: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AudioReelsScreen(
                audioTrackId: video.audioTrackId.isEmpty
                    ? video.id
                    : video.audioTrackId,
                creatorName: video.creator,
              ),
            ),
          ),
          onShare: () => ShareBottomSheet.show(
            context,
            videoUrl: video.videoUrl,
            creatorName: video.creator,
          ),
        );
      },
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                fontSize: 14.5,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isActive ? 24 : 0,
              height: 2,
              color: const Color(0xFFF5B942),
            ),
          ],
        ),
      ),
    );
  }
}
