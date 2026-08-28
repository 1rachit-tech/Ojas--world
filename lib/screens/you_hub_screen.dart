import 'package:flutter/material.dart';

import 'messages_screen.dart';
import 'profile_screen.dart';

class YouHubScreen extends StatefulWidget {
  const YouHubScreen({super.key, this.onLoggedOut});

  final VoidCallback? onLoggedOut;

  @override
  State<YouHubScreen> createState() => _YouHubScreenState();
}

class _YouHubScreenState extends State<YouHubScreen> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(page: _page, onSelected: _selectPage),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _page = page),
            children: [
              const MessagesScreen(),
              ProfileScreen(onLoggedOut: widget.onLoggedOut),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.page, required this.onSelected});
  final int page;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 60,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final active = index == page;
        return GestureDetector(
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 116,
            height: 60,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? const Color(0xFFF5B942) : Colors.transparent,
                  width: 2,
                ),
              ),
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color: Color(0x24F5B942),
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                index == 0 ? 'Messages' : 'Profile',
                style: TextStyle(
                  color: active
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF),
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );
}
