import 'package:flutter/material.dart';
import '../screens/creator_profile_screen.dart';
import '../widgets/share_bottom_sheet.dart';

class WorldMediaDetailSheet extends StatelessWidget {
  final Map<String, dynamic> item;

  const WorldMediaDetailSheet({super.key, required this.item});

  static void show(BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => WorldMediaDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Showcase Box
          Container(
            color: item['color'] as Color,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_fill_rounded, size: 70, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(item['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          // Close Button
          Positioned(
            top: 48,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Bottom Details & Actions
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF13171D).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatorProfileScreen(
                            creatorName: item['creator'] as String,
                            avatarColor: item['color'] as Color,
                          ),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: item['color'] as Color,
                      child: Text((item['creator'] as String)[0], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item['creator'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${item['views']} views · ${item['category']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    onPressed: () {
                      ShareBottomSheet.show(context, videoUrl: 'https://ojas.app/world/${item['id']}', creatorName: item['creator'] as String);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
