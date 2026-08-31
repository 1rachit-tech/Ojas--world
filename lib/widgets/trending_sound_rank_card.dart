import 'package:flutter/material.dart';

class TrendingSoundRankCard extends StatelessWidget {
  final int rank;
  final String title;
  final String artist;
  final String usesCount;
  final Color coverColor;
  final VoidCallback onPlay;
  final VoidCallback onUseSound;

  const TrendingSoundRankCard({
    super.key,
    required this.rank,
    required this.title,
    required this.artist,
    required this.usesCount,
    required this.coverColor,
    required this.onPlay,
    required this.onUseSound,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13171D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Rank Badge
          Text(
            '#$rank',
            style: TextStyle(
              color: rank <= 3 ? const Color(0xFFF5B942) : Colors.white38,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),

          // Disc Cover
          GestureDetector(
            onTap: onPlay,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: coverColor, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.music_note_rounded, color: Colors.black87, size: 22),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Track Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 2),
                Text(usesCount, style: const TextStyle(color: Color(0xFFF5B942), fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // Use Sound Button
          IconButton(
            icon: const Icon(Icons.movie_creation_outlined, color: Color(0xFFF5B942), size: 20),
            tooltip: 'Use Sound',
            onPressed: onUseSound,
          ),
        ],
      ),
    );
  }
}
