import 'package:flutter/material.dart';
import 'creator_profile_screen.dart';
import '../widgets/world_search_delegate.dart';
import '../widgets/world_radar_hub_sheet.dart';
import '../widgets/trending_sound_rank_card.dart';
import '../widgets/world_media_detail_sheet.dart';

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  String _currentRegion = 'Global (All World)';
  int _selectedCategoryIndex = 0;

  final List<String> _categories = [
    '✨ All World',
    '🔥 Trending',
    '🎬 Cinematic',
    '🎵 Music Stems',
    '🎨 Digital Art',
    '🌿 Vindhya Roots',
    '💡 Creator Hub',
    '🎭 Comedy'
  ];

  // Live Creators Spotlight
  final List<Map<String, dynamic>> _spotlightCreators = [
    {'name': 'Maya Chen', 'handle': '@mayamakes', 'followers': '1.2M', 'color': const Color(0xFFE5A87B), 'isLive': true},
    {'name': 'Rohan Mehta', 'handle': '@rohanbuilds', 'followers': '850K', 'color': const Color(0xFF93C5FD), 'isLive': false},
    {'name': 'Sneha Rao', 'handle': '@sneha_09', 'followers': '420K', 'color': const Color(0xFFC5C6E9), 'isLive': true},
    {'name': 'Nikhil Art', 'handle': '@nikhil_art', 'followers': '610K', 'color': const Color(0xFFFFD36B), 'isLive': false},
    {'name': 'Vaibhav', 'handle': '@vaibhav_v', 'followers': '310K', 'color': const Color(0xFFA7F3D0), 'isLive': false},
  ];

  // Trending Sound Charts
  final List<Map<String, dynamic>> _topSounds = [
    {'rank': 1, 'title': 'Vindhya Beats - Folk Fusion', 'artist': 'OJAS Originals', 'uses': '245K reels', 'color': const Color(0xFFF5B942)},
    {'rank': 2, 'title': 'Midnight Synthwave Drive', 'artist': 'Kavya Audio', 'uses': '180K reels', 'color': const Color(0xFF8B5CF6)},
    {'rank': 3, 'title': 'Slowed Lofi Aesthetic 🌿', 'artist': 'Aarav Beats', 'uses': '140K reels', 'color': const Color(0xFF10B981)},
    {'rank': 4, 'title': 'High Bass Drop Cinematic', 'artist': 'Rohan Mehta', 'uses': '95K reels', 'color': const Color(0xFFEF4444)},
  ];

  // Dynamic Media Grid (Mixed 1:1, 16:9, 9:16)
  final List<Map<String, dynamic>> _worldMediaItems = [
    {'id': 'w1', 'title': 'City in Soft Light', 'creator': 'Maya Chen', 'views': '2.4M', 'category': 'Cinematic', 'color': const Color(0xFFB45309), 'isTall': true},
    {'id': 'w2', 'title': 'Modular Synth Stems', 'creator': 'Rohan Mehta', 'views': '890K', 'category': 'Music', 'color': const Color(0xFF1E3A8A), 'isTall': false},
    {'id': 'w3', 'title': 'Bagheli Folk Roots 🌿', 'creator': 'OJAS Studio', 'views': '1.5M', 'category': 'Vindhya', 'color': const Color(0xFF047857), 'isTall': false},
    {'id': 'w4', 'title': '3D Neon Matrix', 'creator': 'Nikhil Art', 'views': '3.1M', 'category': 'Art', 'color': const Color(0xFF6D28D9), 'isTall': true},
    {'id': 'w5', 'title': 'Quiet Moments 35mm', 'creator': 'Sneha Rao', 'views': '740K', 'category': 'Cinematic', 'color': const Color(0xFFBE123C), 'isTall': false},
    {'id': 'w6', 'title': 'Street Beats Drop', 'creator': 'Vaibhav', 'views': '1.1M', 'category': 'Music', 'color': const Color(0xFF0369A1), 'isTall': true},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07090B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFDF79), Color(0xFFF5B942), Color(0xFFE59819)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'WORLD',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2.2, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            // World Radar Filter Button
            GestureDetector(
              onTap: () {
                WorldRadarHubSheet.show(
                  context,
                  activeRegion: _currentRegion,
                  onRegionChanged: (reg) => setState(() => _currentRegion = reg),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF5B942).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.radar_rounded, color: Color(0xFFF5B942), size: 14),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        _currentRegion,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Live Search & Tags',
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 26),
            onPressed: () => WorldSearchSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Search Bar Trigger
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: GestureDetector(
                onTap: () => WorldSearchSheet.show(context),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13171D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_rounded, color: Color(0xFFF5B942), size: 20),
                      SizedBox(width: 10),
                      Text('Discover creators, viral audio, #tags...', style: TextStyle(color: Colors.white38, fontSize: 13.5)),
                      Spacer(),
                      Icon(Icons.mic_none_rounded, color: Colors.white38, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Category Channel Chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedCategoryIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategoryIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF5B942) : const Color(0xFF13171D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? const Color(0xFFF5B942) : Colors.white10),
                      ),
                      child: Text(
                        _categories[index],
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 3. Creator Spotlight Section
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Creator Spotlight', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('See All', style: TextStyle(color: Color(0xFFF5B942), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _spotlightCreators.length,
                    itemBuilder: (context, index) {
                      final c = _spotlightCreators[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreatorProfileScreen(
                                creatorName: c['name'] as String,
                                avatarColor: c['color'] as Color,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 86,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: c['color'] as Color,
                                    child: Text((c['name'] as String)[0], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                                  ),
                                  if (c['isLive'] as bool)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(c['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(c['followers'] as String, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: Divider(color: Colors.white10, height: 20)),

          // 4. Trending Audio Rank Chart
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up_rounded, color: Color(0xFFF5B942), size: 18),
                      SizedBox(width: 6),
                      Text('Trending World Sound Chart', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 74,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _topSounds.length,
                    itemBuilder: (context, index) {
                      final snd = _topSounds[index];
                      return TrendingSoundRankCard(
                        rank: snd['rank'] as int,
                        title: snd['title'] as String,
                        artist: snd['artist'] as String,
                        usesCount: snd['uses'] as String,
                        coverColor: snd['color'] as Color,
                        onPlay: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playing ${snd['title']} 🎵'))),
                        onUseSound: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sound loaded into Studio! 🎬'))),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 5. Staggered Media Discovery Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _worldMediaItems[index % _worldMediaItems.length];
                  return GestureDetector(
                    onTap: () => WorldMediaDetailSheet.show(context, item),
                    child: Container(
                      decoration: BoxDecoration(
                        color: item['color'] as Color,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Gradient
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                                stops: const [0.4, 1.0],
                              ),
                            ),
                          ),
                          // Center Play Icon
                          const Center(child: Icon(Icons.play_circle_outline_rounded, size: 40, color: Colors.white70)),
                          // Bottom Info
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(item['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item['creator'] as String, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text(item['views'] as String, style: const TextStyle(color: Color(0xFFF5B942), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: 12,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }
}
