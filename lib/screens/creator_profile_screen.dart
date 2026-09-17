import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/reel_model.dart';
import '../models/shop_item_model.dart';
import '../services/engagement_service.dart';
import '../services/reel_lifecycle_service.dart';

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
  final ReelLifecycleService _reelLifecycle = ReelLifecycleService();

  late final TabController _tabController;
  late bool _isFollowing;
  late int _followers;
  int _following = 0;
  int _likes = 0;
  String _bio = '';
  String _photoUrl = '';
  bool _profileLoading = true;
  bool _showsLoading = false;
  bool _shopLoading = false;
  bool _followUpdating = false;
  bool _showsLoaded = false;
  bool _shopLoaded = false;
  final Set<String> _busyShowIds = <String>{};
  List<ReelModel> _shows = const <ReelModel>[];
  List<ShopItemModel> _shopItems = const <ShopItemModel>[];
  Map<String, Map<String, dynamic>> _showMeta = <String, Map<String, dynamic>>{};

  bool get _isOwnProfile => _auth.currentUser?.uid == widget.creatorId;

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
    if (_tabController.index == 0 && !_showsLoaded) _loadShows();
    if (_tabController.index == 1 && !_shopLoaded) _loadShopItems();
  }

  Future<void> _loadProfile() async {
    if (widget.creatorId.isEmpty) {
      if (mounted) setState(() => _profileLoading = false);
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('publicProfiles')
          .doc(widget.creatorId)
          .get();
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
        if (currentUser != null) _isFollowing = followingIds.contains(widget.creatorId);
        _profileLoading = false;
      });
      _loadShows();
    } catch (error) {
      if (!mounted) return;
      setState(() => _profileLoading = false);
      debugPrint('OJAS creator profile load failed: $error');
    }
  }

  Future<void> _loadShows() async {
    if (widget.creatorId.isEmpty || _showsLoading) return;
    setState(() => _showsLoading = true);
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('reels')
          .where('creatorId', isEqualTo: widget.creatorId);
      if (!_isOwnProfile) {
        query = query.where('visibility', isEqualTo: 'public');
      }
      final snapshot = await query.limit(24).get();
      final visibleDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['deletedAt'] == null && data['moderationStatus'] != 'deleted';
      }).toList(growable: false);
      final meta = <String, Map<String, dynamic>>{
        for (final doc in visibleDocs) doc.id: Map<String, dynamic>.from(doc.data()),
      };
      final shows = visibleDocs
          .map(ReelModel.fromFirestore)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _shows = shows;
        _showMeta = meta;
        _showsLoaded = true;
        _showsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _showsLoading = false);
      debugPrint('OJAS creator shows load failed: $error');
    }
  }

  Future<void> _loadShopItems() async {
    if (widget.creatorId.isEmpty || _shopLoading) return;
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

  Future<void> _showShowActions(ReelModel show) async {
    if (_busyShowIds.contains(show.id)) return;
    final isOwner = _auth.currentUser?.uid == show.creatorId;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF171B22),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                show.caption.isEmpty ? 'OJAS Show' : show.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.white),
                title: const Text('Edit Show details', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete Show', style: TextStyle(color: Colors.redAccent)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            if (!isOwner)
              ListTile(
                leading: const Icon(Icons.repeat_rounded, color: Color(0xFFF5B942)),
                title: const Text('Request reuse', style: TextStyle(color: Colors.white)),
                subtitle: const Text('The creator controls whether reuse is allowed.', style: TextStyle(color: Colors.white54)),
                onTap: () => Navigator.pop(context, 'reuse'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'edit') await _editShow(show);
    if (choice == 'delete') await _deleteShow(show);
    if (choice == 'reuse') await _reuseShow(show);
  }

  Future<void> _editShow(ReelModel show) async {
    final meta = _showMeta[show.id] ?? const <String, dynamic>{};
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171B22),
      showDragHandle: true,
      builder: (_) => _EditShowSheet(
        initialCaption: show.caption,
        initialVisibility: (meta['visibility'] as String?) ?? 'public',
        initialAllowComments: meta['allowComments'] == true,
        initialRecommendationEligible: meta['recommendationEligible'] == true,
        initialReusePolicy: (meta['reusePolicy'] as String?) ?? 'allowed',
        onSave: (values) async {
          await _reelLifecycle.editPost(
            postId: show.id,
            caption: values.caption,
            visibility: values.visibility,
            allowComments: values.allowComments,
            recommendationEligible: values.recommendationEligible,
            reusePolicy: values.reusePolicy,
          );
        },
      ),
    );
    if (result == true) await _loadShowsFresh();
  }

  Future<void> _deleteShow(ReelModel show) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this Show?'),
        content: const Text('It will stop appearing publicly and its media cleanup will run in the background.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyShowIds.add(show.id));
    try {
      await _reelLifecycle.deletePost(show.id);
      if (!mounted) return;
      setState(() {
        _shows = _shows.where((item) => item.id != show.id).toList(growable: false);
        _showMeta.remove(show.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Show deleted. Media cleanup queued.')),
      );
    } on ReelLifecycleException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busyShowIds.remove(show.id));
    }
  }

  Future<void> _reuseShow(ReelModel show) async {
    setState(() => _busyShowIds.add(show.id));
    try {
      final requestId = await _reelLifecycle.requestReuse(show.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reuse request sent • ${requestId.substring(0, requestId.length > 8 ? 8 : requestId.length)}')),
      );
    } on ReelLifecycleException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busyShowIds.remove(show.id));
    }
  }

  Future<void> _loadShowsFresh() async {
    if (!mounted) return;
    setState(() {
      _showsLoaded = false;
      _showsLoading = false;
    });
    await _loadShows();
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }

  String _compactNumber(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
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
        title: Text('@${widget.username}', style: const TextStyle(fontWeight: FontWeight.w800)),
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
                Tab(icon: Icon(Icons.play_circle_outline_rounded, size: 20), text: 'Shows'),
                Tab(icon: Icon(Icons.storefront_rounded, size: 20), text: 'Store'),
                Tab(icon: Icon(Icons.lock_rounded, size: 19), text: 'Premium'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildShowsGrid(), _buildShopGrid(), _buildPremiumGrid()],
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
                    Text('@${widget.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 9),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(onTap: () => _showSocialList('followers'), child: _Stat(label: 'Followers', value: _compactNumber(_followers))),
                        GestureDetector(onTap: () => _showSocialList('following'), child: _Stat(label: 'Following', value: _compactNumber(_following))),
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
                ? const SizedBox(width: 120, height: 14, child: LinearProgressIndicator(minHeight: 2))
                : Text(_bio.isEmpty ? 'Creator on OJAS ✨' : _bio, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, height: 1.35)),
          ),
          if (!_isOwnProfile) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: widget.creatorId.isEmpty || _followUpdating ? null : _toggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? const Color(0xFF242933) : const Color(0xFFF5B942),
                  foregroundColor: _isFollowing ? Colors.white : Colors.black,
                  disabledBackgroundColor: const Color(0xFF242933),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _followUpdating
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isFollowing ? 'Unfollow' : 'Follow', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final fallback = widget.username.isEmpty ? 'U' : widget.username[0].toUpperCase();
    return Container(
      width: 82,
      height: 82,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFF5B942), width: 2)),
      child: ClipOval(
        child: _photoUrl.isEmpty
            ? Container(color: widget.avatarColor.withValues(alpha: 0.35), alignment: Alignment.center, child: Text(fallback, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)))
            : Image.network(_photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: widget.avatarColor.withValues(alpha: 0.35), alignment: Alignment.center, child: Text(fallback, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)))),
      ),
    );
  }

  Widget _buildShowsGrid() {
    if (_showsLoading && !_showsLoaded) return const _GridLoader();
    if (_shows.isEmpty) return const _EmptyState(icon: Icons.play_circle_outline_rounded, text: 'No Shows yet');
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2, childAspectRatio: 9 / 13),
      itemCount: _shows.length,
      itemBuilder: (context, index) {
        final show = _shows[index];
        final busy = _busyShowIds.contains(show.id);
        return _ShowTile(
          thumbnailUrl: show.thumbnailUrl,
          views: show.views,
          busy: busy,
          onMenu: () => _showShowActions(show),
        );
      },
    );
  }

  Widget _buildShopGrid() {
    if (_shopLoading && !_shopLoaded) return const _GridLoader();
    if (_shopItems.isEmpty) return const _EmptyState(icon: Icons.storefront_outlined, text: 'Storefront is empty');
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.82),
      itemCount: _shopItems.length,
      itemBuilder: (context, index) => _ShopTile(item: _shopItems[index]),
    );
  }

  Widget _buildPremiumGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 0.84),
      itemCount: 9,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(color: const Color(0xFF171B22), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_rounded, color: Color(0xFFF5B942), size: 25), SizedBox(height: 6), Text('Premium', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700))]),
      ),
    );
  }
}

