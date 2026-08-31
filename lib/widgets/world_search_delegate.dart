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
  int _selectedFilterTab = 0; // 0: Top, 1: Accounts, 2: Audio, 3: Tags, 4: Places

  final List<String> _tabs = ['Top', 'Creators', 'Audio', 'Tags', 'Places'];

  final List<Map<String, dynamic>> _mockResults = [
    {'type': 'creator', 'name': 'Maya Chen', 'handle': '@mayamakes', 'followers': '1.2M', 'color': const Color(0xFFE5A87B)},
    {'type': 'creator', 'name': 'Rohan Mehta', 'handle': '@rohanbuilds', 'followers': '850K', 'color': const Color(0xFF93C5FD)},
    {'type': 'audio', 'name': 'Vindhya Beats - Folk Fusion', 'author': 'OJAS Originals', 'uses': '240K videos', 'color': const Color(0xFFF5B942)},
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
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),

          // Search Header with Voice Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFFF5B942), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Search creators, audio, tags...',
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _searchController.clear()),
                            child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listening... Speak now 🎙️')));
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.mic_rounded, color: Color(0xFFF5B942), size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Filter Sub-Tabs
          SizedBox(
            height: 36,
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
                    selectedColor: const Color(0xFFF5B942),
                    backgroundColor: const Color(0xFF161B22),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
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
          const Divider(color: Colors.white10, height: 1),

          // Search Results
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No matching results found in World', style: TextStyle(color: Colors.white38)))
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
                            child: Text((item['name'] as String)[0], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(item['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('${item['handle']} · ${item['followers']} followers', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
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
                      } else if (type == 'audio') {
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: item['color'] as Color, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.music_note_rounded, color: Colors.black87),
                          ),
                          title: Text(item['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('${item['author']} · ${item['uses']}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          trailing: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFF5B942), size: 28),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playing ${item['name']}...')));
                          },
                        );
                      } else {
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF161B22),
                            child: Icon(type == 'tag' ? Icons.tag_rounded : Icons.place_rounded, color: const Color(0xFFF5B942), size: 18),
                          ),
                          title: Text(item['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(item['count'] as String, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          onTap: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Filtering posts for ${item['name']}')));
                          },
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
