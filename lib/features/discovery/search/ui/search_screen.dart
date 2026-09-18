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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          if (widget.embedded)
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF111827),
              ),
            ),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: _focused
                      ? const Color(0xFFD1D5DB)
                      : Colors.transparent,
                ),
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
                  color: Color(0xFF111827),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF6B7280),
                  ),
                  hintText: 'Search people, videos, tags, sounds...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: _clear,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF6B7280),
                            size: 20,
                          ),
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          if (widget.embedded)
            const SizedBox(width: 8)
          else
            TextButton(
              onPressed: () => _focusNode.unfocus(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: SearchTab.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final tab = SearchTab.values[index];
          final selected = tab == _selectedTab;
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text(tab.label),
            onSelected: (_) => _selectTab(tab),
            selectedColor: const Color(0xFF111827),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? const Color(0xFF111827)
                  : const Color(0xFFE5E7EB),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF374151),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecent() {
    if (_history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Search OJAS for creators, sounds, hashtags, videos and more.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 12, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent searches',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _clearHistory,
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._history.map(
          (query) => ListTile(
            dense: true,
            leading: const Icon(
              Icons.history_rounded,
              color: Color(0xFF6B7280),
              size: 20,
            ),
            title: Text(
              query,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: IconButton(
              tooltip: 'Remove',
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF9CA3AF),
                size: 18,
              ),
              onPressed: () => _deleteHistory(query),
            ),
            onTap: () {
              _controller.text = query;
              _submit();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    if (_loadingSuggestions) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: LinearProgressIndicator(
          minHeight: 2,
          color: Color(0xFF111827),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: Text(
            'No suggestions yet',
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 4),
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
      itemBuilder: (_, index) {
        final item = _suggestions[index];
        return ListTile(
          minVerticalPadding: 6,
          leading: _SuggestionIcon(suggestion: item),
          title: Text(
            item.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          subtitle: item.subtitle.isEmpty
              ? null
              : Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
          onTap: () => _selectSuggestion(item),
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
      backgroundColor: Colors.white,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                'Search',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
            ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchField(),
            _buildTabs(),
            const SizedBox(height: 4),
            Expanded(
              child: showSuggestions
                  ? (_controller.text.trim().isEmpty
                      ? _buildRecent()
                      : _buildSuggestions())
                  : _buildResults(),
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
    final isVisual = result.entityType == SearchEntityType.content;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 4,
      ),
      leading: _Leading(result: result),
      title: Text(
        result.title.isEmpty ? 'OJAS result' : result.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.subtitle.isNotEmpty)
            Text(
              result.entityType == SearchEntityType.person &&
                      !result.subtitle.startsWith('@')
                  ? '@' + result.subtitle
                  : result.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 3),
          Text(
            _meta(result),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
            ),
          ),
        ],
      ),
      trailing: isVisual
          ? const Icon(
              Icons.play_arrow_rounded,
              color: Color(0xFF111827),
            )
          : const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
            ),
      onTap: onTap,
    );
  }

  String _meta(SearchResult result) {
    switch (result.entityType) {
      case SearchEntityType.person:
        final followers = result.extra['followers'];
        return followers is num
            ? followers.toInt().toString() + ' followers'
            : 'OJAS creator';
      case SearchEntityType.content:
        final views = result.extra['views'];
        return views is num
            ? views.toInt().toString() + ' views'
            : 'OJAS Show';
      case SearchEntityType.hashtag:
        return 'Hashtag';
      case SearchEntityType.sound:
        return 'Sound';
      case SearchEntityType.topic:
        return 'Topic';
      case SearchEntityType.place:
        return 'Place';
      case SearchEntityType.live:
        return 'LIVE';
      case SearchEntityType.generic:
        return 'Search';
    }
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