class _EditShowValues {
  const _EditShowValues({required this.caption, required this.visibility, required this.allowComments, required this.recommendationEligible, required this.reusePolicy});
  final String caption;
  final String visibility;
  final bool allowComments;
  final bool recommendationEligible;
  final String reusePolicy;
}

class _EditShowSheet extends StatefulWidget {
  const _EditShowSheet({
    required this.initialCaption,
    required this.initialVisibility,
    required this.initialAllowComments,
    required this.initialRecommendationEligible,
    required this.initialReusePolicy,
    required this.onSave,
  });

  final String initialCaption;
  final String initialVisibility;
  final bool initialAllowComments;
  final bool initialRecommendationEligible;
  final String initialReusePolicy;
  final Future<void> Function(_EditShowValues values) onSave;

  @override
  State<_EditShowSheet> createState() => _EditShowSheetState();
}

class _EditShowSheetState extends State<_EditShowSheet> {
  late final TextEditingController _captionController;
  late String _visibility;
  late bool _allowComments;
  late bool _recommendationEligible;
  late bool _allowReuse;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption);
    _visibility = {'public', 'followers', 'only me'}.contains(widget.initialVisibility) ? widget.initialVisibility : 'public';
    _allowComments = widget.initialAllowComments;
    _recommendationEligible = widget.initialRecommendationEligible;
    _allowReuse = widget.initialReusePolicy != 'followers';
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_EditShowValues(
        caption: _captionController.text.trim(),
        visibility: _visibility,
        allowComments: _allowComments,
        recommendationEligible: _recommendationEligible,
        reusePolicy: _allowReuse ? 'public' : 'followers',
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is ReelLifecycleException ? error.message : 'Unable to save changes.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 8, 18, bottomInset + 18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Edit Show', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              maxLength: 2200,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'Caption', labelStyle: const TextStyle(color: Colors.white60), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)), focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFF5B942))), counterStyle: const TextStyle(color: Colors.white38)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _visibility,
              dropdownColor: const Color(0xFF242933),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Visibility', labelStyle: TextStyle(color: Colors.white60), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(value: 'followers', child: Text('Followers')),
                DropdownMenuItem(value: 'only me', child: Text('Only me')),
              ],
              onChanged: _saving ? null : (value) => setState(() => _visibility = value ?? 'public'),
            ),
            SwitchListTile(value: _allowComments, onChanged: _saving ? null : (value) => setState(() => _allowComments = value), title: const Text('Allow comments', style: TextStyle(color: Colors.white)), contentPadding: EdgeInsets.zero, activeColor: const Color(0xFFF5B942)),
            SwitchListTile(value: _recommendationEligible && _visibility == 'public', onChanged: _saving || _visibility != 'public' ? null : (value) => setState(() => _recommendationEligible = value), title: const Text('Recommend in feeds', style: TextStyle(color: Colors.white)), subtitle: const Text('Only public Shows can be recommended.', style: TextStyle(color: Colors.white54)), contentPadding: EdgeInsets.zero, activeColor: const Color(0xFFF5B942)),
            SwitchListTile(value: _allowReuse && _visibility == 'public', onChanged: _saving || _visibility != 'public' ? null : (value) => setState(() => _allowReuse = value), title: const Text('Allow reuse requests', style: TextStyle(color: Colors.white)), subtitle: const Text('Other creators can request to reuse this Show.', style: TextStyle(color: Colors.white54)), contentPadding: EdgeInsets.zero, activeColor: const Color(0xFFF5B942)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF5B942), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(children: [Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))]),
      );
}

