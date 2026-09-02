import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommentModel {
  final String id;
  final String userName;
  final String text;
  final String time;
  int likes;
  bool isLiked;
  final bool isSuperThanks;

  CommentModel({
    required this.id,
    required this.userName,
    required this.text,
    required this.time,
    required this.likes,
    this.isLiked = false,
    this.isSuperThanks = false,
  });
}

class CommentsBottomSheet {
  static void show(BuildContext context, {required String videoId}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const _CommentsSheetContent(),
      ),
    );
  }
}

class _CommentsSheetContent extends StatefulWidget {
  const _CommentsSheetContent();

  @override
  State<_CommentsSheetContent> createState() => _CommentsSheetContentState();
}

class _CommentsSheetContentState extends State<_CommentsSheetContent> {
  final TextEditingController _commentController = TextEditingController();
  final List<CommentModel> _comments = [
    CommentModel(
      id: 'c1',
      userName: 'Rahul Sharma',
      text: 'This frame and lighting is magical! 🌿✨',
      time: '2h',
      likes: 142,
    ),
    CommentModel(
      id: 'c2',
      userName: 'Sneha_09',
      text: 'Vindhya vibes are unmatched! 🔥',
      time: '4h',
      likes: 38,
      isSuperThanks: true,
    ),
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.selectionClick();
    setState(() {
      _comments.insert(
        0,
        CommentModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userName: 'You',
          text: text,
          time: 'Just now',
          likes: 0,
        ),
      );
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_comments.length} Comments',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: Color(0xFF6B7280), size: 22),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFF3F4F6), height: 1, thickness: 1),

          // Comments List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              itemCount: _comments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final comment = _comments[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: comment.isSuperThanks
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFF3F4F6),
                      child: Text(
                        comment.userName[0].toUpperCase(),
                        style: TextStyle(
                          color: comment.isSuperThanks ? Colors.white : const Color(0xFF111827),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                comment.userName,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                comment.time,
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 11,
                                ),
                              ),
                              if (comment.isSuperThanks) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Thanks',
                                    style: TextStyle(
                                      color: Color(0xFFB45309),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            comment.text,
                            style: const TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          comment.isLiked = !comment.isLiked;
                          comment.likes += comment.isLiked ? 1 : -1;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            comment.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: comment.isLiked ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                            size: 16,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${comment.likes}',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Color(0xFF111827), fontSize: 13.5),
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _addComment,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF111827),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
