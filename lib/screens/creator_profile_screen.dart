import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  }) : creatorId = creatorId ?? '',
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
  bool _followUpdating = false;
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
      if (mounted) setState(() => _profileLoading = false);
      return;
    }

    try {
      final profileRef =
          _firestore.collection('publicProfiles').doc(widget.creatorId);
      final snapshot = await profileRef.get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      final currentUser = _auth.currentUser;
      Map<String, dynamic> currentData = const <String, dynamic>{};

      if (currentUser != null) {
        final currentSnapshot = await _firestore
            .collection('publicProfiles')
            .doc(currentUser.uid)
            .get();
        currentData = currentSnapshot.data() ?? const <String, dynamic>{};
      }

      if (!mounted) return;
      final followingIds = _stringList(currentData['following']);
      setState(() {
        _bio = data['bio'] as String? ?? '';
        _photoUrl = data['photoUrl'] as String? ?? '';
        _followers = (data['followersCount'] as num?)?.toInt() ?? _followers;
        _following = (data['followingCount'] as num?)?.toInt() ?? _following;
        _likes = (data['likesCount'] as num?)?.toInt() ?? _likes;
        if (currentUser != null) {
          _isFollowing = followingIds.contains(widget.creatorId);
        }
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

  Future<void> _toggleFollow() async {
    if (_followUpdating || widget.creatorId.isEmpty) return;
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == widget.creatorId) return;

    final next = !_isFollowing;
    final previousFollowers = _followers;
    final previousFollowing = _following;
    setState(() {
      _followUpdating = true;
      _isFollowing = next;
      _followers = (_followers + (next ? 1 : -1)).clamp(0, 1 << 31);
    });

    try {
      await _engagementService.setFollowState(
        creatorId: widget.creatorId,
        following: next,
      );
      if (!mounted) return;
      widget.onFollowChanged?.call(next);
      setState(() => _followUpdating = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _followUpdating = false;
        _isFollowing = !next;
        _followers = previousFollowers;
        _following = previousFollowing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update follow status.')),
      );
      debugPrint('OJAS creator follow update failed: $error');
    }
  }

  Future<void> _showSocialList(String type) async {
    if (widget.creatorId.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF171B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _SocialListSheet(
        profileId: widget.creatorId,
        type: type,
        currentUserId: _auth.currentUser?.uid,
        engagementService: _engagementService,
      ),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
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
                Tab(icon: Icon(Icons.grid_on_rounded, size: 20), text: 'Reels'),
                Tab(
                  icon: Icon(Icons.storefront_rounded, size: 20),
                  text: 'Store',
                ),
                Tab(icon: Icon(Icons.lock_rounded, size: 19), text: 'Premium'),
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
                        GestureDetector(
                          onTap: () => _showSocialList('followers'),
                          behavior: HitTestBehavior.opaque,
                          child: _Stat(
                            label: 'Followers',
                            value: _compactNumber(_followers),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showSocialList('following'),
                          behavior: HitTestBehavior.opaque,
                          child: _Stat(
                            label: 'Following',
                            value: _compactNumber(_following),
                          ),
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
                    style: const TextStyle(color: Colors.white70, height: 1.35),
                  ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: widget.creatorId.isEmpty || _followUpdating
                  ? null
                  : _toggleFollow,
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
              child: _followUpdating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
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
    if (_reelsLoading && !_reelsLoaded) return const _GridLoader();
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
        return _ReelTile(thumbnailUrl: reel.thumbnailUrl, views: reel.views);
      },
    );
  }

  Widget _buildShopGrid() {
    if (_shopLoading && !_shopLoaded) return const _GridLoader();
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
      itemBuilder: (context, index) => _ShopTile(item: _shopItems[index]),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
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
      ),
    );
  }
}

class _SocialListSheet extends StatefulWidget {
  const _SocialListSheet({
    required this.profileId,
    required this.type,
    required this.currentUserId,
    required this.engagementService,
  });

  final String profileId;
  final String type;
  final String? currentUserId;
  final EngagementService engagementService;

  @override
  State<_SocialListSheet> createState() => _SocialListSheetState();
}