class _ShowTile extends StatelessWidget {
  const _ShowTile({required this.thumbnailUrl, required this.views, required this.busy, required this.onMenu});
  final String thumbnailUrl;
  final int views;
  final bool busy;
  final VoidCallback onMenu;

  String _viewsLabel() {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return '$views';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        thumbnailUrl.isEmpty
            ? const ColoredBox(color: Color(0xFF171B22), child: Icon(Icons.play_circle_outline_rounded, color: Colors.white38, size: 30))
            : Image.network(thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF171B22))),
        Positioned(left: 6, bottom: 5, child: DecoratedBox(decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: Text(_viewsLabel(), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700))))),
        Positioned(
          right: 4,
          top: 4,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: busy
                ? const Padding(padding: EdgeInsets.all(9), child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : IconButton(icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20), tooltip: 'Show actions', padding: const EdgeInsets.all(8), constraints: const BoxConstraints(), onPressed: onMenu),
          ),
        ),
      ],
    );
  }
}

class _SocialListSheet extends StatefulWidget {
  const _SocialListSheet({required this.profileId, required this.type, required this.currentUserId, required this.engagementService});
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
  String? _error;
  List<Map<String, dynamic>> _profiles = const <Map<String, dynamic>>[];
  Set<String> _followingIds = <String>{};
  final Set<String> _updatingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<String> _asList(dynamic value) => value is List ? value.whereType<String>().toList(growable: false) : const <String>[];

