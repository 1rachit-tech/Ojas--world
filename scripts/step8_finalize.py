from pathlib import Path
import re

feed = Path('lib/screens/ojs_feed_screen.dart')
video = Path('lib/widgets/ojs_video_page.dart')
f = feed.read_text()
v = video.read_text()

# Repair accidental literal newlines from earlier helper patches.
f = f.replace(r'\n            isSuperViewActive:', '\n            isSuperViewActive:')
f = f.replace(r'\n          isSuperViewActive:', '\n          isSuperViewActive:')

# Haptic polish: lightImpact for Super View OFF; Step 6 double-tap already uses lightImpact.
f = f.replace('HapticFeedback.selectionClick();\n                            if (_isSuperViewActive) {', 'if (_isSuperViewActive) {', 1)
f = f.replace('setState(() => _isSuperViewActive = false);\n                            } else {', 'setState(() => _isSuperViewActive = false);\n                              HapticFeedback.lightImpact();\n                            } else {', 1)

# Make unseen-page pagination robust: keep fetching cursor pages until five unseen reels are collected.
start = f.index('  Future<void> _loadInitialForYouReels() async {')
end = f.index('\n  OjsVideo _toOjsVideo', start)
load = '''  Future<void> _loadInitialForYouReels() async {\n    if (_forYouLoading) return;\n    setState(() => _forYouLoading = true);\n    try {\n      final collected = <ReelModel>[];\n      DocumentSnapshot<Map<String, dynamic>>? cursor;\n      var hasMore = true;\n      while (collected.length < 5 && hasMore) {\n        final page = await _reelFeedService.fetchPage(cursor: cursor);\n        cursor = page.cursor;\n        hasMore = page.hasMore;\n        for (final reel in page.reels) {\n          if (!_seenReelIds.contains(reel.id)) collected.add(reel);\n          if (collected.length >= 5) break;\n        }\n      }\n      if (!mounted) return;\n      setState(() {\n        _forYouReels\n          ..clear()\n          ..addAll(collected);\n        _forYouCursor = cursor;\n        _forYouHasMore = hasMore;\n        _forYouVisibleIndex = collected.isEmpty ? 0 : 0;\n        _forYouLoading = false;\n      });\n      _markReelSeen(_forYouVisibleIndex);\n      if (_forYouVisibleIndex >= 0 && _forYouVisibleIndex < _forYouReels.length) {\n        _visibleSince = DateTime.now();\n      }\n      await _warmForYouReel(_forYouVisibleIndex + 1);\n    } catch (error) {\n      if (!mounted) return;\n      setState(() => _forYouLoading = false);\n      debugPrint('OJAS For You feed load failed: $error');\n    }\n  }\n\n  Future<void> _fetchMoreForYouReels() async {\n    if (_forYouLoading || !_forYouHasMore || _forYouReels.isEmpty) return;\n    _forYouLoading = true;\n    try {\n      final newReels = <ReelModel>[];\n      var cursor = _forYouCursor;\n      var hasMore = _forYouHasMore;\n      while (newReels.length < 5 && hasMore) {\n        final page = await _reelFeedService.fetchPage(cursor: cursor);\n        cursor = page.cursor;\n        hasMore = page.hasMore;\n        for (final reel in page.reels) {\n          if (!_seenReelIds.contains(reel.id) &&\n              !_forYouReels.any((existing) => existing.id == reel.id) &&\n              !newReels.any((existing) => existing.id == reel.id)) {\n            newReels.add(reel);\n          }\n          if (newReels.length >= 5) break;\n        }\n      }\n      if (!mounted) return;\n      setState(() {\n        _forYouReels.addAll(newReels);\n        _forYouCursor = cursor;\n        _forYouHasMore = hasMore;\n        _forYouLoading = false;\n      });\n    } catch (error) {\n      if (!mounted) return;\n      _forYouLoading = false;\n      debugPrint('OJAS For You next page failed: $error');\n    }\n  }\n'''
f = f[:start] + load + f[end:]

