import 'package:flutter/material.dart';

class HashtagFeedScreen extends StatelessWidget {
  final String hashtag;

  const HashtagFeedScreen({
    super.key,
    required this.hashtag,
  });

  static void open(BuildContext context, {required String hashtag}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HashtagFeedScreen(hashtag: hashtag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanTag = hashtag.startsWith('#') ? hashtag : '#$hashtag';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          cleanTag,
          style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF111827)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied link for $cleanTag! 🔗'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Hashtag Header Summary
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Center(
                    child: Text(
                      '#',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cleanTag,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '14.8M Views · 42.6K Posts',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDEF7EC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Trending in India',
                          style: TextStyle(
                            color: Color(0xFF03543F),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Join Challenge Action Button
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
                label: Text(
                  'Join $cleanTag',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening Studio for $cleanTag 🎬'),
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

          // 3. 3-Column Video Posts Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
                childAspectRatio: 9 / 16,
              ),
              itemCount: 18,
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
                          color: Colors.black.withValues(alpha: 0.15),
                          size: 30,
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
                              '${(index + 2) * 5}.4K',
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
