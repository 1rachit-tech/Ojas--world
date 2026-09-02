import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ojs_video.dart';

class YouHubScreen extends StatefulWidget {
  final VoidCallback? onLoggedOut;

  const YouHubScreen({super.key, this.onLoggedOut});

  @override
  State<YouHubScreen> createState() => _YouHubScreenState();
}

class _YouHubScreenState extends State<YouHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // 🚀 FIXED: Restored to 4 Tabs (Videos, Saved, Drafts, Messages)
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleLogout() async {
    HapticFeedback.mediumImpact();
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out of OJAS?',
          style: TextStyle(color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (widget.onLoggedOut != null) {
        widget.onLoggedOut!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'You',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF111827)),
            onPressed: () {
              HapticFeedback.selectionClick();
              // Settings Page Action
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Profile Info Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: const Color(0xFFF3F4F6),
                          backgroundImage: (currentUser?.photoURL != null) 
                              ? NetworkImage(currentUser!.photoURL!) 
                              : null,
                          child: (currentUser?.photoURL == null)
                              ? Text(
                                  currentUser?.displayName?.isNotEmpty == true
                                      ? currentUser!.displayName![0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser?.displayName ?? 'OJAS Creator',
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentUser?.email ?? 'No email linked',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Edit Profile',
                                style: TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Creator Stats & Earnings Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(Icons.visibility_rounded, '12.4K', 'Total Views'),
                        Container(width: 1, height: 32, color: const Color(0xFFE5E7EB)),
                        _buildStatItem(Icons.favorite_rounded, '3.2K', 'Total Likes'),
                        Container(width: 1, height: 32, color: const Color(0xFFE5E7EB)),
                        _buildStatItem(Icons.stars_rounded, '₹450', 'Super Thanks', color: const Color(0xFFD97706)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // 3. Persistent Tab Bar (Now with 4 Tabs including Messages)
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF111827),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF111827),
                unselectedLabelColor: const Color(0xFF9CA3AF),
                onTap: (index) => HapticFeedback.selectionClick(),
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on_rounded, size: 22)),
                  Tab(icon: Icon(Icons.bookmark_outline_rounded, size: 24)),
                  Tab(icon: Icon(Icons.inventory_2_outlined, size: 22)),
                  Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 22)), // 🚀 Messages Tab Restored
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildVideoGrid(isDrafts: false), // 1. Published Videos
            _buildVideoGrid(isDrafts: false, isSaved: true), // 2. Saved Videos
            _buildVideoGrid(isDrafts: true), // 3. Drafts
            _buildMessagesList(), // 4. Direct Messages (Inbox)
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, {Color color = const Color(0xFF111827)}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoGrid({required bool isDrafts, bool isSaved = false}) {
    final int itemCount = isDrafts ? 2 : (isSaved ? 5 : 8);

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Icon(
                  isDrafts ? Icons.edit_document : Icons.play_circle_outline_rounded,
                  color: const Color(0xFFD1D5DB),
                  size: 28,
                ),
              ),
              if (!isDrafts)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow_rounded, color: Color(0xFF6B7280), size: 14),
                      const SizedBox(width: 2),
                      Text(
                        '${(index + 1) * 1.2}K',
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isDrafts)
                const Positioned(
                  left: 6,
                  bottom: 6,
                  child: Text(
                    'Draft',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 🚀 Clean Minimalist Messages Inbox UI
  Widget _buildMessagesList() {
    final List<Map<String, String>> dummyChats = [
      {'name': 'Maya Chen', 'msg': 'Loved your recent Folk track! 🔥', 'time': '2m', 'color': '0xFFD97706', 'unread': '1'},
      {'name': 'Brand Collab', 'msg': 'Are you available for a sponsored video?', 'time': '1h', 'color': '0xFF2563EB', 'unread': '0'},
      {'name': 'Rohan Mehta', 'msg': 'Sent an attachment.', 'time': '3h', 'color': '0xFF059669', 'unread': '0'},
      {'name': 'Sneha Rao', 'msg': 'Can you share the camera settings you used?', 'time': '1d', 'color': '0xFFDB2777', 'unread': '0'},
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: dummyChats.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFFF3F4F6), height: 1, indent: 70),
      itemBuilder: (context, index) {
        final chat = dummyChats[index];
        final bool hasUnread = chat['unread'] != '0';
        
        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            // Open Chat Screen
          },
          highlightColor: const Color(0xFFF9FAFB),
          splashColor: const Color(0xFFF3F4F6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(int.parse(chat['color']!)),
                  child: Text(
                    chat['name']![0],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat['name']!,
                        style: TextStyle(
                          color: const Color(0xFF111827),
                          fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat['msg']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasUnread ? const Color(0xFF111827) : const Color(0xFF6B7280),
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      chat['time']!,
                      style: TextStyle(
                        color: hasUnread ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (hasUnread)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          chat['unread']!,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Helper class for sticky TabBar in Minimalist White UI
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
