import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/reel_model.dart';
import '../models/shop_item_model.dart';
import '../services/engagement_service.dart';

class CreatorProfileScreen extends StatefulWidget {
  const CreatorProfileScreen({
    super.key,
    String? creatorId,
    String? username,
    String? creatorName,
    this.avatarColor = const Color(0xFFE5E7EB),
    this.isFollowing = false,
    this.initialFollowers = 0,
    this.initialFollowing = 0,
    this.initialLikes = 0,
    this.onFollowChanged,
  })  : creatorId = creatorId ?? '',
        username = username ?? creatorName ?? 'OJAS Creator';

  final String creatorId;
  final String username;
  final Color avatarColor;
  final bool isFollowing;
  final int initialFollowers;
  final int initialFollowing;
  final int initialLikes;
  final ValueChanged<bool>? onFollowChanged;

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EngagementService _engagementService = EngagementService();

  late final TabController _tabController;
  late bool _isFollowing;
  late int _followers;
  int _following = 0;
  int _likes = 0;
  String _bio = '';
  String _photoUrl = '';
  bool _profileLoading = true;
  bool _reelsLoading = false;
  bool _shopLoading = false;
  bool _reelsLoaded = false;
  bool _shopLoaded = false;
  List<ReelModel> _reels = const <ReelModel>[];
  List<ShopItemModel> _shopItems = const <ShopItemModel>[];

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
    _followers = widget.initialFollowers;
    _following = widget.initialFollowing;
    _likes = widget.initialLikes;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0 && !_reelsLoaded) {
      _loadReels();
    }
    if (_tabController.index == 1 && !_shopLoaded) {
      _loadShopItems();
    }
  }

  Future<void> _loadProfile() async {
    if (widget.creatorId.isEmpty) {
      if (mounted) {
        setState(() => _profileLoading = false);
      }
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(widget.creatorId)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _bio = data['bio'] as String? ?? '';
        _photoUrl = data['photoUrl'] as String? ??
            data['profileImageUrl'] as String? ??
            '';
        _followers = (data['followersCount'] as num?)?.toInt() ?? _followers;
        _following = (data['followingCount'] as num?)?.toInt() ?? _following;
        _likes = (data['likesCount'] as num?)?.toInt() ?? _likes;
        _profileLoading = false;
      });
      _loadReels();
    } catch (error) {
      if (!mounted) return;
      setState(() => _profileLoading = false);
      debugPrint('OJAS creator profile load failed: $error');
    }
  }

  Future<void> _loadReels() async {
    if (widget.creatorId.isEmpty || _reelsLoading || _reelsLoaded) return;
    setState(() => _reelsLoading = true);
    try {
      final snapshot = await _firestore
          .collection('reels')
          .where('creatorId', isEqualTo: widget.creatorId)
          .limit(24)
          .get();
      final reels = snapshot.docs
          .map(ReelModel.fromFirestore)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _reels = reels;
        _reelsLoaded = true;
        _reelsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _reelsLoading = false);
      debugPrint('OJAS creator reels load failed: $error');
    }
  }

  Future<void> _loadShopItems() async {
    if (widget.creatorId.isEmpty || _shopLoading || _shopLoaded) return;
    setState(() => _shopLoading = true);
    try {
      final snapshot = await _firestore
          .collection('shopItems')
          .where('creatorId', isEqualTo: widget.creatorId)
          .limit(24)
          .get();
      final items = snapshot.docs
          .map(ShopItemModel.fromFirestore)
          .where((item) => item.active)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _shopItems = items;
        _shopLoaded = true;
        _shopLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _shopLoading = false);
      debugPrint('OJAS creator shop load failed: $error');
    }
  }

  void _toggleFollow() {
    final next = !_isFollowing;
    setState(() {
      _isFollowing = next;
      _followers = (_followers + (next ? 1 : -1)).clamp(0, 1 << 31);
    });
    widget.onFollowChanged?.call(next);
    _engagementService.syncFollow(
      creatorId: widget.creatorId,
      following: next,
    );
  }

  String _compactNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '@${widget.username}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFF5B942),
              indicatorWeight: 2.5,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(
                  icon: Icon(Icons.grid_on_rounded, size: 20),
                  text: 'Reels',
                ),
                Tab(
                  icon: Icon(Icons.storefront_rounded, size: 20),
                  text: 'Store',
                ),
                Tab(
                  icon: Icon(Icons.lock_rounded, size: 19),
                  text: 'Premium',
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildReelsGrid(),
                  _buildShopGrid(),
                  _buildPremiumGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${widget.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Stat(
                          label: 'Followers',
                          value: _compactNumber(_followers),
                        ),
                        _Stat(
                          label: 'Following',
                          value: _compactNumber(_following),
                        ),
                        _Stat(label: 'Likes', value: _compactNumber(_likes)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _profileLoading
                ? const SizedBox(
                    width: 120,
                    height: 14,
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : Text(
                    _bio.isEmpty ? 'Creator on OJAS ✨' : _bio,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: widget.creatorId.isEmpty ? null : _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFollowing
                    ? const Color(0xFF242933)
                    : const Color(0xFFF5B942),
                foregroundColor: _isFollowing ? Colors.white : Colors.black,
                disabledBackgroundColor: const Color(0xFF242933),
                disabledForegroundColor: Colors.white38,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isFollowing ? 'Unfollow' : 'Follow',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final fallback = widget.username.isEmpty
        ? 'U'
        : widget.username[0].toUpperCase();
    return Container(
      width: 82,
      height: 82,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF5B942), width: 2),
      ),
      child: ClipOval(
        child: _photoUrl.isEmpty
            ? Container(
                color: widget.avatarColor.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: Text(
                  fallback,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Image.network(
                _photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: widget.avatarColor.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: Text(
                    fallback,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildReelsGrid() {
    if (_reelsLoading && !_reelsLoaded) {
      return const _GridLoader();
    }
    if (_reels.isEmpty) {
      return const _EmptyState(
        icon: Icons.video_library_outlined,
        text: 'No reels yet',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 13,
      ),
      itemCount: _reels.length,
      itemBuilder: (context, index) {
        final reel = _reels[index];
        return _ReelTile(
          thumbnailUrl: reel.thumbnailUrl,
          views: reel.views,
        );
      },
    );
  }

  Widget _buildShopGrid() {
    if (_shopLoading && !_shopLoaded) {
      return const _GridLoader();
    }
    if (_shopItems.isEmpty) {
      return const _EmptyState(
        icon: Icons.storefront_outlined,
        text: 'Storefront is empty',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: _shopItems.length,
      itemBuilder: (context, index) {
        return _ShopTile(item: _shopItems[index]);
      },
    );
  }

  Widget _buildPremiumGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 0.84,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF171B22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, color: Color(0xFFF5B942), size: 25),
              SizedBox(height: 6),
              Text(
                'Premium',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _ReelTile extends StatelessWidget {
  const _ReelTile({required this.thumbnailUrl, required this.views});

  final String thumbnailUrl;
  final int views;

  String _viewsLabel() {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    }
    if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return '$views';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        thumbnailUrl.isEmpty
            ? const ColoredBox(
                color: Color(0xFF171B22),
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.white38,
                  size: 30,
                ),
              )
            : Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFF171B22),
                ),
              ),
        Positioned(
          left: 6,
          bottom: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                _viewsLabel(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.item});

  final ShopItemModel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: item.imageUrl.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.shopping_bag_rounded,
                      color: Color(0xFFF5B942),
                      size: 32,
                    ),
                  )
                : Image.network(
                    item.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.shopping_bag_rounded,
                        color: Color(0xFFF5B942),
                        size: 32,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.currency} ${(item.priceMinor / 100).toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Color(0xFFF5B942),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridLoader extends StatelessWidget {
  const _GridLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFF5B942),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white24, size: 42),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
