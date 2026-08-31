import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide debugPrint;

import 'firebase_options.dart';
import 'screens/create_screen.dart';
import 'screens/ojs_feed_screen.dart';
import 'screens/world_screen.dart';
import 'screens/you_hub_screen.dart';
import 'services/auth_guard.dart';

Future<void> main() async {
  debugPrint('MAIN STARTED');
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('FIREBASE OK');
  } catch (error, stackTrace) {
    debugPrint('FIREBASE FAILED: $error');
    debugPrint(stackTrace.toString());
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

  debugPrint('ABOUT TO CALL runApp');
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
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5B942),
          brightness: Brightness.light,
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
  bool _authGateLoading = false;

  @override
  Widget build(BuildContext context) {
    final hideAppBar = _selectedTab == 1 || _selectedTab == 2 || _selectedTab == 4;

    return PopScope<void>(
      canPop: _selectedTab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedTab != 0) {
          setState(() => _selectedTab = 0);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(
            extendBody: _selectedTab == 1,
            appBar: hideAppBar
                ? null
                : AppBar(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    titleSpacing: 18,
                    title: _buildAppBrandLogo(),
                    actions: [
                      IconButton(
                        onPressed: () {},
                        tooltip: 'Notifications',
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _buildDynamicUserAvatar(),
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
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        _buildFeed(context, isDesktop),
                        _buildOjsTab(),
                        const CreateScreen(),
                        const WorldScreen(),
                        _buildProfileTab(),
                      ],
                    ),
                  ),
                );
              },
            ),
            bottomNavigationBar: _buildNavigationBar(),
          ),
          if (_authGateLoading) _buildAuthLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildAppBrandLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: const LinearGradient(
              colors: [Color(0xFFE02E6E), Color(0xFFFF8235), Color(0xFFFFC043)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE02E6E).withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'OJAS',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicUserAvatar() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFF3F4F6),
            child: Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF6B7280)),
          );
        }

        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          return CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFF5B942),
            backgroundImage: NetworkImage(user.photoURL!),
          );
        }

        String initial = 'U';
        if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          initial = user.displayName!.trim()[0].toUpperCase();
        } else if (user.email != null && user.email!.isNotEmpty) {
          initial = user.email![0].toUpperCase();
        }

        return CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFF5B942),
          child: Text(
            initial,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  void _requestCreate() {
    if (_authGateLoading) return;
    setState(() => _authGateLoading = true);
    requireAuth(
      context,
      () {
        if (mounted) setState(() => _selectedTab = 2);
      },
      onLoadingChanged: (loading) {
        if (mounted) setState(() => _authGateLoading = loading);
      },
      onError: _showAuthError,
    );
  }

  void _showAuthError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: 'Retry', onPressed: _requestCreate),
        ),
      );
  }

  Widget _buildAuthLoadingOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Color(0x2E000000),
            semanticsLabel: 'Checking your account',
          ),
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Checking your profile...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed(BuildContext context, bool isDesktop) {
    return ListView(
      key: const PageStorageKey<String>('ojas-home-feed'),
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 36 : 18,
        20,
        isDesktop ? 36 : 18,
        40,
      ),
      children: [
        Text(
          'YOUR CREATIVE SPACE',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFFF5B942),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Explore stories & creations',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 20),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                          color: Color(0xFF6B7280),
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
                    color: Color(0xFF4B5563),
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
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => requireAuth(
                    context,
                    () => _showActionMessage(
                      'Comments are ready for your thoughts.',
                    ),
                  ),
                  icon: const Icon(Icons.mode_comment_outlined),
                  tooltip: 'Comment',
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => requireAuth(
                    context,
                    () => _showActionMessage('Post shared.'),
                  ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildOjsTab() {
    return OjsFeedScreen(isActive: _selectedTab == 1);
  }

  Widget _buildProfileTab() {
    return YouHubScreen(
      onLoggedOut: () {
        if (mounted) setState(() => _selectedTab = 0);
      },
    );
  }

  Widget _buildNavigationBar() {
    const items = [
      (Icons.home_outlined, Icons.home_rounded, 'Home'),
      (Icons.smart_display_outlined, Icons.smart_display_rounded, 'OJS'),
      (Icons.add_box_outlined, Icons.add_box, 'Create'),
      (Icons.explore_outlined, Icons.explore, 'World'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'You'),
    ];
    return NavigationBar(
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) {
        if (index == _selectedTab) return;
        if (index == 2) {
          _requestCreate();
          return;
        }
        setState(() => _selectedTab = index);
      },
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFF5B942).withValues(alpha: .16),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      height: 60,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      destinations: items
          .map(
            (item) => NavigationDestination(
              icon: Icon(item.$1, size: 28),
              selectedIcon: Icon(item.$2, size: 28),
              label: item.$3,
              tooltip: item.$3,
            ),
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

