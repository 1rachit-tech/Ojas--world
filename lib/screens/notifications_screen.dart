import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🚀 Dummy Data for high-speed UI rendering (Zero Server Cost)
    final List<Map<String, dynamic>> notifications = [
      {
        'type': 'super_thanks',
        'name': 'Rohan Mehta',
        'message': 'sent a Super Thanks on your video!',
        'time': '2m ago',
        'icon': Icons.stars_rounded,
        'color': const Color(0xFFF59E0B), // Golden
        'avatarColor': const Color(0xFF2563EB),
      },
      {
        'type': 'like',
        'name': 'Sneha Rao',
        'message': 'liked your latest reel.',
        'time': '15m ago',
        'icon': Icons.favorite_rounded,
        'color': const Color(0xFFEF4444), // Red
        'avatarColor': const Color(0xFFDB2777),
      },
      {
        'type': 'comment',
        'name': 'Maya Chen',
        'message': 'commented: "This lighting is absolutely magical! ✨"',
        'time': '1h ago',
        'icon': Icons.mode_comment_rounded,
        'color': const Color(0xFF3B82F6), // Blue
        'avatarColor': const Color(0xFFD97706),
      },
      {
        'type': 'follow',
        'name': 'Aarav',
        'message': 'started following you.',
        'time': '3h ago',
        'icon': Icons.person_add_rounded,
        'color': const Color(0xFF10B981), // Green
        'avatarColor': const Color(0xFF4B5563),
      },
      {
        'type': 'mention',
        'name': 'OJAS Studio',
        'message': 'mentioned you in a post.',
        'time': '5h ago',
        'icon': Icons.alternate_email_rounded,
        'color': const Color(0xFF8B5CF6), // Purple
        'avatarColor': const Color(0xFF059669),
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white, // 🚀 100% Minimalist Pure White
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Color(0xFF6B7280), size: 22),
            onPressed: () {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All caught up! ✅'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Text(
                'No new notifications',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
              ),
            )
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(
                color: Color(0xFFF3F4F6),
                height: 1,
                indent: 72,
              ),
              itemBuilder: (context, index) {
                final item = notifications[index];
                final isSuperThanks = item['type'] == 'super_thanks';

                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                  },
                  highlightColor: const Color(0xFFF9FAFB),
                  splashColor: const Color(0xFFF3F4F6),
                  child: Container(
                    color: isSuperThanks ? const Color(0xFFFEF3C7).withValues(alpha: 0.3) : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar + Small Icon Indicator
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: item['avatarColor'] as Color,
                              child: Text(
                                (item['name'] as String)[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: item['color'] as Color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        
                        // Notification Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF374151),
                                    fontFamily: 'sans-serif',
                                    height: 1.4,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${item['name']} ',
                                      style: const TextStyle(
                                        color: Color(0xFF111827),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: item['message'] as String,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['time'] as String,
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Action Button (Follow Back or Thumbnail)
                        if (item['type'] == 'follow')
                          Container(
                            margin: const EdgeInsets.only(left: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Follow',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else if (item['type'] != 'mention')
                          Container(
                            margin: const EdgeInsets.only(left: 10),
                            width: 36,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF9CA3AF), size: 16),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
