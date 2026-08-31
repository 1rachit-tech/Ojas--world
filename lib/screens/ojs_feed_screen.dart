import 'package:flutter/material.dart';

import '../models/ojs_video.dart';
import '../widgets/ojs_video_page.dart';

class CommentItem {
  final String id;
  final String userName;
  final String text;
  final String time;
  int likes;
  bool isLiked;
  final bool isSuperThanks;
  final double? tipAmount;

  CommentItem({
    required this.id,
    required this.userName,
    required this.text,
    required this.time,
    required this.likes,
    this.isLiked = false,
    this.isSuperThanks = false,
    this.tipAmount,
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

  // Following & Likes State
  final Set<String> _followedCreators = {'Rohan Mehta', 'Nia Okafor'};
  final Set<String> _likedVideos = <String>{};

  // 0 = For You, 1 = Following
  int _currentSelectedFeed = 0;
  int _forYouCurrentIndex = 0;
  int _followingCurrentIndex = 0;

  // Comments State
  bool _isCommentsOpen = false;
  final TextEditingController _commentInputController = TextEditingController();
  final List<CommentItem> _commentsList = [
    CommentItem(
      id: '1',
      userName: 'Rahul Sharma',
      text: 'This lighting and frame is magical! 🌿✨',
      time: '2h',
      likes: 142,
    ),
    CommentItem(
      id: '2',
      userName: 'Sneha_09',
      text: 'Where can I get the soundtrack link? https://ojas.app/sound/90',
      time: '4h',
      likes: 38,
    ),
    CommentItem(
      id: '3',
      userName: 'Arjun Vlogs',
      text: 'Keep inspiring us with pure quality content! 🚀',
      time: '5h',
      likes: 89,
      isSuperThanks: true,
      tipAmount: 100,
    ),
  ];

  @override
  void dispose() {
    _horizontalFeedController.dispose();
    _forYouController.dispose();
    _followingController.dispose();
    _commentInputController.dispose();
    super.dispose();
  }

  void _toggleComments() {
    setState(() {
      _isCommentsOpen = !_isCommentsOpen;
    });
    if (!_isCommentsOpen) {
      FocusScope.of(context).unfocus();
    }
  }

  void _addNewComment({bool isSuperThanks = false, double? amount}) {
    final text = _commentInputController.text.trim();
    if (text.isEmpty && !isSuperThanks) return;

    setState(() {
      _commentsList.insert(
        0,
        CommentItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userName: 'You',
          text: text.isEmpty ? 'Supported the creator! ⭐' : text,
          time: 'Just now',
          likes: 0,
          isSuperThanks: isSuperThanks,
          tipAmount: amount,
        ),
      );
      _commentInputController.clear();
    });
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

  void _selectFeed(int index) {
    if (_currentSelectedFeed == index) return;
    _horizontalFeedController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
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
        scaffoldBackgroundColor: const Color(0xff07090b),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xfff5b942),
          brightness: Brightness.dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xff07090b),
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final double totalHeight = constraints.maxHeight;

            return Stack(
              children: [
                // 1. VIDEO FEED CONTAINER (Maintains 9:16 Aspect Ratio)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _isCommentsOpen ? totalHeight * 0.45 : totalHeight,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_isCommentsOpen ? 12 : 0),
                        child: PageView(
                          controller: _horizontalFeedController,
                          physics: _isCommentsOpen
                              ? const NeverScrollableScrollPhysics()
                              : const PageScrollPhysics(),
                          onPageChanged: (index) {
                            setState(() {
                              _currentSelectedFeed = index;
                            });
                          },
                          children: [
                            // FOR YOU FEED (All Videos)
                            _buildForYouFeed(),

                            // FOLLOWING FEED (Only Followed Creators)
                            _buildFollowingFeed(followingVideos),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. TOP TABS (For You | Following)
                if (!_isCommentsOpen) _buildTopBar(),

                // 3. INTERACTIVE COMMENTS SHEET
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: _isCommentsOpen ? totalHeight * 0.55 : 0,
                  child: _isCommentsOpen ? _buildCommentSheet() : const SizedBox.shrink(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- For You Vertical Feed ---
  Widget _buildForYouFeed() {
    final videos = temporaryOjsVideos;
    if (videos.isEmpty) {
      return const Center(
        child: Text(
          'No videos available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return PageView.builder(
      controller: _forYouController,
      scrollDirection: Axis.vertical,
      physics: _isCommentsOpen ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
      itemCount: videos.length,
      onPageChanged: (index) {
        setState(() {
          _forYouCurrentIndex = index;
        });
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
          onFollow: () => _toggleFollowCreator(video.creator),
          onLike: () => _toggleLikeVideo(video.id),
          onComment: _toggleComments,
        );
      },
    );
  }

  // --- Following Vertical Feed ---
  Widget _buildFollowingFeed(List<OjsVideo> followingVideos) {
    // Agar koi creator follow nahi kiya hai
    if (followingVideos.isEmpty) {
      return Container(
        color: const Color(0xff07090b),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 48,
                  color: Color(0xfff5b942),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Follow Creators to See Their Videos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'When you follow creators in the For You feed, their latest clips will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xfff5b942),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => _selectFeed(0),
                child: const Text('Explore For You Feed', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    // Following Feed PageView
    return PageView.builder(
      controller: _followingController,
      scrollDirection: Axis.vertical,
      physics: _isCommentsOpen ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
      itemCount: followingVideos.length,
      onPageChanged: (index) {
        setState(() {
          _followingCurrentIndex = index;
        });
      },
      itemBuilder: (context, index) {
        final video = followingVideos[index];
        final bool isVideoVisible = widget.isActive &&
            _currentSelectedFeed == 1 &&
            _followingCurrentIndex == index;

        return OjsVideoPage(
          video: video,
          isVisible: isVideoVisible,
          isFollowing: _followedCreators.contains(video.creator),
          isFollowingFeed: true,
          isLiked: _likedVideos.contains(video.id),
          onFollow: () => _toggleFollowCreator(video.creator),
          onLike: () => _toggleLikeVideo(video.id),
          onComment: _toggleComments,
        );
      },
    );
  }

  // --- Top Bar (For You | Following) ---
  Widget _buildTopBar() {
    return Positioned(
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
                  onPressed: _showFilters,
                  tooltip: 'Filter categories',
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff171c21),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ['Comedy', 'Music', 'Sports', 'Trending']
                .map(
                  (category) => ActionChip(
                    label: Text(category),
                    onPressed: () => Navigator.pop(context),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  // --- Bottom Comments Sheet ---
  Widget _buildCommentSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xff12171d),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_commentsList.length} comments',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                GestureDetector(
                  onTap: _toggleComments,
                  child: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          // Comments List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _commentsList.length,
              itemBuilder: (context, index) {
                final comment = _commentsList[index];
                return _buildCommentTile(comment);
              },
            ),
          ),

          // Quick Emoji Bar
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['❤️', '🔥', '👏', '😍', '🙌', '💯', '✨', '⚡'].map((emoji) {
                return GestureDetector(
                  onTap: () {
                    _commentInputController.text += emoji;
                    _commentInputController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _commentInputController.text.length),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
          ),

          // Input Bar + Super Thanks + Send
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xff171c21),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFF5B942),
                  child: Text('U', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xff222831),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _commentInputController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Add comment or paste link...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showSuperThanksModal,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E2413),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_rounded,
                      color: Color(0xFFF5B942),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _addNewComment(),
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFF5B942),
                    child: Icon(Icons.send_rounded, color: Colors.black, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(CommentItem comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: comment.isSuperThanks ? const Color(0xFFF5B942) : Colors.white12,
            child: Text(
              comment.userName.isNotEmpty ? comment.userName[0] : 'U',
              style: TextStyle(
                color: comment.isSuperThanks ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
                    ),
                    if (comment.isSuperThanks) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5B942),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '₹${comment.tipAmount?.toInt() ?? 50} Super Thanks',
                          style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.text,
                  style: TextStyle(
                    color: comment.text.startsWith('http') ? const Color(0xFF60A5FA) : Colors.white,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text('Reply · ${comment.time}', style: const TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                comment.isLiked = !comment.isLiked;
                comment.likes += comment.isLiked ? 1 : -1;
              });
            },
            child: Column(
              children: [
                Icon(
                  comment.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 16,
                  color: comment.isLiked ? const Color(0xFFEF4444) : Colors.white38,
                ),
                const SizedBox(height: 2),
                Text(
                  comment.likes.toString(),
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSuperThanksModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF171C21),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.volunteer_activism_rounded, color: Color(0xFFF5B942), size: 36),
              const SizedBox(height: 8),
              const Text(
                'Send Super Thanks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'Support this creator directly on OJAS.',
                style: TextStyle(fontSize: 13, color: Colors.white60),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [50, 100, 200, 500].map((amt) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF222831),
                      foregroundColor: const Color(0xFFF5B942),
                      side: const BorderSide(color: Color(0xFFF5B942), width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _addNewComment(isSuperThanks: true, amount: amt.toDouble());
                    },
                    child: Text('₹$amt', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isActive ? 24 : 0,
              height: 2,
              color: const Color(0xfff5b942),
            ),
          ],
        ),
      ),
    );
  }
}
