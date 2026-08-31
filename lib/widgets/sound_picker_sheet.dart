import 'package:flutter/material.dart';

class AudioTrack {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String reelsCount;
  final Color coverColor;
  bool isSaved;

  AudioTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.reelsCount,
    required this.coverColor,
    this.isSaved = false,
  });
}

class SoundPickerSheet extends StatefulWidget {
  final String currentSound;
  final Function(String selectedSound) onSoundSelected;

  const SoundPickerSheet({
    super.key,
    required this.currentSound,
    required this.onSoundSelected,
  });

  static void show(
    BuildContext context, {
    required String currentSound,
    required Function(String selectedSound) onSoundSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SoundPickerSheet(
        currentSound: currentSound,
        onSoundSelected: onSoundSelected,
      ),
    );
  }

  @override
  State<SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<SoundPickerSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0: For You, 1: Trending, 2: Saved
  String? _currentlyPlayingId;

  final List<AudioTrack> _tracks = [
    AudioTrack(
      id: '1',
      title: 'Vindhya Beats - Folk Fusion',
      artist: 'OJAS Originals',
      duration: '0:30',
      reelsCount: '245K',
      coverColor: const Color(0xFFF5B942),
      isSaved: true,
    ),
    AudioTrack(
      id: '2',
      title: 'Midnight Synthwave Drive',
      artist: 'Kavya Audio Lab',
      duration: '0:15',
      reelsCount: '89K',
      coverColor: const Color(0xFF8B5CF6),
    ),
    AudioTrack(
      id: '3',
      title: 'Slowed Lofi Aesthetic 🌿',
      artist: 'Aarav Beats',
      duration: '0:45',
      reelsCount: '512K',
      coverColor: const Color(0xFF10B981),
      isSaved: true,
    ),
    AudioTrack(
      id: '4',
      title: 'High Bass Cinematic Drop 🔥',
      artist: 'Rohan Mehta',
      duration: '0:30',
      reelsCount: '1.2M',
      coverColor: const Color(0xFFEF4444),
    ),
    AudioTrack(
      id: '5',
      title: 'Sacred Flute Meditation',
      artist: 'Sanskrit Echoes',
      duration: '1:00',
      reelsCount: '67K',
      coverColor: const Color(0xFF3B82F6),
    ),
  ];

  List<AudioTrack> _filteredTracks = [];

  @override
  void initState() {
    super.initState();
    _filteredTracks = _tracks;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredTracks = _tracks;
      } else {
        _filteredTracks = _tracks.where((t) {
          return t.title.toLowerCase().contains(query) ||
              t.artist.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _togglePlayPreview(String trackId) {
    setState(() {
      if (_currentlyPlayingId == trackId) {
        _currentlyPlayingId = null; // Pause
      } else {
        _currentlyPlayingId = trackId; // Play
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var displayList = _filteredTracks;
    if (_selectedTab == 2) {
      displayList = displayList.where((t) => t.isSaved).toList();
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF13171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black87, blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Drag handle
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sounds & Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    widget.onSoundSelected('Original Sound');
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Original Sound',
                      style: TextStyle(
                        color: Color(0xFFF5B942),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      color: Colors.white54, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search songs, artists, or genres...',
                        hintStyle:
                            TextStyle(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white54, size: 18),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Categories Tabs (For You, Trending, Saved)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTabButton('Discover', 0),
                const SizedBox(width: 8),
                _buildTabButton('Trending 🔥', 1),
                const SizedBox(width: 8),
                _buildTabButton('Saved 🔖', 2),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),

          // Track List
          Expanded(
            child: displayList.isEmpty
                ? const Center(
                    child: Text(
                      'No tracks found',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final track = displayList[index];
                      final isPlaying = _currentlyPlayingId == track.id;
                      final isSelected = widget.currentSound == track.title;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF5B942).withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF5B942)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Cover with Play/Pause Button
                            GestureDetector(
                              onTap: () => _togglePlayPreview(track.id),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: track.coverColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.music_note_rounded,
                                      color: Colors.black87,
                                      size: 24,
                                    ),
                                  ),
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Track Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${track.artist} · ${track.duration}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.movie_creation_outlined,
                                        size: 11,
                                        color: Color(0xFFF5B942),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${track.reelsCount} videos',
                                        style: const TextStyle(
                                          color: Color(0xFFF5B942),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Bookmark / Save Action
                            IconButton(
                              icon: Icon(
                                track.isSaved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: track.isSaved
                                    ? const Color(0xFFF5B942)
                                    : Colors.white38,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  track.isSaved = !track.isSaved;
                                });
                              },
                            ),

                            // Select / Use Button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF5B942),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                widget.onSoundSelected(track.title);
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Use',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF5B942)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
