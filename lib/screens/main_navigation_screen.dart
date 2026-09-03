import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ojs_feed_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();

    // बीच वाला '+' बटन (Studio Upload)
    if (index == 2) {
      _openStudioPicker();
      return;
    }

    setState(() => _currentIndex = index);
  }

  void _openStudioPicker() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OJAS Studio: Select video from device 🎬'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFeed = _currentIndex == 0;

    return Scaffold(
      backgroundColor: isFeed ? Colors.black : Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const OjsFeedScreen(),
          _buildPlaceholderScreen('Discover Trending', Icons.explore_outlined),
          const SizedBox.shrink(), // Studio button placeholder
          _buildPlaceholderScreen('Activity & Notifications', Icons.notifications_none_rounded),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 60,
        decoration: BoxDecoration(
          color: isFeed ? Colors.black : Colors.white,
          border: Border(
            top: BorderSide(
              color: isFeed ? Colors.white10 : const Color(0xFFF3F4F6),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home', isFeed),
            _buildNavItem(1, Icons.explore_rounded, Icons.explore_outlined, 'Discover', isFeed),
            _buildCenterStudioButton(isFeed),
            _buildNavItem(3, Icons.notifications_rounded, Icons.notifications_none_rounded, 'Inbox', isFeed),
            _buildNavItem(4, Icons.person_rounded, Icons.person_outline_rounded, 'Profile', isFeed),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label, bool isDarkFeed) {
    final bool isSelected = _currentIndex == index;
    final Color activeColor = isDarkFeed ? Colors.white : const Color(0xFF111827);
    final Color inactiveColor = isDarkFeed ? Colors.white38 : const Color(0xFF9CA3AF);

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : inactiveIcon,
            color: isSelected ? activeColor : inactiveColor,
            size: 24,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? activeColor : inactiveColor,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterStudioButton(bool isDarkFeed) {
    return GestureDetector(
      onTap: () => _onTabTapped(2),
      child: Container(
        width: 44,
        height: 30,
        decoration: BoxDecoration(
          color: isDarkFeed ? Colors.white : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.add_rounded,
          color: isDarkFeed ? Colors.black : Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildPlaceholderScreen(String title, IconData icon) {
    return Scaffold(
      backgroundColor: Colors.white, // 🚀 Minimalist Pure White
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: const Color(0xFFD1D5DB)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
