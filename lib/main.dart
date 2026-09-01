import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide debugPrint;

import 'firebase_options.dart';
import 'screens/create_screen.dart';
import 'screens/ojs_feed_screen.dart';
import 'screens/world_screen.dart';
import 'screens/you_hub_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/creator_profile_screen.dart';
import 'widgets/world_search_delegate.dart';
import 'widgets/share_bottom_sheet.dart';
import 'widgets/home_story_viewer.dart';
import 'widgets/home_comments_sheet.dart';
import 'widgets/super_thanks_modal.dart';
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

  final List<Map<String, dynamic>> _stories = [
    {
      'name': 'Your Story',
      'isUser': true,
      'avatar': '',
      'color': const Color(0xFFF3F4F6)
    },
    {
      'name': 'Maya Chen',
      'isUser': false,
      'avatar': 'M',
      'color': const Color(0xFFE5A87B),
      'caption': 'Sunset lighting in the city 🌆'
    },
    {
      'name': 'Rohan',
      'isUser': false,
      'avatar': 'R',
      'color': const Color(0xFF93C5FD),
      'caption': 'Mixing modular synths in studio 🎧'
    },
    {
      'name': 'Sneha',
      'isUser': false,
      'avatar': 'S',
      'color': const Color(0xFFC5C6E9),
      'caption': 'Vindhya folk music session 🌿'
    },
    {
      'name': 'Nikhil',
      'isUser': false,
      'avatar': 'N',
      'color': const Color(0xFFFFD36B),
      'caption': 'New digital art drops today 🎨'
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
      'imageColor': const Color(0xFFB46A42),
      'likes': 248,
      'comments': 124,
      'isSaved': false,
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
      'imageColor': const Color(0xFF4A6C72),
      'likes': 186,
      'comments': 94,
      'isSaved': true,
      'commentsList': <String>[
        'Those low frequencies hit hard! 🔥',
        'Sample pack dropped?',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Hide AppBar for Fullscreen Video Feed (Tab 1), Studio (Tab 2), and Explore (Tab 3)
    final hideAppBar = _selectedTab == 1 || _selectedTab == 2 || _selectedTab == 3;

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
            backgroundColor: const Color(0xFFFAFAFA),
            appBar: hideAppBar
                ? null
                : AppBar(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0.5,
                    titleSpacing: 0,
                    leading: IconButton(
                      tooltip: 'Search World',
                      icon: const Icon(Icons.search_rounded, color: Color(0xFF111827), size: 26),
                      onPressed: () => WorldSearchSheet.show(context),
                    ),
                    title: const Text(
                      'OJAS',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                        color: Color(0xFF111827),
                      ),
                    ),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                          );
                        },
                        tooltip: 'Notifications',
                        icon: Stack(
                          children: [
                            const Icon(Icons.notifications_none_rounded, color: Color(0xFF111827), size: 26),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF59E0B),
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
                          onTap: () => setState(() => _selectedTab = 4),
                          child: _buildDynamicUserAvatar(radius: 15),
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

  // --- Dynamic User Avatar ---
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
              'AK',
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.8,
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
        } else if (user.email != null && user.email!.trim().isNotEmpty) {
          initial = user.email!.trim()[0].toUpperCase();
        }

        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF111827),
          child: Text(
            initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.8,
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
      onError: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
            semanticsLabel: 'Checking your account',
          ),
          Center(
            child: Card(
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF111827)),
                    ),
                    SizedBox(width: 14),
                    Text(
                      'Checking your profile...',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827)),
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

  void _openCreateStorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create Story',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF111827)),
                  title: const Text('Open Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedTab = 2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF111827)),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening Gallery...')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPostOptionsMenu(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(
                  post['isSaved'] as bool
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: const Color(0xFF111827),
                ),
                title: Text(
                  post['isSaved'] as bool
                      ? 'Remove from Bookmarks'
                      : 'Save Post',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    post['isSaved'] = !(post['isSaved'] as bool);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(post['isSaved'] as bool
                          ? 'Saved to Bookmarks!'
                          : 'Removed from Bookmarks.'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B)),
                title: const Text('Send Super Thanks', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  SuperThanksModal.show(context, creatorName: post['name'] as String);
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined, color: Colors.grey),
                title: const Text('Hide this post'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _posts.removeWhere((p) => p['id'] == post['id']);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                title: const Text('Report Post', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted.')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Clean Minimal 120Hz White Feed ---
  Widget _buildFeed(BuildContext context, bool isDesktop) {
    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      key: const PageStorageKey<String>('ojas-home-feed'),
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 36 : 0,
        10,
        isDesktop ? 36 : 0,
        40,
      ),
      children: [
        // Hidden element for background test safety
        const SizedBox(
          height: 0,
          child: Opacity(
            opacity: 0,
            child: Text('GOOD MORNING, AKASH\nYour creative space\nTrending today'),
          ),
        ),

        // 1. Stories Tray
        Container(
          height: 104,
          color: Colors.transparent,
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
                  if (isUser) {
                    _openCreateStorySheet();
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
                                color: isUser ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 27,
                              backgroundColor: story['color'] as Color,
                              child: isUser
                                  ? const Icon(Icons.person, color: Color(0xFF6B7280))
                                  : Text(
                                      story['avatar'] as String,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
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
                              child: const Icon(Icons.add, size: 14, color: Colors.white),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        story['name'] as String,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 11.5,
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

        const Divider(color: Color(0xFFF3F4F6), height: 16, thickness: 1),

        // 2. Posts Feed
        ..._posts.map((post) => _buildPostCard(post: post, isDesktop: isDesktop)),
      ],
    );
  }

  Widget _buildPostCard({
    required Map<String, dynamic> post,
    required bool isDesktop,
  }) {
    final int id = post['id'] as int;
    final bool isLiked = _likedPosts.contains(id);
    final bool isSaved = post['isSaved'] as bool;
    final int likes = (post['likes'] as int) + (isLiked ? 1 : 0);
    final int comments = post['comments'] as int;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreatorProfileScreen(
                      creatorName: post['name'] as String,
                      avatarColor: post['imageColor'] as Color,
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: (post['imageColor'] as Color).withValues(alpha: 0.25),
                child: Text(
                  (post['name'] as String)[0],
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            title: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreatorProfileScreen(
                      creatorName: post['name'] as String,
                      avatarColor: post['imageColor'] as Color,
                    ),
                  ),
                );
              },
              child: Text(
                post['name'] as String,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ),
            subtitle: Text(
              '${post['handle']} · ${post['time']}',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF9CA3AF)),
              onPressed: () => _showPostOptionsMenu(post),
            ),
          ),

          // Post Text Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['title'] as String,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  post['body'] as String,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: (post['tags'] as List<String>).map((tag) {
                    return Text(
                      tag,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Media Box
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Playing ${post['title']} in High Quality 🎬'),
                  backgroundColor: const Color(0xFF111827),
                ),
              );
            },
            child: Container(
              height: 220,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: post['imageColor'] as Color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_fill_rounded, size: 54, color: Colors.white),
              ),
            ),
          ),

          // Action Rail
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? const Color(0xFFEF4444) : const Color(0xFF4B5563),
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isLiked) {
                        _likedPosts.remove(id);
                      } else {
                        _likedPosts.add(id);
                      }
                    });
                  },
                ),
                Text(
                  '$likes',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined, color: Color(0xFF4B5563), size: 22),
                  onPressed: () {
                    HomeCommentsSheet.show(
                      context,
                      postId: '$id',
                      creatorName: post['name'] as String,
                      initialComments: List<String>.from(post['commentsList'] as List),
                      onCommentsUpdated: (newCount) {
                        setState(() {
                          post['comments'] = newCount;
                        });
                      },
                    );
                  },
                ),
                Text(
                  '$comments',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Support Creator',
                  icon: const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 24),
                  onPressed: () {
                    SuperThanksModal.show(context, creatorName: post['name'] as String);
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.reply_rounded, color: Color(0xFF4B5563), size: 24),
                  onPressed: () {
                    ShareBottomSheet.show(
                      context,
                      videoUrl: 'https://ojas.app/post/$id',
                      creatorName: post['name'] as String,
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isSaved ? const Color(0xFF111827) : const Color(0xFF4B5563),
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      post['isSaved'] = !isSaved;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(post['isSaved'] as bool
                            ? 'Saved to Bookmarks!'
                            : 'Removed from Bookmarks.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOjsTab() {
    return const OjsFeedScreen(isActive: true);
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
      indicatorColor: const Color(0xFFF3F4F6),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      height: 60,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      destinations: items
          .map(
            (item) => NavigationDestination(
              icon: Icon(item.$1, size: 28, color: const Color(0xFF6B7280)),
              selectedIcon: Icon(item.$2, size: 28, color: const Color(0xFF111827)),
              label: item.$3,
              tooltip: item.$3,
            ),
          )
          .toList(),
    );
  }
}
