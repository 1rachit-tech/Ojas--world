import 'package:flutter/material.dart';
import 'creator_profile_screen.dart';
import '../widgets/world_search_delegate.dart';
import '../widgets/world_media_detail_sheet.dart';

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
    {'id': 'w3', 'title': 'Vindhya Roots 🌿', 'creator': 'OJAS Studio', 'views': '1.5M', 'category': 'Culture', 'color': const Color(0xFF059669), 'isReel': true},
    {'id': 'w4', 'title': 'Analog 35mm Frame', 'creator': 'Sneha Rao', 'views': '740K', 'category': 'Photography', 'color': const Color(0xFFDB2777), 'isReel': false},
    {'id': 'w5', 'title': 'Digital Canvas 3D', 'creator': 'Nikhil Art', 'views': '3.1M', 'category': 'Art', 'color': const Color(0xFF7C3AED), 'isReel': true},
    {'id': 'w6', 'title': 'Street Beats Drop', 'creator': 'Vaibhav', 'views': '1.1M', 'category': 'Music', 'color': const Color(0xFF0284C7), 'isReel': false},
    {'id': 'w7', 'title': 'Morning Silence', 'creator': 'Aarav', 'views': '410K', 'category': 'Cinematic', 'color': const Color(0xFF4B5563), 'isReel': true},
    {'id': 'w8', 'title': 'Synthwave Horizon', 'creator': 'Kavya Audio', 'views': '1.8M', 'category': 'Music', 'color': const Color(0xFF9333EA), 'isReel': false},
    {'id': 'w9', 'title': 'Forest Geometry', 'creator': 'Maya Chen', 'views': '920K', 'category': 'Photography', 'color': const Color(0xFF0D9488), 'isReel': true},
    {'id': 'w10', 'title': 'Studio Master Tape', 'creator': 'Rohan Mehta', 'views': '650K', 'category': 'Music', 'color': const Color(0xFF1E293B), 'isReel': false},
    {'id': 'w11', 'title': 'Portrait Studies', 'creator': 'Sneha Rao', 'views': '1.3M', 'category': 'Art', 'color': const Color(0xFFE11D48), 'isReel': true},
    {'id': 'w12', 'title': 'Architecture Lines', 'creator': 'Nikhil Art', 'views': '840K', 'category': 'Cinematic', 'color': const Color(0xFF475569), 'isReel': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // 1. Sleek Modern Search Bar (Single, Crisp, No Clutter)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: GestureDetector(
                  onTap: () => WorldSearchSheet.show(context),
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

            // 2. Minimal Category Chips (Neutral & Smooth)
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
                          onTap: () => setState(() => _selectedCategoryIndex = index),
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

            // 3. Instagram / TikTok 3-Column Clean Media Grid (120 FPS Optimized)
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
                    final item = _exploreMediaItems[index % _exploreMediaItems.length];
                    final isReel = item['isReel'] as bool;

                    return GestureDetector(
                      onTap: () => WorldMediaDetailSheet.show(context, item),
                      child: Container(
                        decoration: BoxDecoration(
                          color: item['color'] as Color,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Subtle Gradient for text readability
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

                            // Reel / Media Type Indicator Icon
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

                            // Bottom Caption & Stats
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
                  childCount: 24,
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
