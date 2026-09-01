import 'package:flutter/material.dart';

class SoundDetailScreen extends StatelessWidget {
  final String soundTitle;
  final String creatorName;

  const SoundDetailScreen({
    super.key,
    required this.soundTitle,
    required this.creatorName,
  });

  static void open(BuildContext context, {required String soundTitle, required String creatorName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SoundDetailScreen(
          soundTitle: soundTitle,
          creatorName: creatorName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sound',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF111827)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sound link copied! 🎵'), behavior: SnackBarBehavior.floating),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Sound Header Card
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        soundTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        creatorName,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '12.4K videos created',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Use Sound Minimalist Black Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.videocam_rounded, size: 20),
                label: const Text(
                  'Use this sound',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Selected "$soundTitle" for Studio recording 🎙️'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF111827),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF3F4F6), height: 1),

          // 3. Grid of Videos using this Sound
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
                childAspectRatio: 9 / 16,
              ),
              itemCount: 15,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Icon(
                          Icons.play_circle_outline_rounded,
                          color: Colors.black.withValues(alpha: 0.2),
                          size: 32,
                        ),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.black54, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              '${(index + 1) * 3}.2K',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
}