# Flush watch metrics before disposing feed controllers.
f = f.replace('  void dispose() {\n    _horizontalFeedController.dispose();', '  void dispose() {\n    if (_forYouVisibleIndex >= 0) _flushWatchMetrics(_forYouVisibleIndex);\n    _horizontalFeedController.dispose();', 1)
f = f.replace('    if (_forYouVisibleIndex >= 0) _flushWatchMetrics(_forYouVisibleIndex);\n    super.dispose();', '    super.dispose();', 1) if f.count('if (_forYouVisibleIndex >= 0) _flushWatchMetrics(_forYouVisibleIndex);') > 1 else f

# Ensure visible transitions mark seen and start timing for the new reel.
f = re.sub(
    r'  void _setForYouVisibleIndex\(int index\) \{.*?\n  \}\n\n  bool _handleForYouScrollNotification',
    '''  void _setForYouVisibleIndex(int index) {\n    if (_forYouVisibleIndex == index || !mounted) return;\n    if (_forYouVisibleIndex >= 0) _flushWatchMetrics(_forYouVisibleIndex);\n    setState(() => _forYouVisibleIndex = index);\n    if (index >= 0 && index < _forYouReels.length) {\n      _markReelSeen(index);\n      _visibleSince = DateTime.now();\n    } else {\n      _visibleSince = null;\n    }\n  }\n\n  bool _handleForYouScrollNotification''',
    f, count=1, flags=re.S)

# Completion callback wiring from video player to feed aggregation.
if 'onCompleted: () => _completionPending[video.id] = true' not in f:
    f = f.replace(
        '            isSuperViewActive: _isSuperViewActive,\n            onLike:',
        '            isSuperViewActive: _isSuperViewActive,\n            onCompleted: () => _completionPending[video.id] = true,\n            onLike:')
if f.count('onCompleted: () => _completionPending[video.id] = true') != 2:
    raise SystemExit('completion wiring mismatch')

# Video completion callback; do not touch the existing GestureDetector/PageView structure.
if 'final VoidCallback? onCompleted;' not in v:
    v = v.replace('  final VoidCallback? onProfile;\n', '  final VoidCallback? onProfile;\n  final VoidCallback? onCompleted;\n', 1)
if '    this.onCompleted,\n' not in v:
    v = v.replace('    this.onProfile,\n', '    this.onProfile,\n    this.onCompleted,\n', 1)
if 'void _handlePlaybackProgress()' not in v:
    v = v.replace(
        '  void _flushLocalWatchState() {\n    _watchStartedAt = null;\n  }\n',
        '''  void _flushLocalWatchState() {\n    _watchStartedAt = null;\n  }\n\n  void _handlePlaybackProgress() {\n    final value = _controller?.value;\n    if (value == null || !value.isInitialized || value.duration == Duration.zero) return;\n    if (value.position >= value.duration && !value.isPlaying && !_completionQueued) {\n      _completionQueued = true;\n      widget.onCompleted?.call();\n    }\n  }\n''', 1)
if '_controller?.removeListener(_handlePlaybackProgress);' not in v:
    v = v.replace('  void dispose() {\n    _flushLocalWatchState();\n', '  void dispose() {\n    _flushLocalWatchState();\n    _controller?.removeListener(_handlePlaybackProgress);\n', 1)
if '_controller?.addListener(_handlePlaybackProgress);' not in v:
    v = v.replace('    setState(() {\n      _controller = ctrl;\n', '    _controller?.removeListener(_handlePlaybackProgress);\n    _controller = ctrl;\n    _controller?.addListener(_handlePlaybackProgress);\n    setState(() {\n', 1)
v = v.replace('        _watchStartedAt = DateTime.now();\n        _loadAndPlay();', '        _watchStartedAt = DateTime.now();\n        _completionQueued = false;\n        _loadAndPlay();', 1)

# Source invariants.
for token in ('_seenReelIds', '_flushWatchMetrics', 'onCompleted: () => _completionPending[video.id] = true'):
    if token not in f: raise SystemExit(f'Missing feed invariant: {token}')
for token in ('final VoidCallback? onCompleted;', '_handlePlaybackProgress'):
    if token not in v: raise SystemExit(f'Missing video invariant: {token}')

feed.write_text(f)
video.write_text(v)
print('Step 8 finalized')
