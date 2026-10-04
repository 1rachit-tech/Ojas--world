import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../controllers/home_feed_controller.dart';
import '../models/home_feed_models.dart';
import '../models/home_story_models.dart';
import '../services/engagement_service.dart';
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

/// Home feed screen — restored full UI with share contentId tracking.
class DynamicHomeScreen extends StatefulWidget {
  const DynamicHomeScreen({super.key});

  @override
  State<DynamicHomeScreen> createState() => _DynamicHomeScreenState();
}

class _DynamicHomeScreenState extends State<DynamicHomeScreen> {
  late final HomeFeedController _controller;
  late final HomePlaybackCoordinator _playback;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = HomeFeedController();
    _playback = HomePlaybackCoordinator();
    _scrollController.addListener(_onScroll);
    unawaited(_controller.initialize());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 600) {
      unawaited(_controller.loadMore());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final items = _controller.items;
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          body: RefreshIndicator(
            onRefresh: _controller.refresh,
            child: items.isEmpty && _controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: items.length + (_controller.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final item = items[index];
                      return _FeedCard(
                        key: ValueKey(item.contentId),
                        item: item,
                        controller: _controller,
                        playback: _playback,
                        position: index,
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    super.key,
    required this.item,
    required this.controller,
    required this.playback,
    required this.position,
  });

  final HomeFeedItem item;
  final HomeFeedController controller;
  final HomePlaybackCoordinator playback;
  final int position;

  @override
  Widget build(BuildContext context) {
    final liked = controller.isLiked(item.contentId);
    final saved = controller.isSaved(item.contentId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF111827),
              child: Text(
                item.creatorId.isNotEmpty ? item.creatorId[0].toUpperCase() : 'O',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              item.creatorId.isEmpty ? 'OJAS Creator' : item.creatorId,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'follow') {
                  controller.markInteraction(item, HomeFeedEventType.follow);
                  unawaited(EngagementService().syncFollow(
                    creatorId: item.creatorId,
                    following: true,
                  ));
                } else if (v == 'not_interested') {
                  controller.notInterested(item);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'follow', child: Text('Follow creator')),
                PopupMenuItem(value: 'not_interested', child: Text('Not interested')),
              ],
            ),
          ),
          if ((item.mediaUrl ?? '').isNotEmpty)
            AspectRatio(
              aspectRatio: 9 / 12,
              child: CachedNetworkImage(
                imageUrl: item.mediaUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(color: Color(0xFFF3F4F6)),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.image_outlined, color: Color(0xFF9CA3AF)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      videoUrl: item.mediaUrl ??
                          'https://ojas.app/post/${item.contentId}',
                      creatorName: item.creatorId,
                      contentId: item.contentId,
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  ),
                  onPressed: () => controller.toggleSave(item),
                ),
              ],
            ),
          ),
          if ((item.caption ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                item.caption!,
                style: const TextStyle(color: Color(0xFF374151), height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}
