import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide debugPrint;
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/create_screen.dart';
import 'screens/ojs_feed_screen.dart';
import 'screens/ojas_shop_screen.dart';
import 'screens/you_hub_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/creator_profile_screen.dart';
import 'widgets/world_search_delegate.dart';
import 'widgets/share_bottom_sheet.dart';
import 'widgets/home_story_viewer.dart';
import 'widgets/home_comments_sheet.dart';
import 'widgets/super_thanks_modal.dart';
import 'widgets/ojas_smart_video_player.dart';
import 'services/video_engine_service.dart';
import 'services/auth_guard.dart';
import 'services/notification_service.dart';
import 'screens/notification_chat_router.dart';

final GlobalKey<NavigatorState> ojasNavigatorKey = GlobalKey<NavigatorState>();
String? _lastOpenedMessageId;

Future<void> _openNotificationChat(NotificationOpenData data) async {
  if (_lastOpenedMessageId == data.messageId) {
    return;
  }
  _lastOpenedMessageId = data.messageId;
  final navigator = ojasNavigatorKey.currentState;
  if (navigator == null) {
    return;
  }
  navigator.push(
    MaterialPageRoute(
      builder: (_) => NotificationChatRouter(openData: data),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.instance.initialize();
  } catch (_) {}

  runApp(const OjasApp());

  NotificationService.instance.onNotificationOpened.listen(_openNotificationChat);
  final pendingOpen = NotificationService.instance.consumePendingOpen();
  if (pendingOpen != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openNotificationChat(pendingOpen);
    });
  }
}

