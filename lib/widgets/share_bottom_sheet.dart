import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShareBottomSheet extends StatelessWidget {
  final String videoUrl;
  final String creatorName;

  const ShareBottomSheet({
    super.key,
    required this.videoUrl,
    required this.creatorName,
  });

  static void show(
    BuildContext context, {
    required String videoUrl,
    required String creatorName,
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ShareBottomSheet(
        videoUrl: videoUrl,
        creatorName: creatorName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> socialShareList = [
      {'name': 'WhatsApp', 'icon': Icons.chat_rounded, 'color': const Color(0xFF25D366)},
      {'name': 'Stories', 'icon': Icons.camera_alt_rounded, 'color': const Color(0xFFE1306C)},
      {'name': 'Direct Message', 'icon': Icons.send_rounded, 'color': const Color(0xFF111827)},
      {'name': 'SMS', 'icon': Icons.sms_rounded, 'color': const Color(0xFF2563EB)},
    ];

    final List<Map<String, dynamic>> toolActions = [
      {'name': 'Copy Link', 'icon': Icons.copy_rounded},
      {'name': 'Save Video', 'icon': Icons.download_rounded},
      {'name': 'QR Code', 'icon': Icons.qr_code_rounded},
      {'name': 'Not Interested', 'icon': Icons.heart_broken_outlined},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Share video by @$creatorName',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 82,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: socialShareList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final item = socialShareList[index];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Clipboard.setData(ClipboardData(text: videoUrl));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Opening ${item['name']}... 🚀'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF111827),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: item['color'] as Color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['name'] as String,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF4B5563),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Divider(color: Color(0xFFF3F4F6), height: 1, thickness: 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: toolActions.map((action) {
                  return _buildToolAction(
                    context,
                    icon: action['icon'] as IconData,
                    label: action['name'] as String,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolAction(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (label == 'Copy Link') {
          Clipboard.setData(ClipboardData(text: videoUrl));
        }
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              label == 'Copy Link'
                  ? 'Link copied to clipboard! 📋'
                  : '$label executed!',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF111827),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF111827), size: 21),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