  Future<void> _load() async {
    try {
      final snapshot = await _firestore.collection('publicProfiles').doc(widget.profileId).get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      final ids = _asList(widget.type == 'followers' ? data['followers'] : data['following']);
      if (widget.currentUserId != null) {
        final current = await _firestore.collection('publicProfiles').doc(widget.currentUserId).get();
        _followingIds = _asList((current.data() ?? const <String, dynamic>{})['following']).toSet();
      }
      final profiles = <Map<String, dynamic>>[];
      for (var start = 0; start < ids.length; start += 30) {
        final chunk = ids.sublist(start, start + 30 > ids.length ? ids.length : start + 30);
        final batch = await _firestore.collection('publicProfiles').where(FieldPath.documentId, whereIn: chunk).get();
        profiles.addAll(batch.docs.map((doc) {
          final p = doc.data();
          return <String, dynamic>{'uid': doc.id, 'ojasId': p['ojasId'] ?? '', 'displayName': p['displayName'] ?? '', 'photoUrl': p['photoUrl'] ?? ''};
        }));
      }
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
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

  Future<void> _toggleFollow(String userId, String name) async {
    if (widget.currentUserId == null || widget.currentUserId == userId || _updatingIds.contains(userId)) return;
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
      await widget.engagementService.setFollowState(creatorId: userId, following: next);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (next) {
          _followingIds.remove(userId);
        } else {
          _followingIds.add(userId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to update @$name.')));
    } finally {
      if (mounted) setState(() => _updatingIds.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'followers' ? 'Followers' : 'Following';
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white54)))
                : _profiles.isEmpty
                    ? Center(child: Text('No $title yet.', style: const TextStyle(color: Colors.white54)))
                    : Column(
                        children: [
                          Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 12), child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)))),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                              itemCount: _profiles.length,
                              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                              itemBuilder: (context, index) {
                                final profile = _profiles[index];
                                final uid = profile['uid'] as String? ?? '';
                                final name = (profile['ojasId'] as String?)?.isNotEmpty == true ? profile['ojasId'] as String : ((profile['displayName'] as String?)?.isNotEmpty == true ? profile['displayName'] as String : 'OJAS user');
                                final photo = profile['photoUrl'] as String? ?? '';
                                final isSelf = uid == widget.currentUserId;
                                final following = _followingIds.contains(uid);
                                final updating = _updatingIds.contains(uid);
                                return ListTile(
                                  leading: CircleAvatar(backgroundColor: const Color(0xFF242933), backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, child: photo.isEmpty ? Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)) : null),
                                  title: Text('@$name', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  trailing: isSelf || widget.currentUserId == null ? null : SizedBox(width: 92, height: 34, child: ElevatedButton(onPressed: updating ? null : () => _toggleFollow(uid, name), style: ElevatedButton.styleFrom(backgroundColor: following ? const Color(0xFF242933) : const Color(0xFFF5B942), foregroundColor: following ? Colors.white : Colors.black, elevation: 0, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: updating ? const SizedBox.square(dimension: 15, child: CircularProgressIndicator(strokeWidth: 2)) : Text(following ? 'Unfollow' : 'Follow', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)))),
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

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.item});
  final ShopItemModel item;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF171B22), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: item.imageUrl.isEmpty ? const Center(child: Icon(Icons.shopping_bag_rounded, color: Color(0xFFF5B942), size: 32)) : Image.network(item.imageUrl, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.shopping_bag_rounded, color: Color(0xFFF5B942), size: 32)))),
          Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('${item.currency} ${(item.priceMinor / 100).toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFF5B942), fontSize: 12, fontWeight: FontWeight.w800))])),
        ],
      ),
    );
  }
}

class _GridLoader extends StatelessWidget {
  const _GridLoader();
  @override
  Widget build(BuildContext context) => const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF5B942))));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white24, size: 42), const SizedBox(height: 10), Text(text, style: const TextStyle(color: Colors.white54))]));
}
