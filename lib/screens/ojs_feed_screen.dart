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
        body: Stack(
          children: [
            PageView(
              controller: _feedController,
              onPageChanged: (index) => setState(() => _selectedFeed = index),
              children: [
                _buildVerticalFeed(_forYouController, false),
                _buildVerticalFeed(_followingController, true),
              ],
            ),
            _buildTopBar(),
          ],
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
            ((followingFeed
                        ? _followingController.page
                        : _forYouController.page) ??
                    0)
                .round();
        return OjsVideoPage(
          video: video,
          isVisible:
              widget.isActive &&
              _selectedFeed == (followingFeed ? 1 : 0) &&
              activeIndex == index,
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
        );
      },
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 10, 0),
        child: Row(
          children: [
            const Spacer(),
            _FeedTab(
              label: 'For You',
              isActive: _selectedFeed == 0,
              onTap: () => _selectFeed(0),
            ),
            const SizedBox(width: 26),
            _FeedTab(
              label: 'Following',
              isActive: _selectedFeed == 1,
              onTap: () => _selectFeed(1),
            ),
            const Spacer(),
            IconButton(
              onPressed: _showFilters,
              tooltip: 'Filter categories',
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(vertical: 10),
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
