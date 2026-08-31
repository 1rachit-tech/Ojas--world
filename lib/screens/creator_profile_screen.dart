import 'package:flutter/material.dart';
import '../widgets/share_bottom_sheet.dart';
import '../widgets/super_thanks_modal.dart';

class CreatorProfileScreen extends StatefulWidget {
  final String creatorName;
  final Color avatarColor;

  const CreatorProfileScreen({
    super.key,
    required this.creatorName,
    required this.avatarColor,
  });

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '@${widget.creatorName.toLowerCase().replaceAll(' ', '')}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
            onPressed: () {
              ShareBottomSheet.show(
                context,
                videoUrl: 'https://ojas.app/creator/${widget.creatorName}',
                creatorName: widget.creatorName,
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar & Stats Row (Instagram Style)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: widget.avatarColor,
                          child: Text(
                            widget.creatorName[0],
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn('142', 'Posts'),
                              _buildStatColumn('48.5K', 'Followers'),
                              _buildStatColumn('320', 'Following'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Name, Verified Badge & Bio
                    Row(
                      children: [
                        Text(widget.creatorName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: Color(0xFFF5B942), size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Cinematic Storyteller & Vindhya Audio Beats 🌿\nCreating daily moments on OJAS.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(Icons.link_rounded, color: Color(0xFFF5B942), size: 14),
                        SizedBox(width: 4),
                        Text('ojas.app/official_creator', style: TextStyle(color: Color(0xFFF5B942), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Follow & Super Thanks Action Row
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing ? const Color(0xFF21262D) : const Color(0xFFF5B942),
                                foregroundColor: _isFollowing ? Colors.white : Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => setState(() => _isFollowing = !_isFollowing),
                              child: Text(_isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 38,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFF5B942)),
                              foregroundColor: const Color(0xFFF5B942),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => SuperThanksModal.show(context, creatorName: widget.creatorName),
                            icon: const Icon(Icons.stars_rounded, size: 18),
                            label: const Text('Super Thanks', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFF5B942),
                  indicatorWeight: 2,
                  labelColor: const Color(0xFFF5B942),
                  unselectedLabelColor: Colors.white38,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on_rounded)),
                    Tab(icon: Icon(Icons.movie_filter_outlined)),
                    Tab(icon: Icon(Icons.bookmark_border_rounded)),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMediaGrid(),
            _buildMediaGrid(),
            _buildMediaGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildMediaGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return Container(
          color: const Color(0xFF161B22),
          child: const Center(
            child: Icon(Icons.play_arrow_rounded, color: Colors.white38, size: 28),
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
    return Container(color: const Color(0xFF0D1117), child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
