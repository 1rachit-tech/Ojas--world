import 'package:flutter/material.dart';

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

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  bool _isFollowing = false;
  int _selectedGridTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '@${widget.creatorName.toLowerCase().replaceAll(' ', '_')}',
          style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF111827)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // 1. Top Section: Avatar (Left) + Stats (Right) - Exactly like OJAS Profile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: widget.avatarColor,
                    child: Text(
                      widget.creatorName.isNotEmpty ? widget.creatorName[0] : 'C',
                      style: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('320', 'Following'),
                        _buildStatColumn('48.5K', 'Followers'),
                        _buildStatColumn('1.8M', 'Likes'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. Name & Bio Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.creatorName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Visual Creator & Storyteller 🎬✨\nSharing cinematic frames & daily energy on OJAS.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.link_rounded, size: 16, color: Color(0xFF00376B)),
                      SizedBox(width: 4),
                      Text(
                        'youtube.com/ojas_creator',
                        style: TextStyle(fontSize: 14, color: Color(0xFF00376B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Action Buttons (Follow / Message / SuperThanks Support)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      onTap: () => setState(() => _isFollowing = !_isFollowing),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isFollowing ? const Color(0xFFEFEFEF) : const Color(0xFFF5B942),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: const Color(0xFF111827),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFEFEF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Message',
                        style: TextStyle(color: Color(0xFF111827), fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. Tabs
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  _buildGridTab(Icons.grid_view_rounded, 0),
                  _buildGridTab(Icons.favorite_border_rounded, 1),
                ],
              ),
            ),

            // 5. Creator's Videos Grid
            _buildPostsGrid(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
      ],
    );
  }

  Widget _buildGridTab(IconData icon, int index) {
    final isSelected = _selectedGridTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGridTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF111827) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Icon(icon, color: isSelected ? const Color(0xFF111827) : const Color(0xFF9CA3AF), size: 26),
        ),
      ),
    );
  }

  Widget _buildPostsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.8,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return Container(
          color: const Color(0xFFE5E7EB),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Icon(Icons.movie_creation_outlined, color: Colors.grey.withValues(alpha: 0.3), size: 36),
              Positioned(
                bottom: 8,
                left: 8,
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text('${(index + 2) * 15}K', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
