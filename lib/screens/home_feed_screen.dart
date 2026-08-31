import 'package:flutter/material.dart';
import 'creator_profile_screen.dart';
import 'notifications_screen.dart';
import '../widgets/share_bottom_sheet.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final List<Map<String, dynamic>> _stories = [
    {'name': 'Your Story', 'isUser': true, 'avatar': '', 'color': const Color(0xFF21262D)},
    {'name': 'Maya Chen', 'isUser': false, 'avatar': 'M', 'color': const Color(0xFFE5A87B)},
    {'name': 'Rohan', 'isUser': false, 'avatar': 'R', 'color': const Color(0xFF93C5FD)},
    {'name': 'Sneha', 'isUser': false, 'avatar': 'S', 'color': const Color(0xFFC5C6E9)},
    {'name': 'Nikhil', 'isUser': false, 'avatar': 'N', 'color': const Color(0xFFFFD36B)},
  ];

  final List<Map<String, dynamic>> _posts = [
    {
      'id': 'p1',
      'creator': 'Maya Chen',
      'handle': '@mayamakes',
      'avatarColor': const Color(0xFFE5A87B),
      'time': '2h ago',
      'title': 'Finding quiet in the middle of the city.',
      'body': 'A study in soft light, hard lines, and the small pauses between everything. Captured with 35mm lens.',
      'tags': ['#urban', '#cinematic', '#ojasart'],
      'mediaColor': const Color(0xFFB45309),
      'likes': 1420,
      'comments': 124,
      'isLiked': false,
      'isSaved': false,
      'commentsList': <String>[
        'Pure magic in this frame! ✨',
        'Which color grading LUT is this?',
      ],
    },
    {
      'id': 'p2',
      'creator': 'Rohan Mehta',
      'handle': '@rohanbuilds',
      'avatarColor': const Color(0xFF93C5FD),
      'time': '4h ago',
      'title': 'Sound Design Breakdown 🎧',
      'body': 'Layering native folk rhythm with deep modular synthesizers. Raw stems available in community hub.',
      'tags': ['#music', '#production', '#beats'],
      'mediaColor': const Color(0xFF1E3A8A),
      'likes': 2890,
      'comments': 310,
      'isLiked': true,
      'isSaved': true,
      'commentsList': <String>[
        'Those 808s hitting hard 🔥',
        'Drop the sample pack link bro!',
      ],
    },
  ];

  // Story Viewer Modal
  void _openStoryViewer(String name, Color color) {
    showDialog(
      context: context,
      builder: (context) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: color,
                          child: Text(
                            name[0],
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "$name's Story",
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sharing daily inspiration on OJAS.',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Create Story Modal
  void _openCreateStoryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Create Story', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFF5B942)),
                  title: const Text('Open Camera', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Camera for Story...')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFF5B942)),
                  title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Gallery...')));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Post Three-Dots Menu
  void _showPostOptionsMenu(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(
                  post['isSaved'] as bool ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: const Color(0xFFF5B942),
                ),
                title: Text(
                  post['isSaved'] as bool ? 'Remove from Saved' : 'Save Post',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    post['isSaved'] = !(post['isSaved'] as bool);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(post['isSaved'] as bool ? 'Post saved!' : 'Post removed from saved.')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined, color: Colors.white70),
                title: const Text('Hide this post', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _posts.removeWhere((p) => p['id'] == post['id']);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post hidden.')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                title: const Text('Report Post', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you. We will review this report.')));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Comments Bottom Sheet
  void _showPostCommentsSheet(Map<String, dynamic> post) {
    final TextEditingController commentCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final List<String> list = post['commentsList'] as List<String>;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Comments (${post['comments']})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(color: Colors.white10),
                    Expanded(
                      child: list.isEmpty
                          ? const Center(child: Text('No comments yet. Be the first!', style: TextStyle(color: Colors.white38)))
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(radius: 16, backgroundColor: Color(0xFFF5B942), child: Text('U', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                                  title: Text('Community Member', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  subtitle: Text(list[index], style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                                );
                              },
                            ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(color: const Color(0xFF21262D), borderRadius: BorderRadius.circular(24)),
                            child: TextField(
                              controller: commentCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Add a comment...',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFFF5B942)),
                          onPressed: () {
                            if (commentCtrl.text.trim().isNotEmpty) {
                              setSheetState(() {
                                list.insert(0, commentCtrl.text.trim());
                              });
                              setState(() {
                                post['comments'] = (post['comments'] as int) + 1;
                              });
                              commentCtrl.clear();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07090B),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            // OJAS Brand Text Logo
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFDF79), Color(0xFFF5B942), Color(0xFFE59819)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'OJAS',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                  color: Colors.white,
                  fontFamily: 'sans-serif',
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF5B942).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'FEED',
                style: TextStyle(
                  color: Color(0xFFF5B942),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Activity & Notifications',
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5B942),
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
          // 1. Stories Tray
          SliverToBoxAdapter(
            child: SizedBox(
              height: 104,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _stories.length,
                itemBuilder: (context, index) {
                  final story = _stories[index];
                  final isUser = story['isUser'] as bool;

                  return GestureDetector(
                    onTap: () {
                      if (isUser) {
                        _openCreateStoryModal();
                      } else {
                        _openStoryViewer(story['name'] as String, story['color'] as Color);
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
                                          colors: [Color(0xFFF5B942), Color(0xFFFF5252)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                ),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: story['color'] as Color,
                                  child: isUser
                                      ? const Icon(Icons.person, color: Colors.white70)
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
                                    color: Color(0xFFF5B942),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add, size: 14, color: Colors.black),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            story['name'] as String,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
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
            child: Divider(color: Colors.white10, height: 16),
          ),

          // 2. Posts Feed
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final post = _posts[index];
                return _buildCommunityPostCard(post);
              },
              childCount: _posts.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildCommunityPostCard(Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF13171D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name & Options
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
            ),
            subtitle: Text(
              '${post['handle']} · ${post['time']}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white54),
              onPressed: () => _showPostOptionsMenu(post),
            ),
          ),

          // Text Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['title'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  post['body'] as String,
                  style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.35),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: (post['tags'] as List<String>).map((tag) {
                    return Text(
                      tag,
                      style: const TextStyle(color: Color(0xFFF5B942), fontSize: 12.5, fontWeight: FontWeight.w600),
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
                SnackBar(content: Text("Playing ${post['title']} in high quality...")),
              );
            },
            child: Container(
              height: 220,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: post['mediaColor'] as Color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.play_circle_fill_rounded, size: 52, color: Colors.white70),
                  Positioned(
                    bottom: 8,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'OJAS / EXCLUSIVE',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Rail (Like, Comment, Share, Save)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    post['isLiked'] as bool ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: post['isLiked'] as bool ? const Color(0xFFFF5252) : Colors.white70,
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      post['isLiked'] = !(post['isLiked'] as bool);
                      post['likes'] = (post['likes'] as int) + (post['isLiked'] as bool ? 1 : -1);
                    });
                  },
                ),
                Text(
                  '${post['likes']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 14),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined, color: Colors.white70, size: 22),
                  onPressed: () => _showPostCommentsSheet(post),
                ),
                Text(
                  '${post['comments']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 14),
                IconButton(
                  icon: const Icon(Icons.reply_rounded, color: Colors.white70, size: 24),
                  onPressed: () {
                    ShareBottomSheet.show(
                      context,
                      videoUrl: 'https://ojas.app/post/${post['id']}',
                      creatorName: post['creator'] as String,
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    post['isSaved'] as bool ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: post['isSaved'] as bool ? const Color(0xFFF5B942) : Colors.white70,
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      post['isSaved'] = !(post['isSaved'] as bool);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(post['isSaved'] as bool ? 'Post saved to your bookmarks!' : 'Post removed from saved.')),
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
