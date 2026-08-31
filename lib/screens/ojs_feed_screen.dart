import 'package:flutter/material.dart';

import '../models/ojs_video.dart';
import '../widgets/ojs_video_page.dart';

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

  // कमेंट बॉक्स के लिए नया स्टेट
  bool _isCommentsOpen = false;

  void _toggleComments() {
    setState(() {
      _isCommentsOpen = !_isCommentsOpen;
    });
  }

  @override
  void didUpdateWidget(covariant OjsFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive && !widget.isActive) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _feedController.dispose();
    _forYouController.dispose();
    _followingController.dispose();
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // 1. आपका फीड सेक्शन (जो कमेंट खुलने पर आधा हो जाएगा)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: _isCommentsOpen ? constraints.maxHeight * 0.45 : constraints.maxHeight,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      PageView(
                        controller: _feedController,
                        onPageChanged: (index) => setState(() => _selectedFeed = index),
                        children: [
                          _buildVerticalFeed(_forYouController, false),
                          _buildVerticalFeed(_followingController, true),
                        ],
                      ),
                      // कमेंट खुलने पर टॉप बार छुपा दें ताकि UI साफ रहे
                      if (!_isCommentsOpen) _buildTopBar(),
                    ],
                  ),
                ),

                // 2. नया डार्क प्रीमियम कमेंट सेक्शन
                if (_isCommentsOpen)
                  Expanded(
                    child: _buildCommentSection(),
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
        ? temporaryOjsVideos
            .where((video) => _followedCreators.contains(video.creator))
            .toList()
        : temporaryOjsVideos;
    final visibleFeed = videos.isEmpty ? temporaryOjsVideos : videos;
    
    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      itemCount: 100,
      onPageChanged: (_) => setState(() {}),
      itemBuilder: (context, index) {
        final video = visibleFeed[index % visibleFeed.length];
        final activeIndex =
            ((followingFeed ? _followingController.page : _forYouController.page) ?? 0)
                .round();
                
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
          // यहाँ हमने कमेंट खोलने का फंक्शन पास किया है
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
                    _FeedTab(
                      label: 'For You',
                      isActive: _selectedFeed == 0,
                      onTap: () => _selectFeed(0),
                    ),
                    _FeedTab(
                      label: 'Following',
                      isActive: _selectedFeed == 1,
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

  // =======================================================================
  // असली कमेंट सेक्शन (Super Thanks के साथ डार्क मोड में)
  // =======================================================================
  Widget _buildCommentSection() {
    return Container(
      color: const Color(0xff0f1419), // प्रीमियम डार्क बैकग्राउंड
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('642 comments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSingleComment('Rahul Sharma', 'This looks so peaceful! Beautiful shot.', '2h', 145),
                _buildSingleComment('Sneha_09', 'Link to the full video? 🤩', '4h', 32),
                _buildSingleComment('Arjun Vlogs', 'Wow! Super thanks sent! 💰🙌', '8h', 89, isSuperThanks: true),
                _buildSingleComment('TechGuru', 'Perfect lighting! Which camera did you use?', '5h', 12),
              ],
            ),
          ),

          // Bottom Input Field & Super Thanks
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xff171c21),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 16, backgroundColor: Colors.white12, child: Icon(Icons.person, size: 20, color: Colors.white54)),
                const SizedBox(width: 12),
                
                // Input Box
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: const Color(0xff222831), borderRadius: BorderRadius.circular(20)),
                    child: const TextField(
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add comment or paste link...',
                        hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Super Thanks Button
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Super Thanks: Creator Support window opened!')));
                  },
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xff2a2216), // Dark Yellow tint
                    child: Icon(Icons.favorite_rounded, color: Color(0xfff5b942), size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.send_rounded, color: Color(0xfff5b942), size: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleComment(String name, String text, String time, int likes, {bool isSuperThanks = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18, 
            backgroundColor: isSuperThanks ? const Color(0xfff5b942) : Colors.white12, 
            child: Text(name[0], style: TextStyle(color: isSuperThanks ? Colors.black : Colors.white))
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
                    if (isSuperThanks) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.monetization_on, color: Color(0xfff5b942), size: 14),
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(fontSize: 14, color: Colors.white)),
                const SizedBox(height: 6),
                Text('Reply · $time', style: const TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.favorite_border_rounded, size: 16, color: Colors.white38),
              const SizedBox(height: 4),
              Text(likes.toString(), style: const TextStyle(fontSize: 11, color: Colors.white38)),
            ],
          ),
        ],
      ),
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
