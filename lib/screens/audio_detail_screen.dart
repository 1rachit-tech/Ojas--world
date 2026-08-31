import 'package:flutter/material.dart';
import 'create_screen.dart';
import '../widgets/share_bottom_sheet.dart';

class AudioDetailScreen extends StatefulWidget {
  final String audioTitle;
  final String creatorName;

  const AudioDetailScreen({
    super.key,
    required this.audioTitle,
    required this.creatorName,
  });

  @override
  State<AudioDetailScreen> createState() => _AudioDetailScreenState();
}

class _AudioDetailScreenState extends State<AudioDetailScreen> {
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07090B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {
              ShareBottomSheet.show(
                context,
                videoUrl: 'https://ojas.app/audio/${widget.audioTitle}',
                creatorName: widget.creatorName,
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Audio Header Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Spinning Vinyl Cover Art
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E242C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF5B942), width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded, color: Color(0xFFF5B942), size: 36),
                  ),
                ),
                const SizedBox(width: 16),

                // Title & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.audioTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Original sound by ${widget.creatorName}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '142.8K videos · Trending on OJAS',
                        style: TextStyle(color: Color(0xFFF5B942), fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bookmark Audio Action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _isSaved ? const Color(0xFFF5B942) : Colors.white24),
                  backgroundColor: _isSaved ? const Color(0xFFF5B942).withValues(alpha: 0.12) : const Color(0xFF161B22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  setState(() => _isSaved = !_isSaved);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_isSaved ? 'Audio saved to your bookmarks! 🎵' : 'Removed from bookmarks.')),
                  );
                },
                icon: Icon(_isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: const Color(0xFFF5B942), size: 18),
                label: Text(
                  _isSaved ? 'Saved to Audio Library' : 'Save Audio',
                  style: TextStyle(color: _isSaved ? const Color(0xFFF5B942) : Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),

          // Videos Grid made with this Audio
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 0.72,
              ),
              itemCount: 15,
              itemBuilder: (context, index) {
                return Container(
                  color: const Color(0xFF161B22),
                  child: Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      Center(
                        child: Icon(Icons.movie_creation_outlined, color: Colors.white.withValues(alpha: 0.15), size: 36),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 2),
                            Text('${(index + 1) * 24}K', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Use this Sound Bottom Button (Navigates to Camera)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF13171D),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5B942),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateScreen()),
                    );
                  },
                  icon: const Icon(Icons.movie_creation_rounded, size: 20),
                  label: const Text('Use this sound', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
