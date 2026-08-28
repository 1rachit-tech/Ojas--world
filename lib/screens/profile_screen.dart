import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onLoggedOut});

  final VoidCallback? onLoggedOut;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?.displayName ?? 'Akash Verma';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
        final Widget authAction = user != null
            ? Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await AuthService.instance.signOut();
                    onLoggedOut?.call();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log out'),
                ),
              )
            : Center(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => const LoginScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Log in to personalize your profile'),
                ),
              );
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF5B942), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33F5B942), blurRadius: 16),
                  ],
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xFFF5B942),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '@akashcreates',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB08220),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Visual storyteller finding wonder in the everyday.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 25),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Metric(value: '248', label: 'Following'),
                _Metric(value: '12.4K', label: 'Followers'),
                _Metric(value: '86.2K', label: 'Total likes'),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Profile'),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.insights_outlined, size: 18),
                  label: const Text('Creator Studio'),
                ),
                IconButton(
                  onPressed: () {},
                  tooltip: 'Share profile',
                  icon: const Icon(Icons.ios_share_rounded),
                ),
              ],
            ),
            const SizedBox(height: 25),
            const _ContentGrid(),
            const SizedBox(height: 25),
            authAction,
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
      ),
    ],
  );
}

class _ContentGrid extends StatefulWidget {
  const _ContentGrid();
  @override
  State<_ContentGrid> createState() => _ContentGridState();
}

class _ContentGridState extends State<_ContentGrid> {
  int _selected = 0;
  static const _tabs = ['Videos', 'Saved', 'Collections', 'Liked'];
  static const _colors = [
    Color(0xFFB46A42),
    Color(0xFF4A6C72),
    Color(0xFFB8A46A),
    Color(0xFF7D7188),
    Color(0xFF5C8068),
    Color(0xFF9A6472),
  ];
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            _tabs.length,
            (index) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_tabs[index]),
                selected: _selected == index,
                onSelected: (_) => setState(() => _selected = index),
                selectedColor: const Color(0xFFF5B942),
                backgroundColor: const Color(0xFFF4F5F7),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _colors.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
          childAspectRatio: .78,
        ),
        itemBuilder: (_, index) => DecoratedBox(
          decoration: BoxDecoration(
            color: _colors[index],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              _selected == 3
                  ? Icons.favorite_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white.withValues(alpha: .85),
              size: 28,
            ),
          ),
        ),
      ),
    ],
  );
}
