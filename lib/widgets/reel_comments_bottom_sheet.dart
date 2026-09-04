import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReelCommentsBottomSheet extends StatefulWidget {
  const ReelCommentsBottomSheet({super.key, required this.reelId});

  final String reelId;

  static Future<void> show(BuildContext context, {required String reelId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => ReelCommentsBottomSheet(reelId: reelId),
    );
  }

  @override
  State<ReelCommentsBottomSheet> createState() =>
      _ReelCommentsBottomSheetState();
}

class _ReelCommentsBottomSheetState extends State<ReelCommentsBottomSheet> {
  static const int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _comments = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasMore = true;
  bool _loading = false;

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      FirebaseFirestore.instance
          .collection('reels')
          .doc(widget.reelId)
          .collection('comments');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || !_hasMore) return;
    if (_scrollController.position.extentAfter < 320) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      Query<Map<String, dynamic>> query = _commentsRef
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (_cursor != null) query = query.startAfterDocument(_cursor!);
      final snapshot = await query.get();
      if (!mounted) return;
      setState(() {
        _comments.addAll(snapshot.docs);
        _cursor = snapshot.docs.isEmpty ? _cursor : snapshot.docs.last;
        _hasMore = snapshot.docs.length == _pageSize;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('OJAS comments load failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.68,
        decoration: const BoxDecoration(
          color: Color(0xFF13171D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
              child: Row(
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: _comments.isEmpty && _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    )
                  : _comments.isEmpty
                  ? const Center(
                      child: Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _comments.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _comments.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                          );
                        }
                        final data = _comments[index].data();
                        final name = data['userName'] as String? ?? 'OJAS User';
                        final text = data['text'] as String? ?? '';
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF222831),
                            child: Text(
                              name.isEmpty ? 'U' : name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
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
