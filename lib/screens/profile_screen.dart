import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ojs_video.dart';

class ProfileScreen extends StatefulWidget {
  final String userName;

  const ProfileScreen({super.key, this.userName = 'creator_ojas'});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 🚀 100% Minimalist Pure White
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '@${widget.userName}',
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF111827)),
            onPressed: () {
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Profile Avatar
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF111827), width: 1.5),
                    ),
                    child: const CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFFF3F4F6),
                      child: Text(
                        'O',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Name & Verified Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'OJAS Creator',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Building culture & pure frames. ⚡ Satna, MP',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats Row (Following, Followers, Likes)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatColumn('Following', '240'),
                      _buildStatDivider(),
                      _buildStatColumn('Followers', '48.2K'),
                      _buildStatDivider(),
                      _buildStatColumn('Likes', '320K'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Edit Profile Button
                  SizedBox(
                    width: 160,
                    height: 38,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF111827),
                        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                      },
                      child: const Text(
                        'Edit Profile',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF111827),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF111827),
                unselectedLabelColor: const Color(0xFF9CA3AF),
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on_rounded, size: 20)),
                  Tab(icon: Icon(Icons.bookmark_outline_rounded, size: 22)),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildVideoGrid(temporaryOjsVideos),
            _buildVideoGrid(temporaryOjsVideos.reversed.toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 18,
      color: const Color(0xFFE5E7EB),
    );
  }

  Widget _buildVideoGrid(List<OjsVideo> videos) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return Container(
          color: const Color(0xFFF3F4F6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Center(
                child: Icon(Icons.play_arrow_rounded, color: Color(0xFF9CA3AF), size: 30),
              ),
              Positioned(
                bottom: 6,
                left: 6,
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow_outlined, color: Color(0xFF4B5563), size: 14),
                    const SizedBox(width: 2),
                    Text(
                      '${video.likes}',
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
