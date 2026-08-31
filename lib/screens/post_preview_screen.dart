import 'dart:io';
import 'package:flutter/material.dart';

class PostPreviewScreen extends StatefulWidget {
  final String mediaPath;
  final bool isVideo;

  const PostPreviewScreen({
    super.key,
    required this.mediaPath,
    required this.isVideo,
  });

  @override
  State<PostPreviewScreen> createState() => _PostPreviewScreenState();
}

class _PostPreviewScreenState extends State<PostPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  bool _allowComments = true;
  bool _allowDuet = true;
  String _visibility = 'Public';

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _publishPost() {
    Navigator.pop(context); // क्रिएटर स्क्रीन बंद करें
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your video is uploading to OJAS! 🚀'),
        backgroundColor: Color(0xFFF5B942),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved locally! 💾')));
              Navigator.pop(context);
            },
            child: const Text('Drafts', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Thumbnail & Caption Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 90,
                    height: 120,
                    color: const Color(0xFF21262D),
                    child: widget.mediaPath.isNotEmpty
                        ? Image.file(File(widget.mediaPath), fit: BoxFit.cover, errorBuilder: (c, e, s) {
                            return const Center(child: Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 36));
                          })
                        : const Center(child: Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 36)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _captionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Describe your creation, add #hashtags and @mentions...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),

            // Quick Hashtags
            Wrap(
              spacing: 8,
              children: ['#OJAS', '#VindhyaBeats', '#Trending', '#Creative'].map((tag) {
                return ActionChip(
                  label: Text(tag),
                  backgroundColor: const Color(0xFF161B22),
                  labelStyle: const TextStyle(color: Color(0xFFF5B942), fontSize: 12, fontWeight: FontWeight.bold),
                  side: BorderSide.none,
                  onPressed: () {
                    _captionController.text += ' $tag ';
                    _captionController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _captionController.text.length),
                    );
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Options List
            _buildSettingTile(
              icon: Icons.public_rounded,
              title: 'Who can view this video',
              trailingText: _visibility,
              onTap: () {
                setState(() {
                  _visibility = _visibility == 'Public' ? 'Followers' : 'Public';
                });
              },
            ),
            _buildSwitchTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Allow comments',
              value: _allowComments,
              onChanged: (val) => setState(() => _allowComments = val),
            ),
            _buildSwitchTile(
              icon: Icons.repeat_rounded,
              title: 'Allow Duet / Remix',
              value: _allowDuet,
              onChanged: (val) => setState(() => _allowDuet = val),
            ),
            const SizedBox(height: 40),

            // Post Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5B942),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _publishPost,
                icon: const Icon(Icons.send_rounded, size: 20),
                label: const Text('Post to OJAS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({required IconData icon, required String title, required String trailingText, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailingText, style: const TextStyle(color: Color(0xFFF5B942), fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({required IconData icon, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: Switch.adaptive(
        value: value,
        activeColor: const Color(0xFFF5B942),
        onChanged: onChanged,
      ),
    );
  }
}
