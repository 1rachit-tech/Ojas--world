import 'package:flutter/material.dart';
import 'creator_profile_screen.dart';
import 'notifications_screen.dart';
import '../widgets/share_bottom_sheet.dart';
import '../widgets/home_story_viewer.dart';
import '../widgets/home_comments_sheet.dart';
import '../widgets/super_thanks_modal.dart';
import '../widgets/world_search_delegate.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
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
      'id': 'p1',
      'creator': 'Maya Chen',
      'handle': '@mayamakes',
      'avatarColor': const Color(0xFFE5A87B),
      'time': '2h ago',
      'title': 'Finding quiet in the middle of the city.',
      'body':
          'A study in soft light, hard lines, and the small pauses between everything. Captured with 35mm lens in Satna.',
      'tags': ['#urban', '#photography', '#ojas'],
      'mediaColor': const Color(0xFFB45309),
      'likes': 1420,
      'comments': 124,
      'isLiked': false,
      'isSaved': false,
      'commentsList': <String>[
        'Pure magic in this frame! ✨',
        'Which lens is this?',
      ],
    },
    {
      'id': 'p2',
      'creator': 'Rohan Mehta',
      'handle': '@rohanbuilds',
      'avatarColor': const Color(0xFF93C5FD),
      'time': '5h ago',
      'title': 'The tools that make ideas feel possible.',
      'body':
          'Layering native Vindhya folk rhythm with modular synthesizers. Simple analog beats and rich textures.',
      'tags': ['#music', '#production', '#beats'],
      'mediaColor': const Color(0xFF1E3A8A),
      'likes': 2890,
      'comments': 310,
      'isLiked': true,
      'isSaved': true,
      'commentsList': <String>[
        'Those low frequencies hit hard! 🔥',
        'Sample pack dropped?',
      ],
    },
  ];

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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening Story Camera...')),
                    );
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
                  SuperThanksModal.show(context, creatorName: post['creator'] as String);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        titleSpacing: 16,
        leading: IconButton(
          tooltip: 'Search World',
          icon: const Icon(Icons.search_rounded, color: Color(0xFF111827), size: 26),
          onPressed: () => WorldSearchSheet.show(context),
        ),
        title: const Text(
          'OJAS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            color: Color(0xFF111827),
            fontFamily: 'sans-serif',
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // 1. Stories Tray
          SliverToBoxAdapter(
            child: Container(
              height: 104,
              color: Colors.transparent,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
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
                                  gradient: isUser
                                      ? null
                                      : const LinearGradient(
                                          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                ),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: story['color'] as Color,
                                  child: isUser
                                      ? const Icon(Icons.person, color: Color(0xFF6B7280))
                                      : Text(
                                          story['avatar'] as String,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
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
          ),

          const SliverToBoxAdapter(
            child: Divider(color: Color(0xFFF3F4F6), height: 16, thickness: 1),
          ),

          // 2. Main Community Posts Feed
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final post = _posts[index];
                return _buildPostCard(post);
              },
              childCount: _posts.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
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
          // Header: Creator Profile & Options
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreatorProfileScreen(
                      creatorName: post['creator'] as String,
                      avatarColor: post['avatarColor'] as Color,
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: post['avatarColor'] as Color,
                child: Text(
                  (post['creator'] as String)[0],
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
                      creatorName: post['creator'] as String,
                      avatarColor: post['avatarColor'] as Color,
                    ),
                  ),
                );
              },
              child: Text(
                post['creator'] as String,
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
                        color: Color(0xFFD97706),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Media Showcase Container
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
                color: post['mediaColor'] as Color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.play_circle_fill_rounded, size: 54, color: Colors.white),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'OJAS / EXCLUSIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Rail (Like, Comment, Super Thanks, Share, Save)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    post['isLiked'] as bool
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: post['isLiked'] as bool
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF4B5563),
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      post['isLiked'] = !(post['isLiked'] as bool);
                      post['likes'] = (post['likes'] as int) +
                          (post['isLiked'] as bool ? 1 : -1);
                    });
                  },
                ),
                Text(
                  '${post['likes']}',
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
                      postId: post['id'] as String,
                      creatorName: post['creator'] as String,
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
                  '${post['comments']}',
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
                    SuperThanksModal.show(context, creatorName: post['creator'] as String);
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.reply_rounded, color: Color(0xFF4B5563), size: 24),
                  onPressed: () {
                    ShareBottomSheet.show(
                      context,
                      videoUrl: 'https://ojas.app/post/${post['id']}',
                      creatorName: post['creator'] as String,
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    post['isSaved'] as bool
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: post['isSaved'] as bool
                        ? const Color(0xFF111827)
                        : const Color(0xFF4B5563),
                    size: 24,
                  ),
                  onPressed: () {
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
