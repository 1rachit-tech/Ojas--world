import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/social_interaction.dart';
import '../services/social_interaction_service.dart';

/// Real comments for a content item (reel).
/// [postId] is the content/reel id (kept for existing call sites).
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
      await SocialInteractionService.instance.postComment(
        contentId: widget.postId,
        text: text,
        parentCommentId: _replyingTo?.id,
        rootCommentId: _replyingTo?.rootCommentId ?? _replyingTo?.id,
      );
      _controller.clear();
      if (mounted) setState(() => _replyingTo = null);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
                stream: SocialInteractionService.instance
                    .watchComments(widget.postId),
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
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final c = comments[index];
                      final isMine = uid != null && c.authorId == uid;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
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
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            c.text,
                            style: const TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() => _replyingTo = c);
                                _focus.requestFocus();
                              },
                              child: const Text(
                                'Reply',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            if (isMine)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Color(0xFF9CA3AF),
                                ),
                                onPressed: () => _delete(c),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_replyingTo != null)
              Container(
                width: double.infinity,
                color: const Color(0xFFF3F4F6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to ${_replyingTo!.authorName}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _replyingTo = null),
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
                          hintText: 'Add a comment…',
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
