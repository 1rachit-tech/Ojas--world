import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/social_interaction.dart';
import '../services/social_interaction_service.dart';

class HomeCommentsSheet extends StatefulWidget {
  const HomeCommentsSheet({
    super.key,
    required this.postId,
    this.creatorName = '',
    this.initialComments = const <String>[],
    this.onCommentsUpdated,
  });

  final String postId;
  final String creatorName;
  final List<String> initialComments;
  final void Function(int updatedCount)? onCommentsUpdated;

  static Future<void> show(
    BuildContext context, {
    required String postId,
    String creatorName = '',
    List<String> initialComments = const <String>[],
    void Function(int updatedCount)? onCommentsUpdated,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HomeCommentsSheet(
        postId: postId,
        creatorName: creatorName,
        initialComments: initialComments,
        onCommentsUpdated: onCommentsUpdated,
      ),
    );
  }

  @override
  State<HomeCommentsSheet> createState() => _HomeCommentsSheetState();
}

class _HomeCommentsSheetState extends State<HomeCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _sending = false;
  String? _error;
  SocialComment? _replyingTo;
  SocialComment? _editing;
  CommentSort _sort = CommentSort.newest;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (_editing != null) {
        await SocialInteractionService.instance.editComment(
          contentId: widget.postId,
          commentId: _editing!.id,
          text: text,
        );
        if (mounted) setState(() => _editing = null);
      } else {
        await SocialInteractionService.instance.postComment(
          contentId: widget.postId,
          text: text,
          parentCommentId: _replyingTo?.id,
          rootCommentId: _replyingTo?.rootCommentId ?? _replyingTo?.id,
        );
        if (mounted) setState(() => _replyingTo = null);
      }
      _controller.clear();
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(SocialComment c) async {
    HapticFeedback.selectionClick();
    try {
      await SocialInteractionService.instance.setCommentLike(
        contentId: widget.postId,
        commentId: c.id,
        liked: !c.likedByMe,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _delete(SocialComment comment) async {
    try {
      await SocialInteractionService.instance.deleteComment(
        contentId: widget.postId,
        commentId: comment.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _startEdit(SocialComment c) {
    setState(() {
      _editing = c;
      _replyingTo = null;
      _controller.text = c.text;
    });
    _focus.requestFocus();
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final d = DateTime.now().toUtc().difference(dt.toUtc());
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  _SortChip(
                    label: 'Newest',
                    selected: _sort == CommentSort.newest,
                    onTap: () => setState(() => _sort = CommentSort.newest),
                  ),
                  const SizedBox(width: 6),
                  _SortChip(
                    label: 'Top',
                    selected: _sort == CommentSort.top,
                    onTap: () => setState(() => _sort = CommentSort.top),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                ),
              ),
            Expanded(
              child: StreamBuilder<List<SocialComment>>(
                stream: SocialInteractionService.instance.watchComments(
                  widget.postId,
                  sort: _sort,
                ),
                builder: (context, snapshot) {
                  final comments = snapshot.data ?? const <SocialComment>[];
                  final cb = widget.onCommentsUpdated;
                  if (cb != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      cb(comments.length);
                    });
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      comments.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (comments.isEmpty) {
                    return const Center(
                      child: Text(
                        'Be the first to comment',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final c = comments[index];
                      final isMine = uid != null && c.authorId == uid;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF111827),
                          child: Text(
                            c.authorName.isNotEmpty
                                ? c.authorName[0].toUpperCase()
                                : 'O',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _timeAgo(c.createdAt),
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 11,
                              ),
                            ),
                            if (c.isEdited)
                              const Text(
                                ' · edited',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.text,
                                style: const TextStyle(
                                  color: Color(0xFF374151),
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleLike(c),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          c.likedByMe
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          size: 14,
                                          color: c.likedByMe
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF9CA3AF),
                                        ),
                                        if (c.likeCount > 0) ...[
                                          const SizedBox(width: 3),
                                          Text(
                                            '${c.likeCount}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _replyingTo = c;
                                        _editing = null;
                                      });
                                      _focus.requestFocus();
                                    },
                                    child: const Text(
                                      'Reply',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                  if (isMine) ...[
                                    const SizedBox(width: 14),
                                    GestureDetector(
                                      onTap: () => _startEdit(c),
                                      child: const Text(
                                        'Edit',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () => _delete(c),
                                      child: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_replyingTo != null || _editing != null)
              Container(
                width: double.infinity,
                color: const Color(0xFFF3F4F6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _editing != null
                            ? 'Editing comment'
                            : 'Replying to ${_replyingTo!.authorName}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _replyingTo = null;
                        _editing = null;
                        _controller.clear();
                      }),
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        maxLength: 1000,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Add a comment…  @mention',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Color(0xFF111827),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
