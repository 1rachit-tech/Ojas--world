import 'package:flutter/material.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  static const List<String> _categories = <String>[
    '🔥 For You',
    '🎵 Sounds',
    '# Trending',
    '👥 Creators',
  ];

  static const List<String> _suggestions = <String>[
    '@ojascreator',
    '@trendingojas',
    '@creator_ojas',
    '@ojasmusic',
  ];

  int _selectedCategory = 0;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final searching = value.trim().isNotEmpty;
    if (_isSearching == searching) return;
    setState(() => _isSearching = searching);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    if (_isSearching) {
      setState(() => _isSearching = false);
    }
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
                      ? ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.only(top: 4),
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final creator = _suggestions[index];
                            final initial = creator.substring(1, 2).toUpperCase();
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE5E7EB),
                                foregroundColor: const Color(0xFF111827),
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(
                                creator,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () {
                                _searchController.text = creator;
                                _searchController.selection =
                                    TextSelection.collapsed(
                                  offset: creator.length,
                                );
                                _searchFocusNode.unfocus();
                              },
                            );
                          },
                        )
                      : const Center(
                          child: Text(
                            'Masonry Grid Placeholder',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
