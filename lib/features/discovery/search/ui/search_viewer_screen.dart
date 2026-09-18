import 'package:flutter/material.dart';

import '../../../../models/ojs_video.dart';
import '../../../../screens/audio_reels_screen.dart';
import '../../../../screens/creator_profile_screen.dart';
import '../../../../services/engagement_service.dart';
import '../../../../services/video_engine_service.dart';
import '../../../../widgets/ojs_video_page.dart';
import '../../../../widgets/share_bottom_sheet.dart';
import '../domain/search_models.dart';

class SearchViewerScreen extends StatefulWidget {
  const SearchViewerScreen({
    super.key,
    required this.results,
    required this.initialIndex,
    required this.query,
  });

  final List<SearchResult> results;
  final int initialIndex;
  final String query;

  @override
  State<SearchViewerScreen> createState() => _SearchViewerScreenState();
}

class _SearchViewerScreenState extends State<SearchViewerScreen> {
  late final PageController _controller;
  final EngagementService _engagement = EngagementService();
  final Set<String> _liked = <String>{};
  final Set<String> _saved = <String>{};

  @override
  void initState() {
    super.initState();
    final safeIndex = widget.initialIndex < 0
        ? 0
        : (widget.initialIndex >= widget.results.length
            ? widget.results.length - 1
            : widget.initialIndex);
    _controller = PageController(initialPage: safeIndex < 0 ? 0 : safeIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.results.isNotEmpty) {
        _warm(safeIndex < 0 ? 0 : safeIndex);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _warm(int index) async {
    if (index < 0 || index >= widget.results.length) return;
    final url = widget.results[index].contentUrl;
    if (url.isEmpty) return;
    try {
      await VideoEngineService.instance.getOrCreateController(url);
    } catch (_) {}
  }

  OjsVideo _video(SearchResult result) {
    return OjsVideo(
      id: result.id,
      creator: result.subtitle.isEmpty ? result.creatorId : result.subtitle,
      caption: result.title,
      videoUrl: result.contentUrl,
      avatarColor: 0xff5d8f8b,
      likes: (result.extra['likes'] as num?)?.toInt() ?? 0,
      comments: 0,
      shares: 0,
      tags: result.tags,
      creatorId: result.creatorId,
      audioTrackId: result.audioTrackId,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No video results',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.results.length,
        onPageChanged: _warm,
        itemBuilder: (context, index) {
          final result = widget.results[index];
          final video = _video(result);
          final creator =
              result.creatorId.isEmpty ? video.creator : result.creatorId;

          return OjsVideoPage(
            video: video,
            isVisible: true,
            isFollowing: false,
            isFollowingFeed: false,
            isLiked: _liked.contains(result.id),
            isSaved: _saved.contains(result.id),
            onLike: () {
              final liked = !_liked.contains(result.id);
              setState(() {
                if (liked) {
                  _liked.add(result.id);
                } else {
                  _liked.remove(result.id);
                }
              });
              _engagement.syncInteraction(
                reelId: result.id,
                liked: liked,
                saved: _saved.contains(result.id),
                likeDelta: liked ? 1 : -1,
              );
            },
            onComment: () {},
            onSave: () {
              final saved = !_saved.contains(result.id);
              setState(() {
                if (saved) {
                  _saved.add(result.id);
                } else {
                  _saved.remove(result.id);
                }
              });
              _engagement.syncInteraction(
                reelId: result.id,
                liked: _liked.contains(result.id),
                saved: saved,
                saveDelta: saved ? 1 : -1,
              );
            },
            onShare: () => ShareBottomSheet.show(
              context,
              videoUrl: result.contentUrl,
              creatorName: creator,
            ),
            onFollow: () {},
            onProfile: () {
              if (result.creatorId.isEmpty) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CreatorProfileScreen(
                    creatorId: result.creatorId,
                    username: creator,
                  ),
                ),
              );
            },
            onAudio: result.audioTrackId.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AudioReelsScreen(
                        audioTrackId: result.audioTrackId,
                        creatorName: creator,
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
