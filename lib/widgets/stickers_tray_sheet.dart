import 'package:flutter/material.dart';

class StickersTraySheet extends StatelessWidget {
  final Function(String sticker) onStickerSelected;

  const StickersTraySheet({super.key, required this.onStickerSelected});

  static void show(BuildContext context, {required Function(String sticker) onStickerSelected}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StickersTraySheet(onStickerSelected: onStickerSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactiveWidgets = ['📊 POLL', '❓ ASK ME', '📍 LOCATION', '🏷️ @MENTION', '⏳ COUNTDOWN', '🎵 MUSIC'];
    final trendingEmojis = ['🔥', '✨', '❤️', '🙌', '💯', '🎬', '🌟', '🎧', '⚡', '🌿', '💎', '🚀', '😍', '👏', '🏆', '🎯'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          const Text('Interactive Stickers & Emojis', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          const Text('Interactive Stickers', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: interactiveWidgets.map((w) {
              return ActionChip(
                backgroundColor: const Color(0xFF21262D),
                label: Text(w, style: const TextStyle(color: Color(0xFFF5B942), fontWeight: FontWeight.bold, fontSize: 12)),
                side: BorderSide.none,
                onPressed: () {
                  onStickerSelected(w);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          const Text('Popular Emojis', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: trendingEmojis.length,
              itemBuilder: (context, index) {
                final em = trendingEmojis[index];
                return GestureDetector(
                  onTap: () {
                    onStickerSelected(em);
                    Navigator.pop(context);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFF21262D), borderRadius: BorderRadius.circular(16)),
                    child: Text(em, style: const TextStyle(fontSize: 32)),
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
