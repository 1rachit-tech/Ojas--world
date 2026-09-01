import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilter = 0;

  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 1,
      'name': 'Maya Chen',
      'action': 'liked your community photo',
      'time': '5m ago',
      'avatarColor': const Color(0xFFE5A87B),
      'isSuperThanks': false,
      'isFollow': false,
      'isComment': false,
      'isRead': false,
    },
    {
      'id': 2,
      'name': 'Rohan Mehta',
      'action': 'sent you ₹100 Super Thanks! 💰',
      'time': '20m ago',
      'avatarColor': const Color(0xFF93C5FD),
      'isSuperThanks': true,
      'isFollow': false,
      'isComment': false,
      'isRead': false,
    },
    {
      'id': 3,
      'name': 'Sneha Rao',
      'action': 'started following you',
      'time': '1h ago',
      'avatarColor': const Color(0xFFC5C6E9),
      'isSuperThanks': false,
      'isFollow': true,
      'isFollowingLocal': false,
      'isComment': false,
      'isRead': true,
    },
    {
      'id': 4,
      'name': 'Nikhil Art',
      'action': 'commented: "Incredible frame! 🔥"',
      'time': '3h ago',
      'avatarColor': const Color(0xFFFFD36B),
      'isSuperThanks': false,
      'isFollow': false,
      'isComment': true,
      'isRead': true,
    },
  ];

  List<Map<String, dynamic>> get _filteredList {
    if (_selectedFilter == 1) {
      return _notifications.where((n) => n['isSuperThanks'] == true).toList();
    } else if (_selectedFilter == 2) {
      return _notifications.where((n) => n['isComment'] == true).toList();
    } else if (_selectedFilter == 3) {
      return _notifications.where((n) => n['isFollow'] == true).toList();
    }
    return _notifications;
  }

  void _markAllRead() {
    HapticFeedback.lightImpact();
    setState(() {
      for (var n in _notifications) {
        n['isRead'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All activities marked as read.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredList;

    return Scaffold(
      backgroundColor: Colors.white,
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
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all_rounded, color: Color(0xFF111827), size: 22),
            onPressed: _markAllRead,
          ),
        ],
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

          // Notifications List
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'No activity here yet',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      color: Color(0xFFF3F4F6),
                      indent: 72,
                    ),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final isSuper = item['isSuperThanks'] as bool;
                      final isFollow = item['isFollow'] as bool;
                      final isComment = item['isComment'] as bool? ?? false;
                      final isRead = item['isRead'] as bool? ?? true;
                      final isFollowing = item['isFollowingLocal'] as bool? ?? false;

                      return Dismissible(
                        key: Key('activity_${item['id']}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: const Color(0xFFEF4444),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                        ),
                        onDismissed: (_) {
                          setState(() {
                            _notifications.removeWhere((n) => n['id'] == item['id']);
                          });
                        },
                        child: Container(
                          color: isRead ? Colors.white : const Color(0xFFF9FAFB),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: item['avatarColor'] as Color,
                                  child: Text(
                                    (item['name'] as String)[0],
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _buildBadgeIcon(isSuper, isFollow, isComment),
                                ),
                              ],
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
                                      backgroundColor: isFollowing ? const Color(0xFFF3F4F6) : const Color(0xFF111827),
                                      foregroundColor: isFollowing ? const Color(0xFF111827) : Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        item['isFollowingLocal'] = !isFollowing;
                                      });
                                    },
                                    child: Text(
                                      isFollowing ? 'Following' : 'Follow back',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : (isSuper
                                    ? const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 24)
                                    : (!isRead
                                        ? const Icon(Icons.circle, size: 8, color: Color(0xFFF59E0B))
                                        : const SizedBox.shrink())),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeIcon(bool isSuper, bool isFollow, bool isComment) {
    if (isSuper) {
      return const CircleAvatar(
        radius: 6.5,
        backgroundColor: Color(0xFFF59E0B),
        child: Icon(Icons.stars_rounded, color: Colors.white, size: 8),
      );
    } else if (isFollow) {
      return const CircleAvatar(
        radius: 6.5,
        backgroundColor: Color(0xFF10B981),
        child: Icon(Icons.person_add_rounded, color: Colors.white, size: 8),
      );
    } else if (isComment) {
      return const CircleAvatar(
        radius: 6.5,
        backgroundColor: Color(0xFF3B82F6),
        child: Icon(Icons.mode_comment_rounded, color: Colors.white, size: 8),
      );
    }
    return const CircleAvatar(
      radius: 6.5,
      backgroundColor: Color(0xFFEF4444),
      child: Icon(Icons.favorite_rounded, color: Colors.white, size: 8),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilter = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
