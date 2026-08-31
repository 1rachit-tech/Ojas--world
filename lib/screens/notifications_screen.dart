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
      'action': 'liked your video',
      'time': '2m ago',
      'avatarColor': const Color(0xFFE5A87B),
      'isSuperThanks': false,
      'isFollow': false,
    },
    {
      'name': 'Arjun Vlogs',
      'action': 'sent you ₹100 Super Thanks! 💰',
      'time': '15m ago',
      'avatarColor': const Color(0xFFF5B942),
      'isSuperThanks': true,
      'isFollow': false,
    },
    {
      'name': 'Sneha_09',
      'action': 'started following you',
      'time': '1h ago',
      'avatarColor': const Color(0xFFC5C6E9),
      'isSuperThanks': false,
      'isFollow': true,
    },
    {
      'name': 'Rohan Mehta',
      'action': 'commented: "Incredible sound mix! 🔥"',
      'time': '3h ago',
      'avatarColor': const Color(0xFF93C5FD),
      'isSuperThanks': false,
      'isFollow': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Activity',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          SizedBox(
            height: 44,
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
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
              itemBuilder: (context, index) {
                final item = _notifications[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: item['avatarColor'] as Color,
                    child: Text(
                      (item['name'] as String)[0],
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${item['name']} ',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        TextSpan(
                          text: item['action'] as String,
                          style: TextStyle(
                            color: item['isSuperThanks'] as bool ? const Color(0xFFF5B942) : Colors.white70,
                            fontSize: 13.5,
                            fontWeight: item['isSuperThanks'] as bool ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  subtitle: Text(
                    item['time'] as String,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  trailing: item['isFollow'] as bool
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5B942),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {},
                          child: const Text('Follow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      : const Icon(Icons.circle, size: 8, color: Color(0xFFF5B942)),
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
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = index),
        selectedColor: const Color(0xFFF5B942),
        backgroundColor: const Color(0xFF161B22),
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
      ),
    );
  }
}
