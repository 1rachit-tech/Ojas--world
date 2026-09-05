import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'creator_profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  static const List<String> _categories = <String>[
    '🔥 For You',
    '🎵 Sounds',
    '# Trending',
    '👥 Creators',
  ];

  static const List<String> _viewCounts = <String>[
    '1.2M',
    '34K',
    '820K',
    '56K',
    '2.4M',
    '91K',
    '640K',
    '18K',
    '3.1M',
    '77K',
    '450K',
    '29K',
    '1.8M',
    '63K',
    '710K',
    '42K',
    '950K',
    '105K',
  ];

  static const List<double> _tileHeights = <double>[
    220,
    300,
    250,
    300,
    220,
    250,
    300,
    220,
    250,
    300,
    220,
    250,
    300,
    220,
    250,
    300,
    220,
    250,
  ];

  int _selectedCategory = 0;
  bool _isSearching = false;
  bool _isLoading = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _searchResults =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  int _searchRequestId = 0;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    final query = value.trim().toLowerCase();
    if (query.isEmpty) {
      _searchRequestId++;
      if (mounted) {
        setState(() {
          _isSearching = false;
          _isLoading = false;
          _searchResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        });
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoading = true;
      _searchResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    });

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      searchUsers(query);
    });
  }

  Future<void> searchUsers(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return;
    }

    final int requestId = ++_searchRequestId;
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(
            'username',
            isGreaterThanOrEqualTo: normalizedQuery,
          )
          .where(
            'username',
            isLessThan: '$normalizedQuery' 'z',
          )
          .limit(20)
          .get();

      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = snapshot.docs;
        _isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      debugPrint('OJAS Discover user search failed: ${error.message}');
      setState(() {
        _searchResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      debugPrint('OJAS Discover user search failed: $error');
      setState(() {
        _searchResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchRequestId++;
    _searchController.clear();
    _searchFocusNode.unfocus();
    if (mounted) {
      setState(() {
        _isSearching = false;
        _isLoading = false;
        _searchResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      });
    }
  }

  void _openProfile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawUid = data['uid'];
    final uid = rawUid is String && rawUid.trim().isNotEmpty
        ? rawUid.trim()
        : doc.id;
    if (uid.isEmpty) return;

    final username = data['username'] is String
        ? (data['username'] as String).trim()
        : '';
    final name = data['name'] is String
        ? (data['name'] as String).trim()
        : data['displayName'] is String
            ? (data['displayName'] as String).trim()
            : '';

    _searchFocusNode.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatorProfileScreen(
          creatorId: uid,
          username: username.isNotEmpty
              ? username
              : (name.isNotEmpty ? name : 'OJAS Creator'),
          creatorName: name.isNotEmpty ? name : username,
          avatarColor: const Color(0xFFE5E7EB),
        ),
      ),
    );
  }

  Widget _searchResultsView() {
    if (_isLoading && _searchResults.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 4),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final doc = _searchResults[index];
        final data = doc.data();
        final username = data['username'] is String
            ? (data['username'] as String).trim()
            : '';
        final name = data['name'] is String
            ? (data['name'] as String).trim()
            : data['displayName'] is String
                ? (data['displayName'] as String).trim()
                : 'OJAS User';
        final imageUrl = data['profileImageUrl'] is String
            ? (data['profileImageUrl'] as String).trim()
            : data['photoUrl'] is String
                ? (data['photoUrl'] as String).trim()
                : '';
        final initialSource = name.isNotEmpty
            ? name
            : (username.isNotEmpty ? username : 'O');
        final initial = initialSource.substring(0, 1).toUpperCase();

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFE5E7EB),
            child: ClipOval(
              child: imageUrl.isEmpty
                  ? Text(
                      initial,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          title: Text(
            name.isNotEmpty ? name : '@$username',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            username.isEmpty ? '@ojasuser' : '@$username',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
          onTap: () => _openProfile(doc),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: Theme.of(context).colorScheme.copyWith(
              brightness: Brightness.light,
              onSurface: const Color(0xFF111827),
            ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _searchFocusNode.unfocus,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    enableSuggestions: true,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search OJAS IDs, tags, or sounds...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF6B7280),
                      ),
                      suffixIcon: _isSearching
                          ? IconButton(
                              tooltip: 'Clear search',
                              onPressed: _clearSearch,
                              icon: const Icon(
                                Icons.cancel,
                                color: Color(0xFF6B7280),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: List<Widget>.generate(_categories.length, (index) {
                        final selected = index == _selectedCategory;
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index == _categories.length - 1 ? 0 : 8,
                          ),
                          child: ChoiceChip(
                            label: Text(_categories[index]),
                            selected: selected,
                            onSelected: (_) {
                              if (selected) return;
                              setState(() => _selectedCategory = index);
                            },
                            backgroundColor: Colors.white,
                            selectedColor: Colors.black,
                            side: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            showCheckmark: false,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isSearching
                      ? _searchResultsView()
                      : MasonryGridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          gridDelegate:
                              const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                          ),
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                          itemCount: _tileHeights.length,
                          itemBuilder: (context, index) {
                            return _MasonryVideoCard(
                              index: index,
                              height: _tileHeights[index],
                              viewCount: _viewCounts[index],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MasonryVideoCard extends StatelessWidget {
  const _MasonryVideoCard({
    required this.index,
    required this.height,
    required this.viewCount,
  });

  final int index;
  final double height;
  final String viewCount;

  @override
  Widget build(BuildContext context) {
    final imageUrl = 'https://picsum.photos/seed/$index/400/600';

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => ColoredBox(
                color: Colors.grey.shade300,
              ),
              errorWidget: (_, __, ___) => ColoredBox(
                color: Colors.grey.shade300,
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 92,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        Color(0xB3000000),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_arrow_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    viewCount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
