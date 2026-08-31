import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/thumbnail_picker_sheet.dart';
import '../widgets/tag_location_picker_sheet.dart';

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
  String _taggedLocation = '';
  String _taggedCreator = '';
  double _coverFramePosition = 0.5;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _publishPost() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your creation is published to OJAS! 🚀'),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail / Cover Frame + Caption
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    ThumbnailPickerSheet.show(
                      context,
                      currentPosition: _coverFramePosition,
                      onThumbnailSelected: (pos) => setState(() => _coverFramePosition = pos),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 95,
                          height: 130,
                          color: const Color(0xFF21262D),
                          child: widget.mediaPath.isNotEmpty
                              ? Image.file(File(widget.mediaPath), fit: BoxFit.cover, errorBuilder: (c, e, s) {
                                  return const Center(child: Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 36));
                                })
                              : const Center(child: Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 36)),
                        ),
                      ),
                      Container(
                        width: 95,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: const BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
                        child: const Text('Select Cover', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFF5B942), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _captionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Describe your creation, add #hashtags...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                    _captionController.selection = TextSelection.fromPosition(TextPosition(offset: _captionController.text.length));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Tag People & Add Location
            _buildSettingTile(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Tag Creators / Collaborators',
              trailingText: _taggedCreator.isEmpty ? 'Add' : _taggedCreator,
              onTap: () {
                TagLocationPickerSheet.show(
                  context,
                  isLocationMode: false,
                  onSelected: (res) => setState(() => _taggedCreator = res),
                );
              },
            ),
            _buildSettingTile(
              icon: Icons.location_on_rounded,
              title: 'Add Location',
              trailingText: _taggedLocation.isEmpty ? 'Add' : _taggedLocation,
              onTap: () {
                TagLocationPickerSheet.show(
                  context,
                  isLocationMode: true,
                  onSelected: (res) => setState(() => _taggedLocation = res),
                );
              },
            ),
            _buildSettingTile(
              icon: Icons.public_rounded,
              title: 'Who can view this',
              trailingText: _visibility,
              onTap: () {
                setState(() => _visibility = _visibility == 'Public' ? 'Followers' : 'Public');
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
            const SizedBox(height: 30),

            // Post Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5B942),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(trailingText, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFF5B942), fontWeight: FontWeight.w600, fontSize: 13)),
          ),
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
      trailing: Switch.adaptive(value: value, activeColor: const Color(0xFFF5B942), onChanged: onChanged),
    );
  }
}
