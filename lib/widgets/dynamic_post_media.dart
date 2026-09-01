import 'package:flutter/material.dart';
import 'ojas_smart_video_player.dart';

class DynamicPostMedia extends StatelessWidget {
  final bool isVideo;
  final String mediaUrl;
  final double aspectRatio; // 1.0 (Square), 0.8 (4:5 Portrait), 1.77 (16:9), 0.56 (9:16)
  final bool isPortraitReel;
  final VoidCallback? onReelTap;

  const DynamicPostMedia({
    super.key,
    required this.isVideo,
    required this.mediaUrl,
    this.aspectRatio = 1.0,
    this.isPortraitReel = false,
    this.onReelTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isVideo) {
      return OjasSmartVideoPlayer(
        videoUrl: mediaUrl,
        aspectRatio: aspectRatio,
        isPortraitReel: isPortraitReel,
        onReelTap: onReelTap,
      );
    }

    // Dynamic Ratio Auto-fit Image (1:1, 4:5, 16:9)
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          color: const Color(0xFFF3F4F6),
          child: Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111827))),
              );
            },
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.image_not_supported_rounded, color: Color(0xFF9CA3AF), size: 36),
            ),
          ),
        ),
      ),
    );
  }
}
