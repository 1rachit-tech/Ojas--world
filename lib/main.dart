import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'services/auth_guard.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp();
    }
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Firebase initialization',
        context: ErrorSummary(
          'Firebase could not initialize in this environment. Continuing without Firebase for web preview.',
        ),
      ),
    );
  }

  runApp(const OjasApp());
}

class OjasApp extends StatelessWidget {
  const OjasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OJAS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080D18),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5B942),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Arial',
      ),
      home: const OjasHomePage(),
    );
  }
}

class OjasHomePage extends StatefulWidget {
  const OjasHomePage({super.key});

  @override
  State<OjasHomePage> createState() => _OjasHomePageState();
}

class _OjasHomePageState extends State<OjasHomePage> {
  int _selectedTab = 0;
  final Set<int> _likedPosts = <int>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1222),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 24,
        title: const Text(
          'OJAS',
          style: TextStyle(
            color: Color(0xFFF5B942),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 20),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFF5B942),
              child: Text(
                'AK',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 1180 : double.infinity,
              ),
              child: _selectedTab == 0
                  ? _buildFeed(context, isDesktop)
                  : _buildPlaceholderTab(_selectedTab),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  Widget _buildFeed(BuildContext context, bool isDesktop) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 36 : 18,
        28,
        isDesktop ? 36 : 18,
        40,
      ),
      children: [
        Text(
          'GOOD MORNING, AKASH',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFFF5B942),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your creative space',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        _sectionHeader('Trending today', 'View all'),
        const SizedBox(height: 14),
        _buildPostCard(
          id: 1,
          name: 'Maya Chen',
          handle: '@mayamakes',
          time: '2h ago',
          title: 'Finding quiet in the middle of the city.',
          body:
              'A study in soft light, hard lines, and the small pauses between everything.',
          tags: const ['#urban', '#photography'],
          imageColor: const Color(0xFFB46A42),
          icon: Icons.wb_twilight_rounded,
          likes: '248',
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 18),
        _buildPostCard(
          id: 2,
          name: 'Rohan Mehta',
          handle: '@rohanbuilds',
          time: '5h ago',
          title: 'The tools that make ideas feel possible.',
          body:
              'Sharing my minimal desk setup and the little rituals that keep the work moving.',
          tags: const ['#workspace', '#process'],
          imageColor: const Color(0xFF4A6C72),
          icon: Icons.auto_awesome_rounded,
          likes: '186',
          isDesktop: isDesktop,
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, String action) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      TextButton(
        onPressed: () {},
        child: Text(action, style: const TextStyle(color: Color(0xFFF5B942))),
      ),
    ],
  );

  Widget _buildPostCard({
    required int id,
    required String name,
    required String handle,
    required String time,
    required String title,
    required String body,
    required List<String> tags,
    required Color imageColor,
    required IconData icon,
    required String likes,
    required bool isDesktop,
  }) {
    final liked = _likedPosts.contains(id);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111A2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF253149)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: imageColor.withValues(alpha: .7),
                  child: Text(name[0]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$handle  ·  $time',
                        style: const TextStyle(
                          color: Color(0xFF8C98AE),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz_rounded),
                  tooltip: 'More options',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFFAFB9C9),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  children: tags
                      .map(
                        (tag) => Text(
                          tag,
                          style: const TextStyle(
                            color: Color(0xFFF5B942),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: isDesktop ? 2.7 : 1.65,
            child: DecoratedBox(
              decoration: BoxDecoration(color: imageColor),
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                  Center(
                    child: Icon(
                      icon,
                      size: 58,
                      color: Colors.white.withValues(alpha: .82),
                    ),
                  ),
                  const Positioned(
                    left: 16,
                    bottom: 14,
                    child: Text(
                      'OJAS / VISUAL DIARY',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => requireAuth(context, () {
                    setState(() {
                      liked ? _likedPosts.remove(id) : _likedPosts.add(id);
                    });
                  }),
                  icon: Icon(
                    liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: liked ? const Color(0xFFEF6B73) : null,
                  ),
                  tooltip: 'Like',
                ),
                Text(
                  liked ? '${int.parse(likes) + 1}' : likes,
                  style: const TextStyle(color: Color(0xFFAFB9C9)),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => requireAuth(context, () => _showActionMessage('Comments are ready for your thoughts.')),
                  icon: const Icon(Icons.mode_comment_outlined),
                  tooltip: 'Comment',
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => requireAuth(context, () => _showActionMessage('Post shared.')),
                  icon: const Icon(Icons.ios_share_rounded),
                  tooltip: 'Share',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showActionMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildPlaceholderTab(int tab) {
    if (tab == 3) return _buildProfileTab();
    final labels = ['Discover', 'Create something', 'Your profile'];
    final icons = [
      Icons.explore_rounded,
      Icons.add_circle_outline_rounded,
      Icons.person_outline_rounded,
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icons[tab - 1], size: 54, color: const Color(0xFFF5B942)),
            const SizedBox(height: 16),
            Text(
              labels[tab - 1],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This space is ready for your next idea.',
              style: TextStyle(color: Color(0xFF9CA8BB)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return StreamBuilder(
      stream: AuthService.instance.authStateChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(builder: (_) => const LoginScreen()),
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Log in to view your profile'),
            ),
          );
        }
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFF5B942),
                child: Text(
                  (user.displayName?.isNotEmpty == true
                          ? user.displayName![0]
                          : user.email![0])
                      .toUpperCase(),
                  style: const TextStyle(color: Color(0xFF111827), fontSize: 25, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 14),
              Text(user.displayName ?? user.email ?? 'OJAS creator', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.instance.signOut();
                  if (mounted) setState(() => _selectedTab = 0);
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavigationBar() {
    const items = [
      (Icons.home_rounded, 'Home'),
      (Icons.explore_outlined, 'Discover'),
      (Icons.add_box_outlined, 'Create'),
      (Icons.person_outline_rounded, 'Profile'),
    ];
    return NavigationBar(
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) {
        if (index == 2) {
          requireAuth(context, () => setState(() => _selectedTab = index));
          return;
        }
        setState(() => _selectedTab = index);
      },
      backgroundColor: const Color(0xFF0B1222),
      indicatorColor: const Color(0xFFF5B942).withValues(alpha: .16),
      destinations: items
          .map(
            (item) =>
                NavigationDestination(icon: Icon(item.$1), label: item.$2),
          )
          .toList(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .1)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