class OjasApp extends StatelessWidget {
  const OjasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: ojasNavigatorKey,
      title: 'OJAS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF111827),
          brightness: Brightness.light,
        ),
        fontFamily: 'sans-serif',
        useMaterial3: true,
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
  bool _authGateLoading = false;

  final Set<int> _likedPosts = <int>{};
  final Set<int> _savedPosts = <int>{};

  final List<Map<String, dynamic>> _stories = [
    {
      'name': 'Your Story',
      'isUser': true,
      'avatar': '',
      'color': const Color(0xFFF3F4F6),
    },
    {
      'name': 'Maya Chen',
      'isUser': false,
      'avatar': 'M',
      'color': const Color(0xFFE5A87B),
      'caption': 'Sunset lighting in the city 🌆',
    },
    {
      'name': 'Rohan',
      'isUser': false,
      'avatar': 'R',
      'color': const Color(0xFF93C5FD),
      'caption': 'Mixing modular synths in studio 🎧',
    },
    {
      'name': 'Sneha',
      'isUser': false,
      'avatar': 'S',
      'color': const Color(0xFFC5C6E9),
      'caption': 'Vindhya folk music session 🌿',
    },
    {
      'name': 'Nikhil',
      'isUser': false,
      'avatar': 'N',
      'color': const Color(0xFFFFD36B),
      'caption': 'New digital art drops today 🎨',
    },
  ];

  final List<Map<String, dynamic>> _posts = [
    {
      'id': 1,
      'name': 'Maya Chen',
      'handle': '@mayamakes',
      'time': '2h ago',
      'title': 'Finding quiet in the middle of the city.',
      'body':
          'A study in soft light, hard lines, and the small pauses between everything. Captured with 35mm lens in Satna.',
      'tags': ['#urban', '#photography', '#ojas'],
      'videoUrl':
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      'isPortraitReel': true,
      'aspectRatio': 9 / 16,
      'likes': 248,
      'comments': 124,
      'commentsList': <String>[
        'Pure magic in this frame! ✨',
        'Which lens is this?',
      ],
    },
    {
      'id': 2,
      'name': 'Rohan Mehta',
      'handle': '@rohanbuilds',
      'time': '5h ago',
      'title': 'The tools that make ideas feel possible.',
      'body':
          'Layering native Vindhya folk rhythm with modular synthesizers. Simple analog beats and rich textures.',
      'tags': ['#workspace', '#process', '#beats'],
      'videoUrl':
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      'isPortraitReel': false,
      'aspectRatio': 16 / 9,
      'likes': 186,
      'comments': 94,
      'commentsList': <String>[
        'Those low frequencies hit hard! 🔥',
        'Sample pack dropped?',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    final urls = _posts
        .map((post) => post['videoUrl'] as String)
        .toList(growable: false);
    VideoEngineService.instance.prefetchNextVideos(urls);
  }

  void _openReelInOjsFeed() {
    HapticFeedback.mediumImpact();
    setState(() => _selectedTab = 1);
  }

  void _onTabSelected(int index) {
    if (index == _selectedTab) return;
    HapticFeedback.selectionClick();
    if (index == 2) {
      _requestCreate();
      return;
    }
    setState(() => _selectedTab = index);
  }

  @override
  Widget build(BuildContext context) {
    final bool hideAppBar = _selectedTab != 0;
    final bool isOjsDark = _selectedTab == 1;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isOjsDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isOjsDark ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness:
            isOjsDark ? Brightness.light : Brightness.dark,
      ),
    );

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
            extendBody: isOjsDark,
            backgroundColor:
                isOjsDark ? Colors.black : const Color(0xFFFAFAFA),
            appBar: hideAppBar
                ? null
                : AppBar(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    titleSpacing: 0,
                    leading: IconButton(
                      tooltip: 'Search & Discover',
                      icon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF111827),
                        size: 24,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        WorldSearchSheet.show(context);
                      },
                    ),
                    title: const Text(
                      'OJAS',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                        color: Color(0xFF111827),
                      ),
                    ),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NotificationsScreen(),
                            ),
                          );
                        },
                        tooltip: 'Notifications',
                        icon: Stack(
                          children: [
                            const Icon(
                              Icons.notifications_none_rounded,
                              color: Color(0xFF111827),
                              size: 25,
                            ),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 14, left: 4),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTab = 4);
                          },
                          child: _buildDynamicUserAvatar(radius: 14),
                        ),
                      ),
                    ],
                  ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth >= 900;
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
                        const OjasShopScreen(),
                        _buildProfileTab(),
                      ],
                    ),
                  ),
                );
              },
            ),
            bottomNavigationBar: _buildMinimalBottomBar(isDark: isOjsDark),
          ),
          if (_authGateLoading) _buildAuthLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildDynamicUserAvatar({required double radius}) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF111827),
            child: Text(
              'O',
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.85,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF111827),
            backgroundImage: NetworkImage(user.photoURL!),
          );
        }
        String initial = 'U';
        if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          initial = user.displayName!.trim()[0].toUpperCase();
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF111827),
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.85,
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
        if (mounted) {
          setState(() => _selectedTab = 2);
        }
      },
      onLoadingChanged: (loading) {
        if (mounted) {
          setState(() => _authGateLoading = loading);
        }
      },
      onError: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  Widget _buildAuthLoadingOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Color(0x2E000000),
          ),
          Center(
            child: Card(
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(width: 14),
                    Text(
                      'Checking your profile...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
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
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      key: const PageStorageKey<String>('ojas-home-feed'),
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 36 : 0,
        10,
        isDesktop ? 36 : 0,
        40,
      ),
      children: [
        SizedBox(
          height: 98,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _stories.length,
            itemBuilder: (context, index) {
              final story = _stories[index];
              final isUser = story['isUser'] as bool;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (isUser) {
                    _requestCreate();
                  } else {
                    HomeStoryViewer.show(
                      context,
                      userName: story['name'] as String,
                      avatarColor: story['color'] as Color,
                      storyCaption: story['caption'] as String? ?? '',
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isUser
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFF111827),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: story['color'] as Color,
                              child: isUser
                                  ? const Icon(
                                      Icons.person,
                                      color: Color(0xFF6B7280),
                                      size: 24,
                                    )
                                  : Text(
                                      story['avatar'] as String,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                          if (isUser)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF111827),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        story['name'] as String,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(
          color: Color(0xFFF3F4F6),
          height: 16,
          thickness: 1,
        ),
        ..._posts.map((post) => _buildFeedPost(context, post)),
      ],
    );
  }

  Widget _buildFeedPost(BuildContext context, Map<String, dynamic> post) {
    final int id = post['id'] as int;
    final bool liked = _likedPosts.contains(id);
    final bool saved = _savedPosts.contains(id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE5E7EB),
                    child: Text(
                      (post['name'] as String).substring(0, 1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${post['handle']} · ${post['time']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _openReelInOjsFeed,
              child: AspectRatio(
                aspectRatio: (post['aspectRatio'] as num).toDouble(),
                child: OjasSmartVideoPlayer(
                  videoUrl: post['videoUrl'] as String,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                post['title'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: Text(
                post['body'] as String,
                style: const TextStyle(
                  height: 1.4,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Wrap(
                spacing: 6,
                children: (post['tags'] as List<String>)
                    .map(
                      (tag) => Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (liked) {
                          _likedPosts.remove(id);
                        } else {
                          _likedPosts.add(id);
                        }
                      });
                    },
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF111827),
                    ),
                  ),
                  Text('${(post['likes'] as int) + (liked ? 1 : 0)}'),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      HomeCommentsSheet.show(
                        context,
                        postId: id.toString(),
                        creatorName: post['name'] as String,
                        initialComments:
                            List<String>.from(post['commentsList'] as List),
                        onCommentsUpdated: (_) {},
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  Text('${post['comments']}'),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (saved) {
                          _savedPosts.remove(id);
                        } else {
                          _savedPosts.add(id);
                        }
                      });
                    },
                    icon: Icon(
                      saved ? Icons.bookmark : Icons.bookmark_border,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOjsTab() {
    return const OjsFeedScreen(isActive: true);
  }

  Widget _buildProfileTab() {
    final firstPost = _posts.isNotEmpty ? _posts.first : null;
    return CreatorProfileScreen(
      creatorName: firstPost?['name'] as String? ?? 'OJAS Creator',
      avatarColor: firstPost?['color'] as Color? ?? const Color(0xFFE5E7EB),
    );
  }

  Widget _buildMinimalBottomBar({required bool isDark}) {
    return NavigationBar(
      backgroundColor: isDark ? Colors.black : Colors.white,
      indicatorColor: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : const Color(0xFFE5E7EB),
      selectedIndex: _selectedTab,
      onDestinationSelected: _onTabSelected,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.play_circle_outline_rounded),
          selectedIcon: Icon(Icons.play_circle_rounded),
          label: 'OJS',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_box_outlined),
          selectedIcon: Icon(Icons.add_box_rounded),
          label: 'Create',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_bag_outlined),
          selectedIcon: Icon(Icons.shopping_bag_rounded),
          label: 'Shop',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'You',
        ),
      ],
    );
  }
}
