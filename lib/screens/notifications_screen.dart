import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilter = 0;

  final List<Map<String, dynamic>> _notifications = [
    {
      'name': 'Maya Chen',
      'action': 'liked your community photo',
      'time': '5m ago',
      'avatarColor': const Color(0xFFE5A87B),
      'isSuperThanks': false,
      'isFollow': false,
    },
    {
      'name': 'Rohan Mehta',
      'action': 'sent you ₹100 Super Thanks! 💰',
      'time': '20m ago',
      'avatarColor': const Color(0xFF93C5FD),
      'isSuperThanks': true,
      'isFollow': false,
    },
    {
      'name': 'Sneha Rao',
      'action': 'started following you',
      'time': '1h ago',
      'avatarColor': const Color(0xFFC5C6E9),
      'isSuperThanks': false,
      'isFollow': true,
    },
    {
      'name': 'Nikhil Art',
      'action': 'commented: "Incredible frame! 🔥"',
      'time': '3h ago',
      'avatarColor': const Color(0xFFFFD36B),
      'isSuperThanks': false,
      'isFollow': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Activity',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterChip('All', 0),
                  _buildFilterChip('Super Thanks', 1),
                  _buildFilterChip('Comments', 2),
                  _buildFilterChip('Followers', 3),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Expanded(
            child: ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 70),
              itemBuilder: (context, index) {
                final item = _notifications[index];
                final isSuper = item['isSuperThanks'] as bool;
                final isFollow = item['isFollow'] as bool;

                return Container(
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: item['avatarColor'] as Color,
                      child: Text(
                        (item['name'] as String)[0],
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    title: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${item['name']} ',
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          TextSpan(
                            text: item['action'] as String,
                            style: TextStyle(
                              color: isSuper ? const Color(0xFFD97706) : const Color(0xFF4B5563),
                              fontSize: 13.5,
                              fontWeight: isSuper ? FontWeight.bold : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item['time'] as String,
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11.5),
                      ),
                    ),
                    trailing: isFollow
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF111827),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {},
                            child: const Text('Follow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        : (isSuper
                            ? const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 22)
                            : const Icon(Icons.circle, size: 7, color: Color(0xFFF59E0B))),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF4B5563),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
