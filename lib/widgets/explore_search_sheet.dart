import 'package:flutter/material.dart';
import '../screens/creator_profile_screen.dart';

class ExploreSearchSheet extends StatefulWidget {
  const ExploreSearchSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ExploreSearchSheet(),
    );
  }

  @override
  State<ExploreSearchSheet> createState() => _ExploreSearchSheetState();
}

class _ExploreSearchSheetState extends State<ExploreSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _activeTab = 0; // 0: Top, 1: Accounts, 2: Tags, 3: Audio

  List<String> _recentSearches = [
    'Maya Chen',
    '#VindhyaBeats',
    'Lofi Ambient',
    'Cinematic 4K',
  ];

  final List<Map<String, dynamic>> _mockAccounts = [
    {'name': 'Maya Chen', 'handle': '@mayamakes', 'followers': '142K', 'color': Color(0xFFE5A87B)},
    {'name': 'Rohan Mehta', 'handle': '@rohanbuilds', 'followers': '89K', 'color': Color(0xFF93C5FD)},
    {'name': 'Sneha Sharma', 'handle': '@sneha_09', 'followers': '210K', 'color': Color(0xFFC5C6E9)},
    {'name': 'Ayush Patel', 'handle': '@ayush_01', 'followers': '45K', 'color': Color(0xFFF4C2C2)},
  ];

  final List<Map<String, dynamic>> _mockTags = [
    {'tag': '#OJASOriginals', 'posts': '1.4M posts'},
    {'tag': '#VindhyaBeats', 'posts': '520K posts'},
    {'tag': '#CinematicShots', 'posts': '890K posts'},
    {'tag': '#FolkFusion', 'posts': '310K posts'},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.toLowerCase().trim();

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E242C),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFFF5B942), size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Search creators, tags, music...',
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _searchCtrl.clear()),
                            child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filter Tabs
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSearchTab('Top', 0),
                _buildSearchTab('Accounts', 1),
                _buildSearchTab('Tags', 2),
                _buildSearchTab('Audio', 3),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 16),

          // Search Results or Recent Searches
          Expanded(
            child: query.isEmpty
                ? _buildRecentSearches()
                : _buildFilteredResults(query),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab(String title, int index) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5B942) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Searches', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
            GestureDetector(
              onTap: () => setState(() => _recentSearches.clear()),
              child: const Text('Clear all', style: TextStyle(color: Color(0xFFF5B942), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._recentSearches.map((item) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_rounded, color: Colors.white38),
            title: Text(item, style: const TextStyle(color: Colors.white, fontSize: 14)),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.white38, size: 18),
              onPressed: () => setState(() => _recentSearches.remove(item)),
            ),
            onTap: () => setState(() => _searchCtrl.text = item),
          );
        }),
      ],
    );
  }

  Widget _buildFilteredResults(String query) {
    final filteredAccounts = _mockAccounts.where((a) => (a['name'] as String).toLowerCase().contains(query) || (a['handle'] as String).toLowerCase().contains(query)).toList();
    final filteredTags = _mockTags.where((t) => (t['tag'] as String).toLowerCase().contains(query)).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (_activeTab == 0 || _activeTab == 1) ...[
          ...filteredAccounts.map((acc) => ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                leading: CircleAvatar(
                  backgroundColor: acc['color'] as Color,
                  child: Text((acc['name'] as String)[0], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                title: Text(acc['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${acc['handle']} · ${acc['followers']} followers', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreatorProfileScreen(
                        creatorName: acc['name'] as String,
                        avatarColor: acc['color'] as Color,
                      ),
                    ),
                  );
                },
              )),
        ],
        if (_activeTab == 0 || _activeTab == 2) ...[
          ...filteredTags.map((tag) => ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF1E242C), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.tag_rounded, color: Color(0xFFF5B942), size: 20),
                ),
                title: Text(tag['tag'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(tag['posts'] as String, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exploring ${tag['tag']} clips!')));
                },
              )),
        ],
      ],
    );
  }
}
