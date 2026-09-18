import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../screens/creator_profile_screen.dart';
import '../../../../screens/hashtag_feed_screen.dart';
import '../../../../screens/sound_detail_screen.dart';
import '../domain/search_models.dart';
import '../search_history.dart';
import '../search_orchestrator.dart';
import 'search_viewer_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.initialQuery = '',
    this.embedded = false,
  });

  final String initialQuery;
  final bool embedded;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchOrchestrator _orchestrator = SearchOrchestrator();
  final SearchHistoryStore _historyStore = SearchHistoryStore();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  SearchTab _selectedTab = SearchTab.all;
  List<SearchSuggestion> _suggestions = const <SearchSuggestion>[];
  List<String> _history = const <String>[];
  List<SearchResult> _results = const <SearchResult>[];
  String? _nextCursor;
  String? _didYouMean;
  String? _error;
  bool _loading = false;
  bool _loadingSuggestions = false;
  bool _focused = false;
  bool _submitted = false;
  bool _hasOfflineCache = false;
  int _requestId = 0;
  String _lastSubmittedQuery = '';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _orchestrator.beginSession();
    _focusNode.addListener(_focusChanged);
    _controller.addListener(_queryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _orchestrator.initialize();
      if (!mounted) return;
      _history = await _historyStore.load(uid: _uid);
      if (mounted) setState(() {});

      if (widget.initialQuery.trim().isNotEmpty) {
        _controller.text = widget.initialQuery.trim();
        _focusNode.requestFocus();
        await _submit();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode
      ..removeListener(_focusChanged)
      ..dispose();
    _controller
      ..removeListener(_queryChanged)
      ..dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  void _queryChanged() {
    final query = _controller.text.trim();
    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _submitted = false;
        _loading = false;
        _error = null;
        _didYouMean = null;
        _results = const <SearchResult>[];
      });
      _loadRecent();
      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 220),
      () => _loadSuggestions(query),
    );
    if (mounted) {
      setState(() {
        _submitted = false;
        _error = null;
      });
    }
  }

  Future<void> _loadRecent() async {
    final history = await _historyStore.load(uid: _uid);
    if (!mounted) return;
    setState(() => _history = history);
  }

  Future<void> _loadSuggestions(String query) async {
    if (!mounted) return;
    setState(() => _loadingSuggestions = true);

    try {
      final values = await _orchestrator.suggestions(query);
      if (!mounted) return;
      setState(() {
        _suggestions = values;
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = const <SearchSuggestion>[];
        _loadingSuggestions = false;
      });
    }
  }

  Future<void> _submit() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    _focusNode.unfocus();
    _debounce?.cancel();

    final requestId = ++_requestId;
    setState(() {
      _submitted = true;
      _loading = true;
      _error = null;
      _didYouMean = null;
      _results = const <SearchResult>[];
      _nextCursor = null;
      _hasOfflineCache = false;
    });

    try {
      final page = await _orchestrator.search(
        query,
        tab: _selectedTab,
        pageSize: 20,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = page.results;
        _nextCursor = page.cursor;
        _didYouMean = page.didYouMean;
        _hasOfflineCache = page.offline;
        _loading = false;
        _lastSubmittedQuery = query;
      });
      _loadRecent();
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = 'Search is temporarily unavailable. Please try again.';
      });
      debugPrint('OJAS Search failed: $error');
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _nextCursor == null || _lastSubmittedQuery.isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      final page = await _orchestrator.search(
        _lastSubmittedQuery,
        tab: _selectedTab,
        pageSize: 20,
        cursor: _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        _results = <SearchResult>[..._results, ...page.results];
        _nextCursor = page.cursor;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectSuggestion(SearchSuggestion suggestion) async {
    HapticFeedback.selectionClick();
    await _orchestrator.recordSuggestionClick(
      suggestion,
      _controller.text.trim(),
    );

    if (suggestion.entityType == SearchEntityType.person &&
        suggestion.id.isNotEmpty) {
      _openProfile(suggestion.id);
      return;
    }

    _controller.text = suggestion.text;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    await _submit();
  }

  void _clear() {
    HapticFeedback.selectionClick();
    _controller.clear();
    _focusNode.requestFocus();
  }

  Future<void> _deleteHistory(String query) async {
    await _historyStore.remove(query, uid: _uid);
    await _loadRecent();
  }

  Future<void> _clearHistory() async {
    await _historyStore.clear(uid: _uid);
    await _loadRecent();
  }

  void _selectTab(SearchTab tab) {
    if (_selectedTab == tab) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedTab = tab);
    if (_controller.text.trim().isNotEmpty) {
      _submit();
    }
  }

  void _openResult(SearchResult result, int index) {
    HapticFeedback.selectionClick();
    _orchestrator.recordResultClick(
      result,
      index,
      _controller.text.trim(),
    );

    switch (result.entityType) {
      case SearchEntityType.person:
        _openProfile(result.id);
        return;
      case SearchEntityType.hashtag:
        HashtagFeedScreen.open(
          context,
          hashtag: result.title,
        );
        return;
      case SearchEntityType.sound:
        SoundDetailScreen.open(
          context,
          soundTitle: result.title,
          creatorName: result.subtitle,
        );
        return;
      case SearchEntityType.content:
        final videos = _results
            .where((item) =>
                item.entityType == SearchEntityType.content &&
                item.contentUrl.trim().isNotEmpty)
            .toList(growable: false);
        final videoIndex = videos.indexWhere((item) => item.id == result.id);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SearchViewerScreen(
              results: videos,
              initialIndex: videoIndex < 0 ? 0 : videoIndex,
              query: _controller.text.trim(),
            ),
          ),
        );
        return;
      case SearchEntityType.topic:
      case SearchEntityType.place:
      case SearchEntityType.live:
      case SearchEntityType.generic:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.title.isEmpty
                  ? 'This destination is not available yet.'
                  : result.title,
            ),
          ),
        );
        return;
    }
  }

  void _openProfile(String uid) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatorProfileScreen(
          creatorId: uid,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          if (widget.embedded)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF101828),
                ),
              ),
            ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _focused
                      ? const Color(0xFF101828)
                      : const Color(0xFFE4E7EC),
                  width: _focused ? 1.2 : 1,
                ),
                boxShadow: _focused
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 18,
                          offset: Offset(0, 7),
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.initialQuery.isEmpty,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: true,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
                    child: Icon(
                      Icons.search_rounded,
                      color: Color(0xFF667085),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  hintText: 'Search creators, Show, tags & sounds',
                  hintStyle: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: _clear,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF667085),
                            size: 19,
                          ),
                        ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 0,
                  ),
                ),
              ),
            ),
          ),
          if (!widget.embedded) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _focusNode.unfocus(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF101828),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 1, 16, 7),
        scrollDirection: Axis.horizontal,
        itemCount: SearchTab.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final tab = SearchTab.values[index];
          final selected = tab == _selectedTab;
          return Material(
            color: selected
                ? const Color(0xFF101828)
                : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _selectTab(tab),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF101828)
                        : const Color(0xFFE4E7EC),
                  ),
                ),
                child: Text(
                  tab.label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : const Color(0xFF475467),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                Color(0xFFF7F8FA),
                Color(0xFFFFFFFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: Color(0xFF101828),
                child: Icon(
                  Icons.travel_explore_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover OJAS',
                      style: TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Creators, Show, sounds, hashtags, topics and places — all in one search.',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent searches',
                style: TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (_history.isNotEmpty)
              TextButton(
                onPressed: _clearHistory,
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (_history.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Your recent searches will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF98A2B3),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ..._history.map(
            (query) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    _controller.text = query;
                    _submit();
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          color: Color(0xFF667085),
                          size: 19,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            query,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF344054),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _deleteHistory(query),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF98A2B3),
                            size: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSuggestions() {
    if (_loadingSuggestions) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.1,
            color: Color(0xFF101828),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'No live suggestions yet. Keep typing to search the full OJAS index.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF98A2B3),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 24),
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = _suggestions[index];
        return Material(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () => _selectSuggestion(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 11,
              ),
              child: Row(
                children: [
                  _SuggestionIcon(suggestion: item),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF101828),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_upward_rounded,
                    color: Color(0xFF98A2B3),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResults() {
    if (_loading && _results.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Color(0xFF111827),
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFF9CA3AF),
                size: 42,
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                color: Color(0xFF9CA3AF),
                size: 42,
              ),
              const SizedBox(height: 10),
              Text(
                _didYouMean == null
                    ? 'No results found'
                    : 'No results. Did you mean ' + _didYouMean! + '?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_hasOfflineCache) ...[
                const SizedBox(height: 8),
                const Text(
                  'Showing the latest cached data when available.',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 280) {
          _loadMore();
        }
        return false;
      },
      child: ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(top: 4, bottom: 30),
        itemCount: _results.length + (_loading ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
        itemBuilder: (_, index) {
          if (index >= _results.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            );
          }
          final result = _results[index];
          return _SearchResultTile(
            result: result,
            onTap: () => _openResult(result, index),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions = _focused && !_submitted;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: const Color(0xFFF9FAFB),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 54,
              titleSpacing: 16,
              title: const Text(
                'Discover',
                style: TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEAECF0),
                      ),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFF475467),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
      body: SafeArea(
        top: widget.embedded,
        child: Column(
          children: [
            _buildSearchField(),
            _buildTabs(),
            const SizedBox(height: 2),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: showSuggestions
                    ? (_controller.text.trim().isEmpty
                        ? _buildRecent()
                        : _buildSuggestions())
                    : _buildResults(),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _SuggestionIcon extends StatelessWidget {
  const _SuggestionIcon({required this.suggestion});

  final SearchSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    if (suggestion.imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: CachedNetworkImageProvider(
          suggestion.imageUrl,
        ),
        backgroundColor: const Color(0xFFE5E7EB),
      );
    }

    final IconData icon = switch (suggestion.entityType) {
      SearchEntityType.person => Icons.person_outline_rounded,
      SearchEntityType.content => Icons.play_arrow_rounded,
      SearchEntityType.hashtag => Icons.tag_rounded,
      SearchEntityType.sound => Icons.music_note_rounded,
      SearchEntityType.topic => Icons.topic_outlined,
      SearchEntityType.place => Icons.location_on_outlined,
      SearchEntityType.live => Icons.live_tv_outlined,
      SearchEntityType.generic => Icons.history_rounded,
    };

    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFF3F4F6),
      child: Icon(
        icon,
        color: const Color(0xFF111827),
        size: 20,
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.onTap,
  });

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = result.entityType == SearchEntityType.content;
    final accent = switch (result.entityType) {
      SearchEntityType.person => const Color(0xFFEEF2FF),
      SearchEntityType.content => const Color(0xFFF4F3FF),
      SearchEntityType.hashtag => const Color(0xFFFFF7ED),
      SearchEntityType.sound => const Color(0xFFFDF2F8),
      SearchEntityType.topic => const Color(0xFFECFDF3),
      SearchEntityType.place => const Color(0xFFEFF8FF),
      SearchEntityType.live => const Color(0xFFFFF1F2),
      SearchEntityType.generic => const Color(0xFFF2F4F7),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEAECF0)),
            ),
            child: Row(
              children: [
                _Leading(result: result),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              result.title.isEmpty
                                  ? 'OJAS result'
                                  : result.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF101828),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                            ),
                          ),
                          if (result.entityType == SearchEntityType.live)
                            const _MiniBadge(
                              label: 'LIVE',
                              background: Color(0xFFFFE4E6),
                              foreground: Color(0xFFBE123C),
                            ),
                        ],
                      ),
                      if (result.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          result.entityType == SearchEntityType.person &&
                                  !result.subtitle.startsWith('@')
                              ? '@' + result.subtitle
                              : result.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              _typeLabel(result.entityType),
                              style: const TextStyle(
                                color: Color(0xFF344054),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              _meta(result),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF98A2B3),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            visual
                                ? Icons.play_circle_fill_rounded
                                : Icons.chevron_right_rounded,
                            color: const Color(0xFF98A2B3),
                            size: visual ? 21 : 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _typeLabel(SearchEntityType type) {
    return switch (type) {
      SearchEntityType.person => 'Creator',
      SearchEntityType.content => 'Show',
      SearchEntityType.hashtag => 'Hashtag',
      SearchEntityType.sound => 'Sound',
      SearchEntityType.topic => 'Topic',
      SearchEntityType.place => 'Place',
      SearchEntityType.live => 'LIVE',
      SearchEntityType.generic => 'Search',
    };
  }

  String _meta(SearchResult result) {
    final views = result.extra['views'];
    final followers = result.extra['followers'];

    switch (result.entityType) {
      case SearchEntityType.person:
        return followers is num
            ? followers.toInt().toString() + ' followers'
            : 'OJAS creator';
      case SearchEntityType.content:
        return views is num
            ? views.toInt().toString() + ' views'
            : 'OJAS Show';
      case SearchEntityType.hashtag:
        return 'Community topic';
      case SearchEntityType.sound:
        return 'Audio discovery';
      case SearchEntityType.topic:
        return 'Topic discovery';
      case SearchEntityType.place:
        return 'Place discovery';
      case SearchEntityType.live:
        return 'Live now';
      case SearchEntityType.generic:
        return 'Search result';
    }
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context) {
    if (result.entityType == SearchEntityType.content &&
        result.imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: result.imageUrl,
          width: 54,
          height: 70,
          fit: BoxFit.cover,
          placeholder: (_, __) => const ColoredBox(
            color: Color(0xFFF3F4F6),
            child: Icon(
              Icons.image_outlined,
              color: Color(0xFF9CA3AF),
            ),
          ),
          errorWidget: (_, __, ___) => const ColoredBox(
            color: Color(0xFFF3F4F6),
            child: Icon(
              Icons.broken_image_outlined,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
      );
    }

    final icon = switch (result.entityType) {
      SearchEntityType.person => Icons.person_outline_rounded,
      SearchEntityType.content => Icons.play_arrow_rounded,
      SearchEntityType.hashtag => Icons.tag_rounded,
      SearchEntityType.sound => Icons.music_note_rounded,
      SearchEntityType.topic => Icons.topic_outlined,
      SearchEntityType.place => Icons.location_on_outlined,
      SearchEntityType.live => Icons.live_tv_outlined,
      SearchEntityType.generic => Icons.search_rounded,
    };

    return CircleAvatar(
      radius: 25,
      backgroundColor: const Color(0xFFF3F4F6),
      backgroundImage: result.imageUrl.isNotEmpty
          ? CachedNetworkImageProvider(result.imageUrl)
          : null,
      child: result.imageUrl.isNotEmpty
          ? null
          : Icon(
              icon,
              color: const Color(0xFF111827),
              size: 23,
            ),
    );
  }
}
