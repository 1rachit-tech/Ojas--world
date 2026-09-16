import 'dart:async';

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
import '../widgets/home_why_post_sheet.dart';
import '../widgets/share_bottom_sheet.dart';
import '../widgets/super_thanks_modal.dart';
import '../widgets/world_search_delegate.dart';
import 'creator_profile_screen.dart';
import 'notifications_screen.dart';

class DynamicHomeScreen extends StatefulWidget {
  const DynamicHomeScreen({super.key});

  @override
  State<DynamicHomeScreen> createState() => _DynamicHomeScreenState();
}

class _DynamicHomeScreenState extends State<DynamicHomeScreen> with WidgetsBindingObserver {
  late final HomeFeedController _controller;
  final HomeStoryService _storyService = HomeStoryService();
  final ScrollController _scrollController = ScrollController();
  final HomePlaybackCoordinator _playback = HomePlaybackCoordinator();

  List<HomeStoryUser> _stories = const <HomeStoryUser>[];
  bool _storiesLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = HomeFeedController()..addListener(_onChanged);
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait<void>([_controller.initialize(), _loadStories()]);
    _schedulePlaybackEvaluation();
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

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    _schedulePlaybackEvaluation();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 700) {
      unawaited(_controller.loadMore());
    }
    _schedulePlaybackEvaluation();
  }

  void _schedulePlaybackEvaluation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_playback.evaluateDominantVisibility());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_controller.saveSession(
        _scrollController.hasClients ? _scrollController.offset : 0,
      ));
      unawaited(_controller.flushEvents());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.saveSession(
      _scrollController.hasClients ? _scrollController.offset : 0,
    ));
    unawaited(_controller.flushEvents());
    _scrollController.dispose();
    _controller.dispose();
    unawaited(_playback.disposeAll());
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
        leading: IconButton(
          tooltip: 'Search World',
          icon: const Icon(Icons.search_rounded, color: Color(0xFF111827)),
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
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF111827)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<void>([_controller.refresh(), _loadStories()]);
          _schedulePlaybackEvaluation();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildModes()),
            SliverToBoxAdapter(child: _buildStories()),
            const SliverToBoxAdapter(
              child: Divider(height: 18, thickness: 1, color: Color(0xFFE5E7EB)),
            ),
            if (_controller.error != null && items.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _errorState())
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
                    _controller.markImpression(item, index);
                    return _FeedCard(
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
                          height: 22,
                          width: 22,
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

  Widget _buildModes() {
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
        itemBuilder: (_, index) {
          final mode = modes.keys.elementAt(index);
          final selected = _controller.mode == mode;
          return ChoiceChip(
            label: Text(modes[mode]!),
            selected: selected,
            onSelected: (_) => _controller.setMode(mode),
            selectedColor: const Color(0xFF111827),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF374151),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStories() {
    if (_storiesLoading) {
      return const SizedBox(
        height: 108,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return SizedBox(
      height: 108,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _stories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          if (index == 0) return _ownStory();
          return _storyUser(_stories[index - 1]);
        },
      ),
    );
  }

  Widget _ownStory() {
    return GestureDetector(
      onTap: () => _storyCreateSheet(),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              const CircleAvatar(
                radius: 29,
                backgroundColor: Color(0xFFF3F4F6),
                child: Icon(Icons.person, color: Color(0xFF6B7280)),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Color(0xFF111827), shape: BoxShape.circle),
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

  Widget _storyUser(HomeStoryUser user) {
    final story = user.stories.first;
    final initial = user.displayName.isEmpty ? '?' : user.displayName.substring(0, 1);
    return GestureDetector(
      onTap: () async {
        await _storyService.markViewed(story.id);
        if (!mounted) return;
        HomeStoryViewer.show(
          context,
          userName: user.displayName,
          avatarColor: _avatarColor(user.creatorId),
          storyCaption: story.caption,
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
              radius: 27,
              backgroundColor: _avatarColor(user.creatorId),
              backgroundImage: user.avatarUrl == null ? null : NetworkImage(user.avatarUrl!),
              child: user.avatarUrl == null
                  ? Text(initial, style: const TextStyle(fontWeight: FontWeight.w800))
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

  void _storyCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text('Create Story', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Open Camera'),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
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
            FilledButton(onPressed: _controller.refresh, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Color _avatarColor(String key) {
    const palette = <Color>[
      Color(0xFFE5A87B),
      Color(0xFF93C5FD),
      Color(0xFFC5C6E9),
      Color(0xFFFFD36B),
      Color(0xFF86EFAC),
    ];
    return palette[key.hashCode.abs() % palette.length];
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
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
    final liked = controller.isLiked(item.contentId);
    final saved = controller.isSaved(item.contentId);
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
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            title: Text(item.creatorId, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_relativeTime(item.createdAt)),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _menu(context, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'why', child: Text('Why am I seeing this?')),
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
            child: _FeedMedia(
              item: item,
              playback: playback,
              autoplay: position == 0,
              onWatchEvent: (event, watchMs) => controller.markWatch(
                item,
                eventType: event,
                position: position,
                watchTimeMs: watchMs,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: liked ? const Color(0xFFEF4444) : const Color(0xFF4B5563),
                  ),
                  onPressed: () => controller.toggleLike(item),
                ),
                Text('${item.likes + (liked ? 1 : 0)}'),
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
                  icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                  onPressed: () => controller.toggleSave(item),
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

  void _menu(BuildContext context, String value) {
    switch (value) {
      case 'why':
        HomeWhyPostSheet.show(
          context,
          reason: controller.whyThisPost(item),
          onNotInterested: () => controller.notInterested(item),
        );
        break;
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted.')));
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

class _FeedMedia extends StatefulWidget {
  const _FeedMedia({
    required this.item,
    required this.playback,
    required this.autoplay,
    required this.onWatchEvent,
  });

  final HomeFeedItem item;
  final HomePlaybackCoordinator playback;
  final bool autoplay;
  final void Function(HomeFeedEventType event, int watchMs) onWatchEvent;

  @override
  State<_FeedMedia> createState() => _FeedMediaState();
}

class _FeedMediaState extends State<_FeedMedia> implements HomePlaybackHandle {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;
  DateTime? _startedAt;

  String? get _url => widget.item.mediaUrl ??
      (widget.item.mediaSources.isEmpty ? null : widget.item.mediaSources.first);

  @override
  void initState() {
    super.initState();
    widget.playback.register(widget.item.contentId, this);
    widget.playback.registerVisibilityProbe(widget.item.contentId, _visibilityFraction);
    if (widget.autoplay && _url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(widget.playback.evaluateDominantVisibility());
      });
    }
  }

  double _visibilityFraction() {
    if (!mounted) return 0;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return 0;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final bottomRight = renderObject.localToGlobal(renderObject.size.bottomRight(Offset.zero));
    final screen = MediaQuery.sizeOf(context);
    final visibleTop = topLeft.dy.clamp(0.0, screen.height);
    final visibleBottom = bottomRight.dy.clamp(0.0, screen.height);
    final visible = (visibleBottom - visibleTop).clamp(0.0, renderObject.size.height);
    if (renderObject.size.height <= 0) return 0;
    return visible / renderObject.size.height;
  }

  @override
  void dispose() {
    widget.playback.unregister(widget.item.contentId);
    unawaited(widget.playback.pause(widget.item.contentId));
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _ensureController() async {
    if (_controller != null || _loading || _failed || _url == null) return;
    _loading = true;
    if (mounted) setState(() {});
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(_url!));
      await controller.initialize();
      await controller.setLooping(true);
      _controller = controller;
      _failed = false;
    } catch (_) {
      _failed = true;
    } finally {
      _loading = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Future<void> play() async {
    await _ensureController();
    if (_controller == null) return;
    await _controller!.play();
    _startedAt ??= DateTime.now();
    widget.onWatchEvent(HomeFeedEventType.playStart, 0);
    if (mounted) setState(() {});
  }

  @override
  Future<void> pause() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.pause();
    if (_startedAt != null) {
      widget.onWatchEvent(
        HomeFeedEventType.pause,
        DateTime.now().difference(_startedAt!).inMilliseconds,
      );
      _startedAt = null;
    }
    if (mounted) setState(() {});
  }

  @override
  Future<void> release() async {
    final controller = _controller;
    _controller = null;
    _startedAt = null;
    await controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url != null && url.isNotEmpty) {
      return GestureDetector(
        onTap: () async {
          if (_controller?.value.isPlaying == true) {
            await pause();
          } else {
            await widget.playback.activate(widget.item.contentId);
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: _controller?.value.isInitialized == true
                ? _controller!.value.aspectRatio
                : 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                if (widget.item.thumbnailUrl != null)
                  CachedNetworkImage(
                    imageUrl: widget.item.thumbnailUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ColoredBox(color: Color(0xFFF3F4F6)),
                    errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFFE5E7EB)),
                  )
                else
                  const ColoredBox(color: Color(0xFFE5E7EB)),
                if (_controller?.value.isInitialized == true)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (_failed)
                  const Center(child: Icon(Icons.broken_image_outlined, size: 42, color: Colors.white)),
                if (_controller?.value.isPlaying != true && !_loading && !_failed)
                  const Center(child: Icon(Icons.play_circle_fill_rounded, size: 58, color: Colors.white)),
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
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 48, color: Color(0xFF9CA3AF)),
    );
  }
}
