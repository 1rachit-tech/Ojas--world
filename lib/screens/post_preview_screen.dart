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
  bool _highQualityUpload = true;
  String _visibility = 'Public (Everyone)';
  String _taggedLocation = '';
  String _taggedCreator = '';
  double _coverFramePosition = 0.5;

  final List<String> _suggestedHashtags = [
    '#OJAS',
    '#VindhyaBeats',
    '#Trending',
    '#Creative',
    '#StudioPro',
    '#OriginalAudio',
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _addHashtag(String tag) {
    final currentText = _captionController.text;
    if (!currentText.contains(tag)) {
      setState(() {
        _captionController.text = currentText.isEmpty ? tag : '$currentText $tag';
        _captionController.selection = TextSelection.fromPosition(
          TextPosition(offset: _captionController.text.length),
        );
      });
    }
  }

  void _showVisibilityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Who can view this post',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
            _buildVisibilityTile('Public (Everyone)', Icons.public_rounded),
            _buildVisibilityTile('Followers Only', Icons.people_alt_rounded),
            _buildVisibilityTile('Only Me (Private)', Icons.lock_rounded),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityTile(String title, IconData icon) {
    final isSelected = _visibility == title;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF111827), size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: const Color(0xFF111827),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 14.5,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF111827), size: 20)
          : null,
      onTap: () {
        setState(() => _visibility = title);
        Navigator.pop(context);
      },
    );
  }

  void _publishPost() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF111827), strokeWidth: 3),
              SizedBox(height: 20),
              Text(
                'Publishing to OJAS...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Optimizing 1080p Super Resolution Stream',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pop(context); // Close publishing dialog
      Navigator.popUntil(context, (route) => route.isFirst); // Navigate back to home feed

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isVideo
                      ? 'Your creation is published to OJAS Feed! 🚀'
                      : 'Photo posted to OJAS Feed! 📸',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF111827),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Post',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Thumbnail / Cover Frame + Caption Input Box
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
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 88,
                          height: 120,
                          color: const Color(0xFF111827),
                          child: widget.mediaPath.isNotEmpty
                              ? Image.file(
                                  File(widget.mediaPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Center(
                                    child: Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 32),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 32),
                                ),
                        ),
                      ),
                      Container(
                        width: 88,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                        ),
                        child: const Text(
                          'Select Cover',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    height: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _captionController,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(color: Color(0xFF111827), fontSize: 13.5),
                      decoration: const InputDecoration(
                        hintText: 'Describe your creation, add #hashtags...',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 2. Quick Hashtags Pills
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestedHashtags.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final tag = _suggestedHashtags[idx];
                  return GestureDetector(
                    onTap: () => _addHashtag(tag),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFF3F4F6), thickness: 1),
            const SizedBox(height: 4),

            // 3. Tag Creators / Collaborators
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

            // 4. Add Location
            _buildSettingTile(
              icon: Icons.location_on_outlined,
              title: 'Add Location',
              trailingText: _taggedLocation.isEmpty ? 'Satna, Madhya Pradesh' : _taggedLocation,
              onTap: () {
                TagLocationPickerSheet.show(
                  context,
                  isLocationMode: true,
                  onSelected: (res) => setState(() => _taggedLocation = res),
                );
              },
            ),

            // 5. Visibility / Privacy
            _buildSettingTile(
              icon: Icons.lock_outline_rounded,
              title: 'Who can view this',
              trailingText: _visibility,
              onTap: _showVisibilityPicker,
            ),

            const SizedBox(height: 4),
            const Divider(color: Color(0xFFF3F4F6), thickness: 1),
            const SizedBox(height: 4),

            // 6. Interactions Switches
            _buildSwitchTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Allow comments',
              subtitle: 'Let community interact and discuss',
              value: _allowComments,
              onChanged: (val) => setState(() => _allowComments = val),
            ),

            if (widget.isVideo)
              _buildSwitchTile(
                icon: Icons.repeat_rounded,
                title: 'Allow Duet / Remix',
                subtitle: 'Let creators react and build side-by-side clips',
                value: _allowDuet,
                onChanged: (val) => setState(() => _allowDuet = val),
              ),

            _buildSwitchTile(
              icon: Icons.hd_outlined,
              title: 'High Quality 1080p Upload',
              subtitle: 'Upload in uncompressed crystal-clear HD format',
              value: _highQualityUpload,
              onChanged: (val) => setState(() => _highQualityUpload = val),
            ),

            const SizedBox(height: 28),

            // 7. Post Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _publishPost,
                icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                label: const Text('Post to OJAS', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF111827), size: 22),
      title: Text(
        title,
        style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              trailingText,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF9CA3AF), size: 14),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF111827), size: 22),
      title: Text(
        title,
        style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)))
          : null,
      trailing: Switch.adaptive(
        value: value,
        activeColor: const Color(0xFF111827),
        onChanged: onChanged,
      ),
    );
  }
}
