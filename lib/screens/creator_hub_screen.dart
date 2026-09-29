import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../creation/screens/creation_hub_screen.dart';
import '../models/reel_model.dart';
import '../models/shop_item_model.dart';

class CreatorHubScreen extends StatefulWidget {
  const CreatorHubScreen({super.key});

  @override
  State<CreatorHubScreen> createState() => _CreatorHubScreenState();
}

class _CreatorHubScreenState extends State<CreatorHubScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final TabController _tabs;

  bool _loading = true;
  bool _refreshing = false;
  bool _showsLoading = false;
  bool _shopLoading = false;
  bool _showsLoaded = false;
  bool _shopLoaded = false;
  String _displayName = 'OJAS Creator';
  String _ojasId = '';
  String _bio = '';
  String _photoUrl = '';
  bool _isVerified = false;
  int _followers = 0;
  int _following = 0;
  int _likes = 0;

  List<ReelModel> _shows = const <ReelModel>[];
  List<ShopItemModel> _shopItems = const <ShopItemModel>[];

  User? get _user => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_handleTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabs.removeListener(_handleTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _user;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final snapshot =
          await _firestore.collection('publicProfiles').doc(user.uid).get();
      final profileData = snapshot.data() ?? const <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _displayName = profileData['displayName'] as String? ??
            user.displayName ??
            'OJAS Creator';
        _ojasId = profileData['ojasId'] as String? ?? '';
        _bio = profileData['bio'] as String? ?? '';
        _photoUrl = profileData['photoUrl'] as String? ?? '';
        _isVerified = profileData['isVerified'] == true;
        _followers = _intValue(profileData['followersCount']);
        _following = _intValue(profileData['followingCount']);
        _likes = _intValue(profileData['likesCount']);
        _loading = false;
      });
    } catch (error) {
      debugPrint('OJAS creator hub load failed: $error');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creator Studio data could not be loaded.')),
      );
    }
  }

  void _handleTabChanged() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index == 1 && !_showsLoaded) _loadShows();
    if (_tabs.index == 2 && !_shopLoaded) _loadShopItems();
  }

  Future<void> _loadShows() async {
    final user = _user;
    if (user == null || _showsLoading) return;
    setState(() => _showsLoading = true);
    try {
      final snapshot = await _firestore
          .collection('reels')
          .where('creatorId', isEqualTo: user.uid)
          .limit(24)
          .get();
      final visibleDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['deletedAt'] == null &&
            data['moderationStatus'] != 'deleted';
      });
      final shows = visibleDocs
          .map(ReelModel.fromFirestore)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _shows = shows;
        _showsLoaded = true;
        _showsLoading = false;
      });
    } catch (error) {
      debugPrint('OJAS creator Show library load failed: $error');
      if (mounted) setState(() => _showsLoading = false);
    }
  }

  Future<void> _loadShopItems() async {
    final user = _user;
    if (user == null || _shopLoading) return;
    setState(() => _shopLoading = true);
    try {
      final snapshot = await _firestore
          .collection('shopItems')
          .where('creatorId', isEqualTo: user.uid)
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
      debugPrint('OJAS creator store load failed: $error');
      if (mounted) setState(() => _shopLoading = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _load();
    if (_showsLoaded) await _loadShows();
    if (_shopLoaded) await _loadShopItems();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CreationHubScreen(),
      ),
    );
    await _refresh();
  }

  String _compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  static int _intValue(dynamic value) => value is num ? value.toInt() : 0;

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Creator Studio',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: const Center(
          child: Text(
            'Sign in to open Creator Studio.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Creator Studio',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            TabBar(
              controller: _tabs,
              labelColor: const Color(0xFF111827),
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: const Color(0xFF111827),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Shows'),
                Tab(text: 'Store'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildOverview(),
                  _buildShows(),
                  _buildStore(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final initial = _displayName.isEmpty
        ? 'O'
        : _displayName.substring(0, 1).toUpperCase();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage:
                _photoUrl.isEmpty ? null : NetworkImage(_photoUrl),
            child: _photoUrl.isEmpty
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (_isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                    ],
                  ],
                ),
                if (_ojasId.isNotEmpty)
                  Text(
                    '@$_ojasId',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                if (_bio.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(
            children: [
              Expanded(child: _metricCard('Followers', _compact(_followers))),
              const SizedBox(width: 10),
              Expanded(child: _metricCard('Following', _compact(_following))),
              const SizedBox(width: 10),
              Expanded(child: _metricCard('Likes', _compact(_likes))),
            ],
          ),
          const SizedBox(height: 14),
          _actionCard(
            icon: Icons.add_circle_outline_rounded,
            title: 'Create a new Show',
            subtitle: 'Camera or Gallery → Editor → Publish',
            onTap: _openCreate,
          ),
          const SizedBox(height: 10),
          _actionCard(
            icon: Icons.video_library_outlined,
            title: 'Published Shows',
            subtitle:
                '$_shows.length loaded from your creator library',
            onTap: () => _tabs.animateTo(1),
          ),
          const SizedBox(height: 10),
          _actionCard(
            icon: Icons.storefront_outlined,
            title: 'Creator Store',
            subtitle: _shopItems.length.toString() + ' active items',
            onTap: () => _tabs.animateTo(2),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data & cost posture',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 7),
                Text(
                  'Creator Studio reads bounded profile, Show and store datasets only when opened or refreshed. Media stays on the existing device-first pipeline.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF111827)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShows() {
    if (_loading || _showsLoading) return const Center(child: CircularProgressIndicator());
    if (_shows.isEmpty) {
      return _emptyTab(
        icon: Icons.play_circle_outline_rounded,
        title: 'No Shows yet',
        subtitle: 'Create your first Show from Creator Studio.',
        onTap: _openCreate,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
          childAspectRatio: 9 / 13,
        ),
        itemCount: _shows.length,
        itemBuilder: (context, index) {
          final show = _shows[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                show.thumbnailUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFE5E7EB),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFF6B7280),
                        ),
                      )
                    : Image.network(
                        show.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFE5E7EB),
                        ),
                      ),
                Positioned(
                  left: 5,
                  bottom: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      child: Text(
                        _compact(show.views),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStore() {
    if (_loading || _shopLoading) return const Center(child: CircularProgressIndicator());
    if (_shopItems.isEmpty) {
      return _emptyTab(
        icon: Icons.storefront_outlined,
        title: 'No active store items',
        subtitle: 'Your active creator products will appear here.',
        onTap: () {},
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        itemCount: _shopItems.length,
        itemBuilder: (context, index) {
          final item = _shopItems[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: item.imageUrl.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: Color(0xFF6B7280),
                            size: 32,
                          ),
                        )
                      : Image.network(
                          item.imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: Color(0xFF6B7280),
                              size: 32,
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyTab({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFFD1D5DB)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onTap,
              child: const Text('Open Creator Studio'),
            ),
          ],
        ),
      ),
    );
  }
}
