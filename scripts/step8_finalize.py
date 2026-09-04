from pathlib import Path

feed = Path('lib/screens/ojs_feed_screen.dart')
video = Path('lib/widgets/ojs_video_page.dart')
f = feed.read_text()
v = video.read_text()

# Repair accidental literal escape sequences without touching feed structure.
f = f.replace('\\n            isSuperViewActive:', '\n            isSuperViewActive:')
f = f.replace('\\n          isSuperViewActive:', '\n          isSuperViewActive:')

# Super View OFF: light haptic only.
f = f.replace(
    'HapticFeedback.selectionClick();\n                            if (_isSuperViewActive) {',
    'if (_isSuperViewActive) {',
    1,
)
f = f.replace(
    'setState(() => _isSuperViewActive = false);\n                            } else {',
    'setState(() => _isSuperViewActive = false);\n                              HapticFeedback.lightImpact();\n                            } else {',
    1,
)

# Completion callback plumbing in both feed pages.
f = f.replace(
    '            isSuperViewActive: _isSuperViewActive,\n            onLike:',
    '            isSuperViewActive: _isSuperViewActive,\n            onCompleted: () => _completionPending[video.id] = true,\n            onLike:',
)

# Flush watch metrics before feed controllers are disposed.
f = f.replace(
    '  void dispose() {\n    _horizontalFeedController.dispose();',
    '  void dispose() {\n    if (_forYouVisibleIndex >= 0) _flushWatchMetrics(_forYouVisibleIndex);\n    _horizontalFeedController.dispose();',
    1,
)

# Start/stop a lightweight wall-clock accumulator around visible reel transitions.
old_visible = '''  void _setForYouVisibleIndex(int index) {
    if (_forYouVisibleIndex == index || !mounted) return;
    if (_forYouVisibleIndex >= 0) _flushWatchMetrics(_forYouVisibleIndex);
    setState(() => _forYouVisibleIndex = index);
    if (index >= 0) _visibleSince = DateTime.now();
  }
'''
new_visible = '''  void _setForYouVisibleIndex(int index) {
    if (_forYouVisibleIndex == index || !mounted) return;
    if (_forYouVisibleIndex >= 0) _flushWatchMetrics(_forYouVisibleIndex);
    setState(() => _forYouVisibleIndex = index);
    if (index >= 0 && index < _forYouReels.length) {
      _seenReelIds.add(_forYouReels[index].id);
      _visibleSince = DateTime.now();
    } else {
      _visibleSince = null;
    }
  }
'''
if old_visible in f:
    f = f.replace(old_visible, new_visible, 1)

# OjsVideoPage completion callback + listener.
if 'final VoidCallback? onCompleted;' not in v:
    v = v.replace('  final VoidCallback? onProfile;\n', '  final VoidCallback? onProfile;\n  final VoidCallback? onCompleted;\n', 1)
if '    this.onCompleted,\n' not in v:
    v = v.replace('    this.onProfile,\n', '    this.onProfile,\n    this.onCompleted,\n', 1)
if 'void _handlePlaybackProgress()' not in v:
    v = v.replace(
        '  void _flushLocalWatchState() {\n    _watchStartedAt = null;\n  }\n',
        '''  void _flushLocalWatchState() {
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
''',
        1,
    )
if '_controller?.removeListener(_handlePlaybackProgress);' not in v:
    v = v.replace(
        '  void dispose() {\n    _flushLocalWatchState();\n',
        '  void dispose() {\n    _flushLocalWatchState();\n    _controller?.removeListener(_handlePlaybackProgress);\n',
        1,
    )
if '_controller?.addListener(_handlePlaybackProgress);' not in v:
    v = v.replace(
        '    setState(() {\n      _controller = ctrl;\n',
        '    _controller?.removeListener(_handlePlaybackProgress);\n    _controller = ctrl;\n    _controller?.addListener(_handlePlaybackProgress);\n    setState(() {\n',
        1,
    )
v = v.replace(
    '        _watchStartedAt = DateTime.now();\n        _loadAndPlay();',
    '        _watchStartedAt = DateTime.now();\n        _completionQueued = false;\n        _loadAndPlay();',
    1,
)

# The interactive caption parser is already present; repair its malformed render call if needed.
v = v.replace(
    '''                    _buildInteractiveCaption(widget.video.caption),
                      maxLines: _isCaptionExpanded ? 8 : 2,
                      overflow: _isCaptionExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
''',
    '                    _buildInteractiveCaption(widget.video.caption),\n',
    1,
)

feed.write_text(f)
video.write_text(v)
