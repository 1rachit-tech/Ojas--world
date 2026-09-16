import 'package:flutter/material.dart';

class HomeRecommendationControlsSheet extends StatelessWidget {
  const HomeRecommendationControlsSheet({
    super.key,
    required this.onReset,
    required this.onMutedCreators,
    required this.onManageTopics,
  });

  final VoidCallback onReset;
  final VoidCallback onMutedCreators;
  final VoidCallback onManageTopics;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onReset,
    required VoidCallback onMutedCreators,
    required VoidCallback onManageTopics,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => HomeRecommendationControlsSheet(
        onReset: onReset,
        onMutedCreators: onMutedCreators,
        onManageTopics: onManageTopics,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recommendation Controls',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Manage Topics'),
            subtitle: const Text('Control the interests used for recommendations'),
            onTap: () {
              Navigator.pop(context);
              onManageTopics();
            },
          ),
          ListTile(
            leading: const Icon(Icons.volume_off_rounded),
            title: const Text('Muted Creators'),
            subtitle: const Text('Creators whose posts are hidden from Home'),
            onTap: () {
              Navigator.pop(context);
              onMutedCreators();
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('Reset Recommendations'),
            subtitle: const Text('Start rebuilding your Home recommendations'),
            onTap: () {
              Navigator.pop(context);
              onReset();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
