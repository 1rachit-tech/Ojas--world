import 'package:flutter/material.dart';
import '../models/ojs_video.dart';
import '../widgets/ojs_video_page.dart';
import '../widgets/share_bottom_sheet.dart';

class CommentItem {
  final String id;
  final String userName;
  final String text;
  final String time;
  int likes;
  bool isLiked;
  final bool isSuperThanks;

  CommentItem({
    required this.id,
    required this.userName,
    required this.text,
    required this.time,
    required this.likes,
    this.isLiked = false,
    this.isSuperThanks = false,
  });
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

  final Set<String> _followedCreators = {'Rohan Mehta', 'Nia Okafor'};
  final Set<String> _likedVideos = <String>{};
  final Set<String> _savedVideos = <String>{};

  int _currentSelectedFeed = 0;
  int _forYouCurrentIndex = 0;
  int _followingCurrentIndex = 0;
  String _activeCategoryFilter = 'All';

  bool _isCommentsOpen = false;
  final List<CommentItem> _commentsList = [
    CommentItem(
      id: '1',
      userName: 'Rahul Sharma',
      text: 'This frame and lighting is magical! 🌿✨',
      time: '2h',
      likes: 142,
    ),
    CommentItem(
      id: '2',
      userName: 'Sneha_09',
      text: 'Vindhya vibes are unmatched! 🔥',
      time: '4h',
      likes: 38,
    ),
  ];

  @override
  void dispose() {
    _horizontalFeedController.dispose();
    _forYouController.dispose();
    _followingController.dispose();
    super.dispose();
  }

  void _toggleComments() {
    setState(() => _isCommentsOpen = !_isCommentsOpen);
  }

  void _toggleFollowCreator(String creator) {
    setState(() {
      if (_followedCreators.contains(creator)) {
        _followedCreators.remove(creator);
      } else {
        _followedCreators.add(creator);
      }
    });
  }

  void _toggleLikeVideo(String videoId) {
    setState(() {
      if (_likedVideos.contains(videoId)) {
        _likedVideos.remove(videoId);
      } else {
        _likedVideos.add(videoId);
      }
    });
  }

  void _toggleSaveVideo(String videoId) {
    setState(() {
      if (_savedVideos.contains(videoId)) {
        _savedVideos.remove(videoId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from Saved')),
        );
      } else {
        _savedVideos.add(videoId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved 🔖')),
        );
      }
    });
  }

  void _selectFeed(int index) {
    if (_currentSelectedFeed == index) return;
    _horizontalFeedController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _showTopFeedFilters() {
    final categories = ['All Feed', '🔥 Trending', '🎬 Cinematic', '🌿 Vindhya Roots', '🎵 High Bass Beats', '🎭 Comedy'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13171D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter Video Feed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: categories.map((cat) {
                  final isSelected = _activeCategoryFilter == cat;
                  return ActionChip(
                    label: Text(cat),
                    backgroundColor: isSelected ? const Color(0xFFF5B942) : const Color(0xFF222831),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    side: BorderSide.none,
                    onPressed: () {
                      setState(() => _activeCategoryFilter = cat);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Filtered by $cat 🎬')),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final followingVideos = temporaryOjsVideos
        .where((video) => _followedCreators.contains(video.creator))
        .toList();

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xff07090b),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xfff5b942),
          brightness: Brightness.dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xff07090b),
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView(
              controller: _horizontalFeedController,
              physics: _isCommentsOpen
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentSelectedFeed = index),
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
                          onPressed: _showTopFeedFilters,
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_isCommentsOpen)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.60,
                child: _buildCommentSheet(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForYouFeed() {
    final videos = temporaryOjsVideos;
    return PageView.builder(
      controller: _forYouController,
      scrollDirection: Axis.vertical,
      physics: _isCommentsOpen ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
      itemCount: videos.length,
      onPageChanged: (index) => setState(() => _forYouCurrentIndex = index),
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
  }

  Widget _buildFollowingFeed(List<OjsVideo> followingVideos) {
    if (followingVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_add_alt_1_rounded, size: 48, color: Color(0xFFF5B942)),
            const SizedBox(height: 12),
            const Text('Follow Creators to see their clips here', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5B942), foregroundColor: Colors.black),
              onPressed: () => _selectFeed(0),
              child: const Text('Back to For You', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: _followingController,
      scrollDirection: Axis.vertical,
      physics: _isCommentsOpen ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
      itemCount: followingVideos.length,
      onPageChanged: (index) => setState(() => _followingCurrentIndex = index),
      itemBuilder: (context, index) {
        final video = followingVideos[index];
        final bool isVideoVisible = widget.isActive &&
            _currentSelectedFeed == 1 &&
            _followingCurrentIndex == index;

        return OjsVideoPage(
          video: video,
          isVisible: isVideoVisible,
          isFollowing: true,
          isFollowingFeed: true,
          isLiked: _likedVideos.contains(video.id),
          isSaved: _savedVideos.contains(video.id),
          onFollow: () => _toggleFollowCreator(video.creator),
          onLike: () => _toggleLikeVideo(video.id),
          onComment: _toggleComments,
          onSave: () => _toggleSaveVideo(video.id),
          onShare: () {
            ShareBottomSheet.show(context, videoUrl: video.videoUrl, creatorName: video.creator);
          },
        );
      },
    );
  }

  Widget _buildCommentSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_commentsList.length} comments', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                GestureDetector(onTap: _toggleComments, child: const Icon(Icons.close_rounded, color: Colors.white54)),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: ListView.builder(
              itemCount: _commentsList.length,
              itemBuilder: (context, index) {
                final c = _commentsList[index];
                return ListTile(
                  leading: const CircleAvatar(radius: 16, backgroundColor: Color(0xFFF5B942), child: Text('U', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                  title: Text(c.userName, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: Text(c.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({required this.label, required this.isActive, required this.onTap});
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
