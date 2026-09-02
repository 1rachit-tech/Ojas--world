import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'creator_profile_screen.dart';
import '../widgets/world_search_delegate.dart';

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  int _selectedCategoryIndex = 0;

  final List<String> _categories = [
    'Explore',
    'Trending',
    'Cinematic',
    'Music',
    'Visual Arts',
    'Folk Beats',
    'Creators',
  ];

  // High performance light-palette items for zero-lag instant rendering
  final List<Map<String, dynamic>> _exploreMediaItems = [
    {'id': 'w1', 'title': 'City in Soft Light', 'creator': 'Maya Chen', 'views': '2.4M', 'category': 'Cinematic', 'color': const Color(0xFFD97706), 'isReel': true},
    {'id': 'w2', 'title': 'Modular Stems 808', 'creator': 'Rohan Mehta', 'views': '890K', 'category': 'Music', 'color': const Color(0xFF2563EB), 'isReel': false},
    {'id': 'w3', 'title': 'Vindhya Roots 🌿', 'creator': 'OJAS Studio', 'views': '1.5M', 'category': 'Folk Beats', 'color': const Color(0xFF059669), 'isReel': true},
    {'id': 'w4', 'title': 'Analog 35mm Frame', 'creator': 'Sneha Rao', 'views': '740K', 'category': 'Visual Arts', 'color': const Color(0xFFDB2777), 'isReel': false},
    {'id': 'w5', 'title': 'Digital Canvas 3D', 'creator': 'Nikhil Art', 'views': '3.1M', 'category': 'Visual Arts', 'color': const Color(0xFF7C3AED), 'isReel': true},
    {'id': 'w6', 'title': 'Street Beats Drop', 'creator': 'Vaibhav', 'views': '1.1M', 'category': 'Music', 'color': const Color(0xFF0284C7), 'isReel': false},
    {'id': 'w7', 'title': 'Morning Silence', 'creator': 'Aarav', 'views': '410K', 'category': 'Cinematic', 'color': const Color(0xFF4B5563), 'isReel': true},
    {'id': 'w8', 'title': 'Synthwave Horizon', 'creator': 'Kavya Audio', 'views': '1.8M', 'category': 'Music', 'color': const Color(0xFF9333EA), 'isReel': false},
    {'id': 'w9', 'title': 'Forest Geometry', 'creator': 'Maya Chen', 'views': '920K', 'category': 'Visual Arts', 'color': const Color(0xFF0D9488), 'isReel': true},
    {'id': 'w10', 'title': 'Studio Master Tape', 'creator': 'Rohan Mehta', 'views': '650K', 'category': 'Music', 'color': const Color(0xFF1E293B), 'isReel': false},
    {'id': 'w11', 'title': 'Portrait Studies', 'creator': 'Sneha Rao', 'views': '1.3M', 'category': 'Visual Arts', 'color': const Color(0xFFE11D48), 'isReel': true},
    {'id': 'w12', 'title': 'Architecture Lines', 'creator': 'Nikhil Art', 'views': '840K', 'category': 'Cinematic', 'color': const Color(0xFF475569), 'isReel': false},
  ];

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 1) {
      return _exploreMediaItems;
    }
    final selectedCat = _categories[_selectedCategoryIndex];
    final list = _exploreMediaItems.where((item) => item['category'] == selectedCat).toList();
    return list.isEmpty ? _exploreMediaItems : list;
  }

  void _openMediaDetail(BuildContext context, Map<String, dynamic> item) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _WorldMediaDetailModal(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredItems;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // 1. Sleek Modern Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    WorldSearchSheet.show(context);
                  },
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 0.8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Search creators, audio, tags...',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Icon(Icons.mic_none_rounded, color: Color(0xFF6B7280), size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2. Minimal Category Chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedCategoryIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCategoryIndex = index);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                _categories[index],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // 3. Clean Media Grid (120 FPS Native Flow)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = displayList[index % displayList.length];
                    final isReel = item['isReel'] as bool;

                    return GestureDetector(
                      onTap: () => _openMediaDetail(context, item),
                      child: Container(
                        decoration: BoxDecoration(
                          color: item['color'] as Color,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black54],
                                  stops: [0.6, 1.0],
                                ),
                              ),
                            ),
                            if (isReel)
                              const Positioned(
                                top: 6,
                                right: 6,
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            Positioned(
                              left: 6,
                              right: 6,
                              bottom: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    item['views'] as String,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: displayList.length >= 12 ? displayList.length : 18,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

class _WorldMediaDetailModal extends StatelessWidget {
  final Map<String, dynamic> item;

  const _WorldMediaDetailModal({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreatorProfileScreen(
                          creatorName: item['creator'] as String,
                          avatarColor: item['color'] as Color,
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: item['color'] as Color,
                    child: Text(
                      (item['creator'] as String)[0],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${item['creator']} · ${item['category']}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text('Watch in OJAS Feed', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
