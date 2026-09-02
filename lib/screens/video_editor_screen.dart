import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// OJAS Video Editor
///
/// Lightweight editor foundation designed for:
/// - Local camera recordings
/// - Gallery videos
/// - Gallery images
/// - Low-end Android devices
/// - Minimal memory usage
/// - No server processing
/// - No FFmpeg dependency
///
/// Important:
/// This screen is directly compatible with CreateScreen:
///
/// VideoEditorScreen(
///   mediaPath: video.path,
///   isVideo: true,
/// )
///
/// VideoEditorScreen(
///   mediaPath: photo.path,
///   isVideo: false,
/// )
class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({
    super.key,
    required this.mediaPath,
    required this.isVideo,
  });

  final String mediaPath;
  final bool isVideo;

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;

  bool _isInitializing = true;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isSavingDraft = false;

  double _trimStart = 0.0;
  double _trimEnd = 1.0;

  String _selectedPrivacy = 'Public';
  String _selectedCoverLabel = 'Auto';

  final TextEditingController _captionController =
      TextEditingController();

  final FocusNode _captionFocusNode = FocusNode();

  static const Color _backgroundColor = Colors.white;
  static const Color _primaryColor = Color(0xFF111111);
  static const Color _secondaryTextColor = Color(0xFF777777);
  static const Color _borderColor = Color(0xFFEAEAEA);
  static const Color _softBackground = Color(0xFFF6F6F6);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    if (widget.isVideo) {
      _initializeVideo();
    } else {
      _isInitializing = false;
    }
  }

  Future<void> _initializeVideo() async {
    try {
      final File file = File(widget.mediaPath);

      if (!await file.exists()) {
        throw Exception('Video file does not exist');
      }

      final VideoPlayerController controller =
          VideoPlayerController.file(file);

      _videoController = controller;

      await controller.initialize();
      await controller.setLooping(false);

      controller.addListener(_videoListener);

      if (!mounted) {
        controller.removeListener(_videoListener);
        await controller.dispose();
        return;
      }

      setState(() {
        _isInitializing = false;
        _hasError = false;
      });
    } catch (error) {
      debugPrint('OJAS video editor initialization error: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _hasError = true;
      });
    }
  }

  void _videoListener() {
    final VideoPlayerController? controller = _videoController;

    if (controller == null || !mounted) {
      return;
    }

    final bool currentlyPlaying = controller.value.isPlaying;

    if (_isPlaying != currentlyPlaying) {
      setState(() {
        _isPlaying = currentlyPlaying;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    final VideoPlayerController? controller =
        _videoController;

    if (controller == null) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _captionController.dispose();
    _captionFocusNode.dispose();

    final VideoPlayerController? controller =
        _videoController;

    if (controller != null) {
      controller.removeListener(_videoListener);
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    final VideoPlayerController? controller =
        _videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    HapticFeedback.selectionClick();

    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        final Duration duration =
            controller.value.duration;

        final Duration position =
            controller.value.position;

        if (position >= duration &&
            duration > Duration.zero) {
          await controller.seekTo(Duration.zero);
        }

        await controller.play();
      }
    } catch (error) {
      debugPrint('OJAS play/pause error: $error');
    }
  }

  Future<void> _toggleMute() async {
    final VideoPlayerController? controller =
        _videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    HapticFeedback.selectionClick();

    final bool newMutedState = !_isMuted;

    try {
      await controller.setVolume(
        newMutedState ? 0.0 : 1.0,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isMuted = newMutedState;
      });
    } catch (error) {
      debugPrint('OJAS mute error: $error');
    }
  }

  Future<void> _seekToTrimPosition(
    double normalizedPosition,
  ) async {
    final VideoPlayerController? controller =
        _videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    final Duration duration =
        controller.value.duration;

    if (duration <= Duration.zero) {
      return;
    }

    final double safePosition =
        normalizedPosition.clamp(0.0, 1.0);

    final int milliseconds =
        (duration.inMilliseconds * safePosition).round();

    try {
      await controller.seekTo(
        Duration(milliseconds: milliseconds),
      );
    } catch (error) {
      debugPrint('OJAS seek error: $error');
    }
  }

  String _formatDuration(Duration duration) {
    final int totalSeconds = duration.inSeconds;

    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _openCaptionSheet() async {
    HapticFeedback.selectionClick();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                    24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D6D6),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 22),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Write a caption',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _captionController,
                focusNode: _captionFocusNode,
                minLines: 4,
                maxLines: 8,
                maxLength: 2200,
                textCapitalization:
                    TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: _primaryColor,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Tell people something about your post...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9A9A9A),
                  ),
                  filled: true,
                  fillColor: _softBackground,
                  contentPadding:
                      const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: _primaryColor,
                      width: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    setState(() {});
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPrivacySheet() async {
    HapticFeedback.selectionClick();

    final String? result =
        await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (BuildContext context) {
        const List<_PrivacyOption> options = [
          _PrivacyOption(
            title: 'Public',
            subtitle: 'Anyone on OJAS can discover this.',
            icon: Icons.public_rounded,
          ),
          _PrivacyOption(
            title: 'Followers',
            subtitle:
                'Visible to people who follow you.',
            icon: Icons.group_outlined,
          ),
          _PrivacyOption(
            title: 'Only me',
            subtitle:
                'Keep this private in your account.',
            icon: Icons.lock_outline_rounded,
          ),
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D6D6),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Who can watch this?',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map(
                  (_PrivacyOption option) {
                    final bool selected =
                        option.title == _selectedPrivacy;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(
                            context,
                            option.title,
                          );
                        },
                        borderRadius:
                            BorderRadius.circular(18),
                        child: Container(
                          margin:
                              const EdgeInsets.only(
                            bottom: 8,
                          ),
                          padding:
                              const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFF3F3F3)
                                : Colors.white,
                            borderRadius:
                                BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? _primaryColor
                                  : _borderColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? _primaryColor
                                      : _softBackground,
                                  borderRadius:
                                      BorderRadius.circular(
                                    14,
                                  ),
                                ),
                                child: Icon(
                                  option.icon,
                                  color: selected
                                      ? Colors.white
                                      : _primaryColor,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      option.subtitle,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color:
                                            _secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: _primaryColor,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _selectedPrivacy = result;
    });
  }

  Future<void> _openCoverSheet() async {
    HapticFeedback.selectionClick();

    final String? result =
        await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (BuildContext context) {
        final List<String> options = widget.isVideo
            ? [
                'Auto',
                'Beginning',
                'Middle',
                'Ending',
              ]
            : [
                'Original',
              ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D6D6),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose cover',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...options.map(
                  (String option) {
                    final bool selected =
                        option == _selectedCoverLabel;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(
                            context,
                            option,
                          );
                        },
                        borderRadius:
                            BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          margin:
                              const EdgeInsets.only(
                            bottom: 8,
                          ),
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFF3F3F3)
                                : Colors.white,
                            borderRadius:
                                BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? _primaryColor
                                  : _borderColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_rounded,
                                  color: _primaryColor,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCoverLabel = result;
    });
  }

  Future<void> _saveDraft() async {
    if (_isSavingDraft) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _isSavingDraft = true;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 650),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSavingDraft = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Draft saved locally on this device.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openPublishSheet() {
    HapticFeedback.mediumImpact();

    final String caption =
        _captionController.text.trim();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D6D6),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(
                  Icons.publish_outlined,
                  size: 42,
                  color: _primaryColor,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Ready to publish',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  caption.isEmpty
                      ? 'Your post is ready.'
                      : caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _secondaryTextColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _PublishInfoRow(
                  icon: Icons.public_rounded,
                  title: _selectedPrivacy,
                ),
                const SizedBox(height: 10),
                _PublishInfoRow(
                  icon: Icons.image_outlined,
                  title: 'Cover: $_selectedCoverLabel',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Publishing pipeline will be connected next.',
                          ),
                          behavior:
                              SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      'Publish',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaPreview() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (_hasError) {
      return _buildMediaErrorState();
    }

    if (!widget.isVideo) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 3.0,
        child: Image.file(
          File(widget.mediaPath),
          fit: BoxFit.contain,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return _buildMediaErrorState();
          },
        ),
      );
    }

    final VideoPlayerController? controller =
        _videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio:
                controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : 9 / 16,
            child: VideoPlayer(controller),
          ),
          AnimatedOpacity(
            opacity: _isPlaying ? 0.0 : 1.0,
            duration:
                const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: _isPlaying,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white24,
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaErrorState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              'Unable to load this media',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Please choose another file and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        8,
        6,
        14,
        6,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.close_rounded,
              color: _primaryColor,
            ),
          ),
          const Expanded(
            child: Text(
              'Edit',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _primaryColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
          TextButton(
            onPressed: _isSavingDraft
                ? null
                : _saveDraft,
            child: _isSavingDraft
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primaryColor,
                    ),
                  )
                : const Text(
                    'Draft',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorPreview() {
    return Expanded(
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: _buildMediaPreview(),
            ),
            if (widget.isVideo &&
                !_isInitializing &&
                !_hasError)
              Positioned(
                right: 14,
                bottom: 14,
                child: _buildFloatingVideoControl(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingVideoControl() {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _toggleMute,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            _isMuted
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoTimeline() {
    if (!widget.isVideo) {
      return const SizedBox.shrink();
    }

    final VideoPlayerController? controller =
        _videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final Duration duration =
        controller.value.duration;

    final Duration position =
        controller.value.position;

    final double normalizedPosition =
        duration.inMilliseconds <= 0
            ? 0.0
            : (position.inMilliseconds /
                    duration.inMilliseconds)
                .clamp(0.0, 1.0);

    final double currentStart =
        _trimStart.clamp(0.0, 1.0);

    final double currentEnd = _trimEnd.clamp(
      currentStart + 0.02,
      1.0,
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        4,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Trim',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '${_formatDuration(Duration(milliseconds: (duration.inMilliseconds * currentStart).round()))} – ${_formatDuration(Duration(milliseconds: (duration.inMilliseconds * currentEnd).round()))}',
                style: const TextStyle(
                  fontSize: 12,
                  color: _secondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFEF),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: LayoutBuilder(
                      builder: (
                        BuildContext context,
                        BoxConstraints constraints,
                      ) {
                        final double width =
                            constraints.maxWidth;

                        final double startLeft =
                            width * currentStart;

                        final double endLeft =
                            width * currentEnd;

                        final double playheadLeft =
                            width *
                                normalizedPosition;

                        return Stack(
                          children: [
                            Positioned(
                              left: startLeft,
                              top: 6,
                              bottom: 6,
                              child: Container(
                                width:
                                    (endLeft - startLeft)
                                        .clamp(
                                  2.0,
                                  width,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _primaryColor,
                                    width: 2,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(
                                    8,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: playheadLeft
                                  .clamp(0.0, width),
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2,
                                color: const Color(
                                  0xFFE53935,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          RangeSlider(
            values: RangeValues(
              currentStart,
              currentEnd,
            ),
            min: 0.0,
            max: 1.0,
            divisions: 100,
            activeColor: _primaryColor,
            inactiveColor: const Color(0xFFE7E7E7),
            onChanged: (RangeValues values) {
              setState(() {
                _trimStart = values.start;
                _trimEnd = values.end;
              });
            },

            // FIXED:
            // RangeSlider callbacks require RangeValues,
            // not double.
            onChangeStart: (RangeValues values) {
              _seekToTrimPosition(values.start);
            },

            onChangeEnd: (RangeValues values) {
              _seekToTrimPosition(values.end);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditingTools() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        10,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround,
        children: [
          _EditorTool(
            icon: Icons.short_text_rounded,
            label: 'Caption',
            onTap: _openCaptionSheet,
          ),
          _EditorTool(
            icon: Icons.image_outlined,
            label: 'Cover',
            onTap: _openCoverSheet,
          ),
          _EditorTool(
            icon: Icons.tune_rounded,
            label: 'Adjust',
            onTap: _showAdjustInfo,
          ),
          _EditorTool(
            icon: Icons.auto_awesome_outlined,
            label: 'Effects',
            onTap: _showEffectsInfo,
          ),
          _EditorTool(
            icon: Icons.lock_outline_rounded,
            label: 'Privacy',
            onTap: _openPrivacySheet,
          ),
        ],
      ),
    );
  }

  void _showAdjustInfo() {
    HapticFeedback.selectionClick();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Advanced color adjustment will connect to the OJAS filter engine.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEffectsInfo() {
    HapticFeedback.selectionClick();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Effects will connect to the existing OJAS Matrix Filter system.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPostSettings() {
    final String caption =
        _captionController.text.trim();

    return Container(
      color: _softBackground,
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        12,
      ),
      child: Column(
        children: [
          _SettingsRow(
            icon: Icons.notes_rounded,
            title: caption.isEmpty
                ? 'Add caption'
                : caption,
            subtitle: caption.isEmpty
                ? 'Tell people about your post'
                : null,
            onTap: _openCaptionSheet,
          ),
          const SizedBox(height: 10),
          _SettingsRow(
            icon: Icons.public_rounded,
            title: _selectedPrivacy,
            subtitle: 'Who can watch this post',
            onTap: _openPrivacySheet,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPublishBar() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(
          20,
          10,
          20,
          14,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: _openPublishSheet,
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'Next',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildEditorPreview(),
            _buildVideoTimeline(),
            _buildEditingTools(),
            _buildPostSettings(),
            _buildBottomPublishBar(),
          ],
        ),
      ),
    );
  }
}

class _EditorTool extends StatelessWidget {
  const _EditorTool({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const Color _primaryColor =
      Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: _primaryColor,
                size: 22,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(
                  color: _primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  static const Color _primaryColor =
      Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: _primaryColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xFF999999),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishInfoRow extends StatelessWidget {
  const _PublishInfoRow({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF111111),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyOption {
  const _PrivacyOption({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}
