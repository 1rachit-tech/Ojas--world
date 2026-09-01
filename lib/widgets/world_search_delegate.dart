import 'package:flutter/material.dart';
import '../screens/creator_profile_screen.dart';

class WorldSearchSheet extends StatefulWidget {
  final String initialQuery;
  const WorldSearchSheet({super.key, this.initialQuery = ''});

  static void show(BuildContext context, {String initialQuery = ''}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WorldSearchSheet(initialQuery: initialQuery),
    );
  }

  @override
  State<WorldSearchSheet> createState() => _WorldSearchSheetState();
}

class _WorldSearchSheetState extends State<WorldSearchSheet> {
  late TextEditingController _searchController;
  int _selectedFilterTab = 0;

  final List<String> _tabs = ['Top', 'Creators', 'Audio', 'Tags', 'Places'];

  final List<Map<String, dynamic>> _mockResults = [
    {'type': 'creator', 'name': 'Maya Chen', 'handle': '@mayamakes', 'followers': '1.2M', 'color': const Color(0xFFE5A87B)},
    {'type': 'creator', 'name': 'Rohan Mehta', 'handle': '@rohanbuilds', 'followers': '850K', 'color': const Color(0xFF93C5FD)},
    {'type': 'audio', 'name': 'Vindhya Beats - Folk Fusion', 'author': 'OJAS Originals', 'uses': '240K videos', 'color': const Color(0xFF111827)},
    {'type': 'tag', 'name': '#OJASCreator', 'count': '4.5M posts', 'color': const Color(0xFF10B981)},
    {'type': 'place', 'name': 'Satna, Madhya Pradesh', 'count': '128K posts', 'color': const Color(0xFFEC4899)},
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase().trim();
    final filtered = _mockResults.where((item) {
      final name = (item['name'] as String).toLowerCase();
      final handle = (item['handle'] as String? ?? '').toLowerCase();
      return query.isEmpty || name.contains(query) || handle.contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),

          // Search Bar & Cancel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: const TextStyle(color: Color(0xFF111827), fontSize: 14),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Search creators, audio, tags...',
                              hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _searchController.clear()),
                            child: const Icon(Icons.close_rounded, color: Color(0xFF6B7280), size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Sub Filter Chips
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedFilterTab == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_tabs[index]),
                    selected: isSelected,
                    selectedColor: const Color(0xFF111827),
                    backgroundColor: const Color(0xFFF3F4F6),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF4B5563),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide.none),
                    onSelected: (_) => setState(() => _selectedFilterTab = index),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: Color(0xFFF3F4F6), height: 1),

          // Search Results List
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No results found', style: TextStyle(color: Color(0xFF9CA3AF))))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final type = item['type'] as String;

                      if (type == 'creator') {
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: item['color'] as Color,
                            child: Text((item['name'] as String)[0], style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(item['name'] as String, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('${item['handle']} · ${item['followers']} followers', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreatorProfileScreen(
                                  creatorName: item['name'] as String,
                                  avatarColor: item['color'] as Color,
                                ),
                              ),
                            );
                          },
                        );
                      } else {
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFF3F4F6),
                            child: Icon(type == 'tag' ? Icons.tag_rounded : (type == 'audio' ? Icons.music_note_rounded : Icons.place_rounded), color: const Color(0xFF111827), size: 18),
                          ),
                          title: Text(item['name'] as String, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(item['uses'] as String? ?? item['count'] as String? ?? '', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                          onTap: () => Navigator.pop(context),
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
