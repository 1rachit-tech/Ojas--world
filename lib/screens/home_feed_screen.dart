import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../controllers/home_feed_controller.dart';
import '../models/home_feed_models.dart';
import '../models/home_story_models.dart';
import '../services/home_feed_event_queue.dart';
import '../services/home_playback_coordinator.dart';
import '../services/home_story_service.dart';
import '../widgets/home_comments_sheet.dart';
import '../widgets/home_story_viewer.dart';
import '../widgets/share_bottom_sheet.dart';
import '../widgets/super_thanks_modal.dart';
import '../widgets/world_search_delegate.dart';
import 'creator_profile_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeFeedController _controller;
  final HomeStoryService _storyService = HomeStoryService();
  final ScrollController _scrollController = ScrollController();
  final HomePlaybackCoordinator _playback = HomePlaybackCoordinator();

  List<HomeStoryUser> _stories = const <HomeStoryUser>[];
  bool _storiesLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = HomeFeedController()..addListener(_onFeedChanged);
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait<void>([
      _controller.initialize(),
      _loadStories(),
    ]);
  }

  Future<void> _loadStories() async {
    try {
      final stories = await _storyService.fetchActiveStories();
      if (!mounted) return;
      setState(() {
        _stories = stories;
        _storiesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _storiesLoading = false);
    }
  }

  void _onFeedChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 800) {
      _controller.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _playback.disposeAll();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _controller.items;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        titleSpacing: 16,
        leading: IconButton(
          tooltip: 'Search World',
          icon: const Icon(Icons.search_rounded, color: Color(0xFF111827), size: 26),
          onPressed: () => WorldSearchSheet.show(context),
        ),
        title: const Text(
          'OJAS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            color: Color(0xFF111827),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF111827), size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<void>([
            _controller.refresh(),
            _loadStories(),
          ]);
        },
        color: const Color(0xFF111827),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildFeedModeBar()),
            SliverToBoxAdapter(child: _buildStoriesTray()),
            const SliverToBoxAdapter(
              child: Divider(color: Color(0xFFE5E7EB), height: 18, thickness: 1),
            ),
            if (_controller.error != null && items.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _buildErrorState())
            else if (items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = items[index];
                    return _HomeFeedCard(
                      key: ValueKey(item.contentId),
                      item: item,
                      position: index,
                      controller: _controller,
                      playback: _playback,
                    );
                  },
                  childCount: items.length,
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: _controller.hasMore
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'You are all caught up',
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedModeBar() {
    const modes = <HomeFeedMode, String>{
      HomeFeedMode.personalized: 'For You',
      HomeFeedMode.following: 'Following',
      HomeFeedMode.favorites: 'Favorites',
      HomeFeedMode.latest: 'Latest',
      HomeFeedMode.friends: 'Friends',
    };

    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mode = modes.keys.elementAt(index);
          final active = _controller.mode == mode;
          return ChoiceChip(
            label: Text(modes[mode]!),
            selected: active,
            onSelected: (_) => _controller.setMode(mode),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : const Color(0xFF374151),
            ),
            selectedColor: const Color(0xFF111827),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          );
        },
      ),
    );
  }

  Widget _buildStoriesTray() {
    if (_storiesLoading) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _stories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) return _buildOwnStoryButton();
          return _buildStoryUser(_stories[index - 1]);
        },
      ),
    );
  }

  Widget _buildOwnStoryButton() {
    return GestureDetector(
      onTap: _openCreateStorySheet,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFFF3F4F6),
                child: Icon(Icons.person, color: Color(0xFF6B7280)),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFF111827),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 14, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Your Story', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStoryUser(HomeStoryUser user) {
    final firstStory = user.stories.first;
    final color = _colorFor(user.creatorId);
    final initial = user.displayName.isEmpty ? '?' : user.displayName.substring(0, 1);
    return GestureDetector(
      onTap: () async {
        await _storyService.markViewed(firstStory.id);
        if (!mounted) return;
        HomeStoryViewer.show(
          context,
          userName: user.displayName,
          avatarColor: color,
          storyCaption: firstStory.caption,
        );
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: user.hasUnread
                    ? const [Color(0xFFF59E0B), Color(0xFFEF4444)]
                    : const [Color(0xFFD1D5DB), Color(0xFFE5E7EB)],
              ),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: color,
              backgroundImage: user.avatarUrl == null ? null : NetworkImage(user.avatarUrl!),
              child: user.avatarUrl == null
                  ? Text(
                      initial,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 68,
            child: Text(
              user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _openCreateStorySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text('Create Story', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Open Camera'),
              onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening Story Camera...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening Gallery...')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            const Text('Home feed could not be loaded.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _controller.refresh,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(String value) {
    const palette = <Color>[
      Color(0xFFE5A87B),
      Color(0xFF93C5FD),
      Color(0xFFC5C6E9),
      Color(0xFFFFD36B),
      Color(0xFF86EFAC),
    ];
    return palette[value.hashCode.abs() % palette.length];
  }
}

class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context) => const HomeScreen();
}

class _HomeFeedCard extends StatelessWidget {
  const _HomeFeedCard({
    super.key,
    required this.item,
    required this.position,
    required this.controller,
    required this.playback,
  });

  final HomeFeedItem item;
  final int position;
  final HomeFeedController controller;
  final HomePlaybackCoordinator playback;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: () {
              controller.markInteraction(item, HomeFeedEventType.profileVisit);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatorProfileScreen(
                    creatorName: item.creatorId,
                    avatarColor: const Color(0xFFE5A87B),
                  ),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE5A87B),
              child: Text(
                item.creatorId.isEmpty ? '?' : item.creatorId[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
              ),
            ),
            title: Text(
              item.creatorId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(_relativeTime(item.createdAt)),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleMenu(context, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'not_interested', child: Text('Not Interested')),
                PopupMenuItem(value: 'hide', child: Text('Hide this post')),
                PopupMenuItem(value: 'mute', child: Text('Mute creator')),
                PopupMenuItem(value: 'block', child: Text('Block creator')),
                PopupMenuItem(value: 'report', child: Text('Report')),
              ],
            ),
          ),
          if (item.recommendationReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.recommendationReason!,
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          if (item.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(item.caption, style: const TextStyle(fontSize: 14.5, height: 1.4)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _HomeFeedMedia(
              item: item,
              playback: playback,
              autoplay: position == 0,
              onWatchEvent: (eventType, watchMs) {
                controller.markWatch(
                  item,
                  eventType: eventType,
                  position: position,
                  watchTimeMs: watchMs,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_border_rounded),
                  onPressed: () => controller.markInteraction(item, HomeFeedEventType.like),
                ),
                Text('${item.likes}'),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined),
                  onPressed: () {
                    controller.markInteraction(item, HomeFeedEventType.comment);
                    HomeCommentsSheet.show(
                      context,
                      postId: item.contentId,
                      creatorName: item.creatorId,
                      initialComments: const <String>[],
                      onCommentsUpdated: (_) {},
                    );
                  },
                ),
                Text('${item.comments}'),
                IconButton(
                  icon: const Icon(Icons.reply_rounded),
                  onPressed: () {
                    controller.markInteraction(item, HomeFeedEventType.share);
                    ShareBottomSheet.show(
                      context,
                      videoUrl: item.mediaUrl ?? 'https://ojas.app/post/${item.contentId}',
                      creatorName: item.creatorId,
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bookmark_border_rounded),
                  onPressed: () => controller.markInteraction(item, HomeFeedEventType.save),
                ),
                if (position == 0)
                  IconButton(
                    tooltip: 'Support Creator',
                    icon: const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B)),
                    onPressed: () => SuperThanksModal.show(context, creatorName: item.creatorId),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenu(BuildContext context, String value) {
    switch (value) {
      case 'not_interested':
        controller.notInterested(item);
        break;
      case 'hide':
        controller.hide(item);
        break;
      case 'mute':
        controller.muteCreator(item);
        break;
      case 'block':
        controller.blockCreator(item);
        break;
      case 'report':
        controller.report(item);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted.')),
        );
        break;
    }
  }

  String _relativeTime(DateTime time) {
    final minutes = DateTime.now().difference(time).inMinutes;
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return '${minutes}m ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '${hours}h ago';
    return '${hours ~/ 24}d ago';
  }
}

