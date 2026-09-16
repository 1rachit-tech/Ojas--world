import 'package:flutter/material.dart';

class HomeWhyPostSheet extends StatelessWidget {
  const HomeWhyPostSheet({
    super.key,
    required this.reason,
    required this.onNotInterested,
  });

  final String reason;
  final VoidCallback onNotInterested;

  static Future<void> show(
    BuildContext context, {
    required String reason,
    required VoidCallback onNotInterested,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => HomeWhyPostSheet(
        reason: reason,
        onNotInterested: onNotInterested,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why you are seeing this post',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 20, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(fontSize: 14, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.thumb_down_alt_outlined),
              title: const Text('Not Interested'),
              subtitle: const Text('Show fewer posts like this'),
              onTap: () {
                Navigator.pop(context);
                onNotInterested();
              },
            ),
          ],
        ),
      ),
    );
  }
}
