import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SoundDetailScreen extends StatelessWidget {
  final String soundTitle;
  final String creatorName;

  const SoundDetailScreen({
    super.key,
    required this.soundTitle,
    required this.creatorName,
  });

  static void open(BuildContext context, {required String soundTitle, required String creatorName}) {
    HapticFeedback.selectionClick();
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sound',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF111827), size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sound link copied! 🎵'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Sound Minimalist Header Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded, color: Color(0xFF111827), size: 34),
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
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@$creatorName',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '12.4K videos',
                          style: TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Use Sound Modern Minimal Black Button
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.videocam_rounded, size: 19),
                label: const Text(
                  'Use this sound',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    letterSpacing: 0.2,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Selected "$soundTitle" for Studio 🎙️'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF3F4F6), height: 1, thickness: 1),

          // 3. Grid of Videos using this Sound
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              physics: const BouncingScrollPhysics(),
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
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black.withValues(alpha: 0.15),
                          size: 32,
                        ),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow_outlined, color: Color(0xFF4B5563), size: 13),
                            const SizedBox(width: 2),
                            Text(
                              '${(index + 1) * 3}.2K',
                              style: const TextStyle(
                                color: Color(0xFF374151),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
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