class _HomeFeedMedia extends StatefulWidget {
  const _HomeFeedMedia({
    required this.item,
    required this.playback,
    required this.autoplay,
    required this.onWatchEvent,
  });

  final HomeFeedItem item;
  final HomePlaybackCoordinator playback;
  final bool autoplay;
  final void Function(HomeFeedEventType eventType, int watchMs) onWatchEvent;

  @override
  State<_HomeFeedMedia> createState() => _HomeFeedMediaState();
}

class _HomeFeedMediaState extends State<_HomeFeedMedia> implements HomePlaybackHandle {
  VideoPlayerController? _videoController;
  bool _loading = false;
  bool _failed = false;
  DateTime? _startedAt;
  String? get _videoUrl => widget.item.mediaUrl ??
      (widget.item.mediaSources.isEmpty ? null : widget.item.mediaSources.first);

  @override
  void initState() {
    super.initState();
    widget.playback.register(widget.item.contentId, this);
    if (widget.autoplay && _videoUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.playback.activate(widget.item.contentId);
      });
    }
  }

  @override
  void dispose() {
    widget.playback.pause(widget.item.contentId);
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _ensureController() async {
    if (_videoController != null || _loading || _failed || _videoUrl == null) return;
    _loading = true;
    if (mounted) setState(() {});
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(_videoUrl!));
      await controller.initialize();
      await controller.setLooping(true);
      controller.addListener(_onVideoChanged);
      _videoController = controller;
      _failed = false;
    } catch (_) {
      _failed = true;
    } finally {
      _loading = false;
      if (mounted) setState(() {});
    }
  }

  void _onVideoChanged() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized || !controller.value.isPlaying) return;
    _startedAt ??= DateTime.now();
  }

  @override
  Future<void> play() async {
    await _ensureController();
    if (_videoController == null) return;
    await _videoController!.play();
    _startedAt ??= DateTime.now();
    widget.onWatchEvent(HomeFeedEventType.playStart, 0);
    if (mounted) setState(() {});
  }

  @override
  Future<void> pause() async {
    final controller = _videoController;
    if (controller == null) return;
    await controller.pause();
    if (_startedAt != null) {
      final ms = DateTime.now().difference(_startedAt!).inMilliseconds;
      widget.onWatchEvent(HomeFeedEventType.pause, ms);
      _startedAt = null;
    }
    if (mounted) setState(() {});
  }

  @override
  Future<void> release() async {
    final controller = _videoController;
    _videoController = null;
    _startedAt = null;
    await controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoUrl = _videoUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      return GestureDetector(
        onTap: () async {
          if (_videoController?.value.isPlaying == true) {
            await pause();
          } else {
            await widget.playback.activate(widget.item.contentId);
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: _videoController?.value.isInitialized == true
                ? _videoController!.value.aspectRatio
                : 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                if (widget.item.thumbnailUrl != null)
                  CachedNetworkImage(
                    imageUrl: widget.item.thumbnailUrl!,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 160),
                    placeholder: (_, __) => const ColoredBox(color: Color(0xFFF3F4F6)),
                    errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFFE5E7EB)),
                  )
                else
                  const ColoredBox(color: Color(0xFFE5E7EB)),
                if (_videoController?.value.isInitialized == true)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (_failed)
                  const Center(
                    child: Icon(Icons.broken_image_outlined, size: 42, color: Colors.white),
                  ),
                if (_videoController?.value.isPlaying != true && !_loading)
                  const Center(
                    child: Icon(Icons.play_circle_fill_rounded, size: 58, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.item.thumbnailUrl != null && widget.item.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 1,
          child: CachedNetworkImage(imageUrl: widget.item.thumbnailUrl!, fit: BoxFit.cover),
        ),
      );
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF3F4F6),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 48, color: Color(0xFF9CA3AF)),
    );
  }
}