class _SocialListSheetState extends State<_SocialListSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _profiles = const <Map<String, dynamic>>[];
  Set<String> _followingIds = <String>{};
  final Set<String> _updatingIds = <String>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<String> _asStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snapshot = await _firestore
          .collection('publicProfiles')
          .doc(widget.profileId)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      final ids = _asStringList(
        widget.type == 'followers' ? data['followers'] : data['following'],
      );

      if (widget.currentUserId != null) {
        final currentSnapshot = await _firestore
            .collection('publicProfiles')
            .doc(widget.currentUserId)
            .get();
        final currentData = currentSnapshot.data() ?? const <String, dynamic>{};
        _followingIds = _asStringList(currentData['following']).toSet();
      }

      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() {
          _profiles = const <Map<String, dynamic>>[];
          _loading = false;
        });
        return;
      }

      final docs = <Map<String, dynamic>>[];
      for (var start = 0; start < ids.length; start += 30) {
        final chunk = ids.sublist(
          start,
          start + 30 > ids.length ? ids.length : start + 30,
        );
        final profileSnapshot = await _firestore
            .collection('publicProfiles')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        docs.addAll(
          profileSnapshot.docs.map((doc) {
            final profile = doc.data();
            return <String, dynamic>{
              'uid': doc.id,
              'ojasId': profile['ojasId'] is String
                  ? profile['ojasId'] as String
                  : '',
              'displayName': profile['displayName'] is String
                  ? profile['displayName'] as String
                  : '',
              'photoUrl': profile['photoUrl'] is String
                  ? profile['photoUrl'] as String
                  : '',
            };
          }),
        );
      }

      final order = <String, int>{};
      for (var i = 0; i < ids.length; i++) {
        order[ids[i]] = i;
      }
      docs.sort(
        (a, b) => (order[a['uid']] ?? 999999).compareTo(
          order[b['uid']] ?? 999999,
        ),
      );

      if (!mounted) return;
      setState(() {
        _profiles = docs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load this list.';
      });
      debugPrint('OJAS social list load failed: $error');
    }
  }

  Future<void> _toggleListedUser(String userId, String name) async {
    final currentUserId = widget.currentUserId;
    if (currentUserId == null ||
        currentUserId.isEmpty ||
        currentUserId == userId ||
        _updatingIds.contains(userId)) {
      return;
    }

    final next = !_followingIds.contains(userId);
    setState(() {
      _updatingIds.add(userId);
      if (next) {
        _followingIds.add(userId);
      } else {
        _followingIds.remove(userId);
      }
    });

    try {
      await widget.engagementService.setFollowState(
        creatorId: userId,
        following: next,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (next) {
          _followingIds.remove(userId);
        } else {
          _followingIds.add(userId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update @$name.')),
      );
      debugPrint('OJAS social list follow update failed: $error');
    } finally {
      if (mounted) setState(() => _updatingIds.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'followers' ? 'Followers' : 'Following';

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  : _profiles.isEmpty
                  ? Center(
                      child: Text(
                        'No $title yet.',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      itemCount: _profiles.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final profile = _profiles[index];
                        final uid = profile['uid'] as String? ?? '';
                        final ojasId = profile['ojasId'] as String? ?? '';
                        final displayName = profile['displayName'] as String? ?? '';
                        final photoUrl = profile['photoUrl'] as String? ?? '';
                        final name = ojasId.isNotEmpty
                            ? ojasId
                            : (displayName.isNotEmpty ? displayName : 'OJAS user');
                        final isSelf = uid == widget.currentUserId;
                        final following = _followingIds.contains(uid);
                        final updating = _updatingIds.contains(uid);

                        return ListTile(
                          leading: _SocialAvatar(url: photoUrl, label: name),
                          title: Text(
                            '@$name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: displayName.isNotEmpty && displayName != name
                              ? Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white54),
                                )
                              : null,
                          trailing: isSelf || widget.currentUserId == null
                              ? null
                              : SizedBox(
                                  width: 92,
                                  height: 34,
                                  child: ElevatedButton(
                                    onPressed: updating
                                        ? null
                                        : () => _toggleListedUser(uid, name),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: following
                                          ? const Color(0xFF242933)
                                          : const Color(0xFFF5B942),
                                      foregroundColor: following
                                          ? Colors.white
                                          : Colors.black,
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: updating
                                        ? const SizedBox.square(
                                            dimension: 15,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            following ? 'Unfollow' : 'Follow',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialAvatar extends StatelessWidget {
  const _SocialAvatar({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final initial = label.isEmpty ? 'O' : label.substring(0, 1).toUpperCase();
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFF242933),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF242933),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
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
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF171B22)),
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
