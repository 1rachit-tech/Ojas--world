import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/ojs_video.dart';
import '../services/video_engine_service.dart';
import '../screens/fullscreen_landscape_player.dart';
import '../screens/sound_detail_screen.dart';
import 'reel_shop_products_bottom_sheet.dart';

class OjsVideoPage extends StatefulWidget {
  final OjsVideo video;
  final bool isVisible;
  final bool isFollowing;
  final bool isFollowingFeed;
  final bool isLiked;
  final bool isSaved;
  final bool isSuperViewActive;
  final VoidCallback onFollow;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onSave;
  final VoidCallback? onAudio;
  final VoidCallback? onProfile;
  final VoidCallback? onCompleted;

  const OjsVideoPage({
    super.key,
    required this.video,
    required this.isVisible,
    required this.isFollowing,
    required this.isFollowingFeed,
    required this.isLiked,
    this.isSaved = false,
    this.isSuperViewActive = false,
    required this.onFollow,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.onSave,
    this.onAudio,
    this.onProfile,
    this.onCompleted,
  });

  @override
  State<OjsVideoPage> createState() => _OjsVideoPageState();
}

class _OjsVideoPageState extends State<OjsVideoPage>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInit = false;
  bool _isPlaying = true;
  late bool _isSavedLocal;

  // Double Tap Heart Animation
  bool _showHeartAnim = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  // Scrubbing & Timeline Tracking
  bool _isScrubbing = false;
  double _scrubPosition = 0.0;

  // 2X Speed on Long Press
  bool _isSpeedBoosted = false;
  bool _clearDisplay = false;
  bool _isCaptionExpanded = false;
  DateTime? _watchStartedAt;
  bool _completionQueued = false;

  @override
  void initState() {
    super.initState();
    _isSavedLocal = widget.isSaved;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.25).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    if (widget.isVisible) {
      _watchStartedAt = DateTime.now();
      _loadAndPlay();
    }
  }

  @override
  void dispose() {
    _flushLocalWatchState();
    _controller?.removeListener(_handlePlaybackProgress);
    _animController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OjsVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSaved != oldWidget.isSaved) {
      _isSavedLocal = widget.isSaved;
    }
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _watchStartedAt = DateTime.now();
        _completionQueued = false;
        _loadAndPlay();
      } else {
        _flushLocalWatchState();
        _controller?.pause();
        _isPlaying = false;
        _resetSpeed();
      }
    }
  }

  void _flushLocalWatchState() {
    _watchStartedAt = null;
  }

  void _handlePlaybackProgress() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized || value.duration == Duration.zero) return;
    if (value.position >= value.duration && !value.isPlaying && !_completionQueued) {
      _completionQueued = true;
      widget.onCompleted?.call();
    }
  }

  Future<void> _loadAndPlay() async {
    final ctrl = await VideoEngineService.instance.getOrCreateController(
      widget.video.videoUrl,
    );
    if (!mounted) return;
    _controller?.removeListener(_handlePlaybackProgress);
    _controller = ctrl;
    _controller?.addListener(_handlePlaybackProgress);
    setState(() {
      _isInit = ctrl.value.isInitialized;
      _isPlaying = true;
    });
    if (_isInit && widget.isVisible) {
      await ctrl.setPlaybackSpeed(1.0);
      await ctrl.play();
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInit) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  void _handleDoubleTap() {
    HapticFeedback.lightImpact();
    widget.onLike();
    setState(() => _showHeartAnim = true);
    _animController.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _showHeartAnim = false);
      });
    });
  }

  Future<void> _openGestureOptions() async {
    if (_controller == null || !_isInit) return;
    HapticFeedback.mediumImpact();
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF13171D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const Text(
              'Playback & Display',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Playback Speed',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _speedChip(sheetContext, '1x', 1.0),
                _speedChip(sheetContext, '1.5x', 1.5),
                _speedChip(sheetContext, '2x', 2.0),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.visibility_off_rounded,
                color: Colors.white70,
              ),
              title: const Text(
                'Clear Display',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Hide feed controls temporarily',
                style: TextStyle(color: Colors.white54),
              ),
              trailing: Switch(
                value: _clearDisplay,
                onChanged: (value) => Navigator.pop(
                  sheetContext,
                  value ? 'clear_on' : 'clear_off',
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (selected == 'clear_on') {
      setState(() => _clearDisplay = true);
    } else if (selected == 'clear_off') {
      setState(() => _clearDisplay = false);
    }
  }

  Widget _buildInteractiveCaption(String caption) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'([#@][A-Za-z0-9_]+)');
    int cursor = 0;
    for (final match in regex.allMatches(caption)) {
      if (match.start > cursor) spans.add(TextSpan(text: caption.substring(cursor, match.start)));
      final token = match.group(0)!;
      spans.add(WidgetSpan(child: GestureDetector(onTap: () => debugPrint('OJAS caption route: $token'), child: Text(token, style: const TextStyle(color: Color(0xFF7DD3FC), fontWeight: FontWeight.w700)))));
      cursor = match.end;
    }
    if (cursor < caption.length) spans.add(TextSpan(text: caption.substring(cursor)));
    return RichText(maxLines: _isCaptionExpanded ? 8 : 2, overflow: _isCaptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis, text: TextSpan(style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3, fontWeight: FontWeight.w400), children: spans));
  }

  Widget _speedChip(BuildContext context, String label, double speed) {
    return ActionChip(
      label: Text(label),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: const Color(0xFF222831),
      side: const BorderSide(color: Colors.white10),
      onPressed: () {
        _controller?.setPlaybackSpeed(speed);
        setState(() => _isSpeedBoosted = speed == 2.0);
        Navigator.pop(context);
      },
    );
  }

  void _resetSpeed() {
    if (_isSpeedBoosted && _controller != null && _isInit) {
      setState(() => _isSpeedBoosted = false);
      _controller?.setPlaybackSpeed(1.0);
    }
  }

  void _openSoundHub() {
    HapticFeedback.selectionClick();
    SoundDetailScreen.open(
      context,
      soundTitle: 'Original Audio - ${widget.video.creator}',
      creatorName: widget.video.creator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        _isInit && _controller != null && _controller!.value.aspectRatio > 1.2;

    return Container(
      color: Colors.black,
      child: GestureDetector(
        onTap: () {
          if (_clearDisplay) {
            setState(() => _clearDisplay = false);
          }
          _togglePlayPause();
        },
        onDoubleTap: _handleDoubleTap,
        onLongPress: _openGestureOptions,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Center Video Engine
            if (_isInit && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: isLandscape
                      ? _controller!.value.aspectRatio
                      : 9 / 16,
                  child: ColorFiltered(
                    colorFilter: VideoEngineService.superResolutionEnhancer,
                    child: FittedBox(
                      fit: isLandscape ? BoxFit.contain : BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white30,
                  ),
                ),
              ),

            // 2. Play/Pause Big Center Indicator
            if (!_clearDisplay)
              if (!_isPlaying && _isInit)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                ),

            // 3. Double Tap Heart Pop Animation
            if (!_clearDisplay)
              if (_showHeartAnim)
                Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFEF4444),
                      size: 110,
                    ),
                  ),
                ),

            // 4. 2X Playback Speed Top Minimal Banner
            if (!_clearDisplay)
              if (_isSpeedBoosted)
                Positioned(
                  top: 48,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fast_forward_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '2X Speed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

            // 5. TikTok 16:9 Landscape Fullscreen Button
            if (!_clearDisplay)
              if (isLandscape)
                Positioned(
                  bottom: 180,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () async {
                        await FullscreenLandscapePlayer.open(
                          context,
                          videoUrl: widget.video.videoUrl,
                          title: widget.video.caption,
                          creator: widget.video.creator,
                        );
                        if (!mounted) return;
                        await SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                        ]);
                        await SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.edgeToEdge,
                        );
                        SystemChrome.setSystemUIOverlayStyle(
                          const SystemUiOverlayStyle(
                            statusBarColor: Colors.transparent,
                            statusBarIconBrightness: Brightness.light,
                            systemNavigationBarColor: Colors.black,
                            systemNavigationBarIconBrightness: Brightness.light,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.screen_rotation_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Full screen (Rotate)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

            // 6. Right Action Rail
            if (!_clearDisplay)
              Positioned(
                right: 10,
                bottom: 84 + MediaQuery.of(context).viewPadding.bottom,
                child: IgnorePointer(
                  ignoring: widget.isSuperViewActive,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    opacity: widget.isSuperViewActive ? 0.0 : 1.0,
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (widget.onProfile == null) return;
                            HapticFeedback.selectionClick();
                            widget.onProfile!();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 21,
                              backgroundColor: const Color(0xFF111827),
                              child: Text(
                                widget.video.creator.isNotEmpty
                                    ? widget.video.creator[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -6,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onFollow();
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Container(
                                key: ValueKey<bool>(widget.isFollowing),
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: widget.isFollowing
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  widget.isFollowing
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildActionButton(
                      icon: widget.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: '${widget.video.likes}',
                      color: widget.isLiked
                          ? const Color(0xFFEF4444)
                          : Colors.white,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onLike();
                      },
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      icon: Icons.mode_comment_rounded,
                      label: '${widget.video.comments}',
                      color: Colors.white,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onComment();
                      },
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      icon: _isSavedLocal
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: 'Save',
                      color: _isSavedLocal
                          ? const Color(0xFFF59E0B)
                          : Colors.white,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isSavedLocal = !_isSavedLocal);
                        if (widget.onSave != null) {
                          widget.onSave!();
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isSavedLocal
                                  ? 'Video saved to profile!'
                                  : 'Removed from bookmarks.',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      icon: Icons.reply_rounded,
                      label: 'Share',
                      color: Colors.white,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onShare();
                      },
                    ),
                    const SizedBox(height: 8),

                    GestureDetector(
                      onTap: widget.onAudio ?? _openSoundHub,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1F2937),
                          border: Border.all(color: Colors.white38, width: 2.5),
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),

            // 7. Bottom Metadata
            if (!_clearDisplay)
              Positioned(
                left: 14,
                bottom: 84 + MediaQuery.of(context).viewPadding.bottom,
                right: 84,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.video.shopItemIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ReelShopProductsBottomSheet.show(
                              context,
                              shopItemIds: widget.video.shopItemIds,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5B942)
                                  .withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shopping_bag_rounded,
                                  color: Colors.black,
                                  size: 15,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Shop Products',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.black,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Text(
                          '@${widget.video.creator}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF38BDF8),
                          size: 14,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _buildInteractiveCaption(widget.video.caption),
                    if (widget.video.caption.length > 90)
                      GestureDetector(
                        onTap: () => setState(
                          () => _isCaptionExpanded = !_isCaptionExpanded,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            _isCaptionExpanded ? 'See less' : '...See more',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _openSoundHub,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white70,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Original Audio - @${widget.video.creator}',
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 8. Interactive Timeline Video Scrubber (Bottom Line)
            if (!_clearDisplay)
              if (_isInit && _controller != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 60,
                  child: ValueListenableBuilder(
                    valueListenable: _controller!,
                    builder: (context, VideoPlayerValue val, child) {
                      final duration = val.duration.inMilliseconds.toDouble();
                      final position = val.position.inMilliseconds.toDouble();
                      final currentVal = _isScrubbing
                          ? _scrubPosition
                          : (duration > 0
                                ? (position / duration).clamp(0.0, 1.0)
                                : 0.0);

                      return GestureDetector(
                        onHorizontalDragStart: (details) {
                          setState(() {
                            _isScrubbing = true;
                            _controller?.pause();
                          });
                        },
                        onHorizontalDragUpdate: (details) {
                          final RenderBox box =
                              context.findRenderObject() as RenderBox;
                          final relative =
                              (details.localPosition.dx / box.size.width).clamp(
                                0.0,
                                1.0,
                              );
                          setState(() {
                            _scrubPosition = relative;
                          });
                        },
                        onHorizontalDragEnd: (details) {
                          if (duration > 0) {
                            final targetMs = (_scrubPosition * duration)
                                .toInt();
                            _controller?.seekTo(
                              Duration(milliseconds: targetMs),
                            );
                          }
                          setState(() {
                            _isScrubbing = false;
                            _controller?.play();
                          });
                        },
                        child: Container(
                          height: 14,
                          color: Colors.transparent,
                          alignment: Alignment.bottomCenter,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Container(
                                height: _isScrubbing ? 4 : 2,
                                color: Colors.white24,
                              ),
                              FractionallySizedBox(
                                widthFactor: currentVal,
                                child: Container(
                                  height: _isScrubbing ? 4 : 2,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
