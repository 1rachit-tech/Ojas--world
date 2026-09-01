import 'package:flutter/material.dart';
import '../widgets/account_switcher_sheet.dart';
import 'settings_screen.dart';

class YouHubScreen extends StatefulWidget {
  final VoidCallback? onLoggedOut;
  const YouHubScreen({super.key, this.onLoggedOut});

  @override
  State<YouHubScreen> createState() => _YouHubScreenState();
}

class _YouHubScreenState extends State<YouHubScreen> with SingleTickerProviderStateMixin {
  late TabController _mainTabController;

  @override
  void initState() {
    super.initState();
    // Tab 0 = Messages, Tab 1 = Profile
    _mainTabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        // Left: Profile Avatar (Opens Account Switcher)
        leading: Padding(
          padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
          child: GestureDetector(
            onTap: () => AccountSwitcherSheet.show(context),
            child: const CircleAvatar(
              backgroundColor: Color(0xFFF3F4F6),
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'), // Dummy image
            ),
          ),
        ),
        // Center: Messages & Profile Tabs
        title: TabBar(
          controller: _mainTabController,
          indicatorColor: const Color(0xFF111827),
          indicatorWeight: 2.5,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: const Color(0xFF111827),
          unselectedLabelColor: const Color(0xFF9CA3AF),
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Messages'),
            Tab(text: 'Profile'),
          ],
        ),
        centerTitle: true,
        // Right: Hamburger Menu for Creator Tools/Settings
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF111827), size: 28),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: TabBarView(
        controller: _mainTabController,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildMessagesTab(),
          _buildProfileTab(),
        ],
      ),
    );
  }

  // ==========================================
  // 1. MESSAGES TAB (CLEAN & MODERN)
  // ==========================================
  Widget _buildMessagesTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Messages', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            IconButton(icon: const Icon(Icons.drive_file_rename_outline_rounded, color: Color(0xFF111827)), onPressed: () {}),
          ],
        ),
        const SizedBox(height: 12),
        
        // Search Bar
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
              SizedBox(width: 8),
              Text('Search conversations', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Active Now
        const Text('Active now', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 12),
        SizedBox(
          height: 85,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildActiveUser('Maya', const Color(0xFFFECACA), Icons.wb_twilight_rounded),
              _buildActiveUser('Rohan', const Color(0xFFBFDBFE), Icons.auto_awesome_rounded),
              _buildActiveUser('Nia', const Color(0xFFFDE68A), Icons.graphic_eq_rounded),
              _buildActiveUser('Studio', const Color(0xFFE9D5FF), Icons.people_rounded),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        // Recent Chats
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent chats', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            Text('4', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        _buildChatTile('Maya Chen', 'Your latest edit is beautiful.', '9:42 AM', 3, const Color(0xFFFECACA), Icons.wb_twilight_rounded),
        _buildChatTile('Rohan Mehta', 'I sent over the new storyboard.', 'Yesterday', 0, const Color(0xFFBFDBFE), Icons.auto_awesome_rounded),
        _buildChatTile('Nia Kapoor', 'Voice note · 0:18', 'Tue', 1, const Color(0xFFFDE68A), Icons.graphic_eq_rounded),
        _buildChatTile('Studio Circle', 'Arjun: Call time moved to 6 PM', 'Mon', 0, const Color(0xFFE9D5FF), Icons.people_rounded),
      ],
    );
  }

  Widget _buildActiveUser(String name, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(radius: 30, backgroundColor: color, child: Icon(icon, color: const Color(0xFF111827))),
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        ],
      ),
    );
  }

  Widget _buildChatTile(String name, String msg, String time, int unread, Color color, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 26, backgroundColor: color, child: Icon(icon, color: const Color(0xFF111827))),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827))),
      subtitle: Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread > 0 ? const Color(0xFF111827) : const Color(0xFF6B7280), fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          if (unread > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
              child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. PROFILE TAB (120FPS SMOOTH NESTED GRID)
  // ==========================================
  Widget _buildProfileTab() {
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, _) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    // Avatar & Stats Row
                    Row(
                      children: [
                        // Ring Light Avatar
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFE11D48), Color(0xFF9333EA)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const CircleAvatar(
                              radius: 38,
                              backgroundColor: Color(0xFFF3F4F6),
                              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Stats
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStat('145', 'Following'),
                              _buildStat('12.4K', 'Followers'),
                              _buildStat('2.1M', 'Likes'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Bio
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Rachit Kushwaha', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF111827))),
                    ),
                    const SizedBox(height: 2),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Digital Creator | Music & Tech 🚀\nWelcome to my creative space.', style: TextStyle(fontSize: 13.5, color: Color(0xFF4B5563), height: 1.3)),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: const [
                          Icon(Icons.link_rounded, size: 16, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text('youtube.com/ojas', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () {},
                            child: const Text('Edit Profile', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () {},
                            child: const Text('Share Profile', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            // Profile Media Tabs
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                const TabBar(
                  indicatorColor: Color(0xFF111827),
                  indicatorWeight: 2,
                  labelColor: Color(0xFF111827),
                  unselectedLabelColor: Color(0xFF9CA3AF),
                  tabs: [
                    Tab(icon: Icon(Icons.grid_on_rounded)),
                    Tab(icon: Icon(Icons.favorite_border_rounded)),
                    Tab(icon: Icon(Icons.lock_outline_rounded)),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          physics: const BouncingScrollPhysics(),
          children: [
            _buildMediaGrid(),
            const Center(child: Text('Only you can see which videos you liked', style: TextStyle(color: Color(0xFF9CA3AF)))),
            const Center(child: Text('Private videos', style: TextStyle(color: Color(0xFF9CA3AF)))),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF111827))),
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      ],
    );
  }

  Widget _buildMediaGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 0.75,
      ),
      itemCount: 15,
      itemBuilder: (context, index) {
        return Container(
          color: const Color(0xFFF3F4F6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Center(child: Icon(Icons.image_rounded, color: Color(0xFFD1D5DB), size: 32)),
              Positioned(
                bottom: 4, left: 6,
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 16),
                    Text('${(index + 1) * 12}K', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

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
