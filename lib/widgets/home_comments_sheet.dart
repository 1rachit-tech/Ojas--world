import 'package:flutter/material.dart';

class HomeCommentsSheet extends StatefulWidget {
  final String postId;
  final String creatorName;
  final List<String> initialComments;
  final Function(int updatedCount) onCommentsUpdated;

  const HomeCommentsSheet({
    super.key,
    required this.postId,
    required this.creatorName,
    required this.initialComments,
    required this.onCommentsUpdated,
  });

  static void show(
    BuildContext context, {
    required String postId,
    required String creatorName,
    required List<String> initialComments,
    required Function(int updatedCount) onCommentsUpdated,
  }) {
    showModalBottomSheet(
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
  final TextEditingController _commentCtrl = TextEditingController();
  late List<String> _comments;

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.initialComments);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _addComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _comments.insert(0, text);
    });
    widget.onCommentsUpdated(_comments.length);
    _commentCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: const BoxDecoration(
        color: Color(0xFF12161D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comments (${_comments.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Comments List
          Expanded(
            child: _comments.isEmpty
                ? const Center(
                    child: Text(
                      'No comments yet. Start the conversation!',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(0xFFF5B942),
                              child: Text(
                                'U',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'OJAS Creator',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _comments[index],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Emoji Selector Row
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['❤️', '🔥', '👏', '😍', '🙌', '💯', '✨', '⚡'].map((emoji) {
                return GestureDetector(
                  onTap: () {
                    _commentCtrl.text += emoji;
                    _commentCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: _commentCtrl.text.length),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF171C24),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222934),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _commentCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: const InputDecoration(
                        hintText: 'Add a community comment...',
                        hintStyle:
                            TextStyle(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFFF5B942)),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
