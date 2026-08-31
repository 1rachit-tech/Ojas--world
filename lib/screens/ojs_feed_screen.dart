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
  final PageController _feedController = PageController();
  final PageController _forYouController = PageController();
  final PageController _followingController = PageController();
  final Set<String> _followedCreators = {'Rohan Mehta', 'Nia Okafor'};
  final Set<String> _likedVideos = <String>{};
  int _selectedFeed = 0;

  // Real Comments State
  bool _isCommentsOpen = false;
  final TextEditingController _commentInputController = TextEditingController();
  final List<CommentItem> _commentsList = [
    CommentItem(id: '1', userName: 'Rahul Sharma', text: 'This lighting and frame is magical! 🌿✨', time: '2h', likes: 142),
    CommentItem(id: '2', userName: 'Sneha_09', text: 'Where can I get the soundtrack link? https://ojas.app/sound/90', time: '4h', likes: 38),
    CommentItem(id: '3', userName: 'Arjun Vlogs', text: 'Keep inspiring us with pure quality content! 🚀', time: '5h', likes: 89, isSuperThanks: true, tipAmount: 100),
  ];

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

  @override
  void dispose() {
    _feedController.dispose();
    _forYouController.dispose();
    _followingController.dispose();
    _commentInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                // 1. VIDEO VIEW - Scaled & Ratio Maintained (9:16 Aspect Ratio)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _isCommentsOpen ? totalHeight * 0.45 : totalHeight,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 9 / 16, // 9:16 अनुपात बरकरार रहता है
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_isCommentsOpen ? 12 : 0),
                        child: PageView(
                          controller: _feedController,
                          physics: _isCommentsOpen ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                          onPageChanged: (index) => setState(() => _selectedFeed = index),
                          children: [
                            _buildVerticalFeed(_forYouController, false),
                            _buildVerticalFeed(_followingController, true),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. TOP BAR (Only visible when comments are closed)
                if (!_isCommentsOpen) _buildTopBar(),

                // 3. BOTTOM COMMENT SHEET (Opens from half height)
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

  Widget _buildVerticalFeed(PageController controller, bool followingFeed) {
    final videos = followingFeed
        ? temporaryOjsVideos.where((video) => _followedCreators.contains(video.creator)).toList()
        : temporaryOjsVideos;
    final visibleFeed = videos.isEmpty ? temporaryOjsVideos : videos;

    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      physics: _isCommentsOpen ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
      itemCount: 100,
      onPageChanged: (_) => setState(() {}),
      itemBuilder: (context, index) {
        final video = visibleFeed[index % visibleFeed.length];
        final activeIndex = ((followingFeed ? _followingController.page : _forYouController.page) ?? 0).round();

        return OjsVideoPage(
          video: video,
          isVisible: widget.isActive && _selectedFeed == (followingFeed ? 1 : 0) && activeIndex == index,
          isFollowing: _followedCreators.contains(video.creator),
          isFollowingFeed: followingFeed,
          isLiked: _likedVideos.contains(video.id),
          onFollow: () => setState(() {
            if (!_followedCreators.add(video.creator)) {
              _followedCreators.remove(video.creator);
            }
          }),
          onLike: () => setState(() {
            if (!_likedVideos.add(video.id)) {
              _likedVideos.remove(video.id);
            }
          }),
          onComment: _toggleComments,
        );
      },
    );
  }

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
                    _FeedTab(label: 'For You', isActive: _selectedFeed == 0, onTap: () => _selectFeed(0)),
                    _FeedTab(label: 'Following', isActive: _selectedFeed == 1, onTap: () => _selectFeed(1)),
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

  void _selectFeed(int index) {
    _feedController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
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
                .map((category) => ActionChip(label: Text(category), onPressed: () => Navigator.pop(context)))
                .toList(),
          ),
        ),
      ),
    );
  }

  // =======================================================================
  // रियल कमेंट बॉक्स (Emoji Bar, Link Posting, Super Thanks & Real Likes)
  // =======================================================================
  Widget _buildCommentSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xff12171d),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, spreadRadius: 2)],
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

          // Quick Emoji Selector Bar (जैसे TikTok/Instagram में होता है)
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

          // Bottom Input Field + Super Thanks + Send
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xff171c21),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 16, backgroundColor: Color(0xFFF5B942), child: Text('U', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: const Color(0xff222831), borderRadius: BorderRadius.circular(24)),
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
                // Super Thanks Button
                GestureDetector(
                  onTap: _showSuperThanksModal,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFF2E2413), shape: BoxShape.circle),
                    child: const Icon(Icons.volunteer_activism_rounded, color: Color(0xFFF5B942), size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                // Send Button
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
              style: TextStyle(color: comment.isSuperThanks ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
                    if (comment.isSuperThanks) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF5B942), borderRadius: BorderRadius.circular(10)),
                        child: Text('₹${comment.tipAmount?.toInt() ?? 50} Super Thanks', style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
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
          // Like comment button
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
                Text(comment.likes.toString(), style: const TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Super Thanks Support Modal
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
              const Text('Send Super Thanks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('Support this creator directly on OJAS.', style: TextStyle(fontSize: 13, color: Colors.white60)),
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
