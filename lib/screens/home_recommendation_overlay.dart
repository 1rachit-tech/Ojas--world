import 'package:flutter/material.dart';

import '../controllers/home_feed_controller.dart';
import '../widgets/home_recommendation_controls_sheet.dart';
import 'home_feed_dynamic_screen.dart';
import 'home_manage_topics_screen.dart';
import 'home_muted_creators_screen.dart';

class HomeRecommendationOverlay extends StatefulWidget {
  const HomeRecommendationOverlay({super.key});

  @override
  State<HomeRecommendationOverlay> createState() => _HomeRecommendationOverlayState();
}

class _HomeRecommendationOverlayState extends State<HomeRecommendationOverlay> {
  late final HomeFeedController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeFeedController()..addListener(_refresh);
    _controller.initialize();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _showControls() async {
    await HomeRecommendationControlsSheet.show(
      context,
      onReset: _resetRecommendations,
      onMutedCreators: _openMuted,
      onManageTopics: _openTopics,
    );
  }

  Future<void> _openTopics() async {
    final selected = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => HomeManageTopicsScreen(
          initialTopics: _controller.managedTopics,
          onSave: _controller.setManagedTopics,
        ),
      ),
    );
    if (selected != null) await _controller.setManagedTopics(selected);
  }

  Future<void> _openMuted() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => HomeMutedCreatorsScreen(
          creatorIds: _controller.mutedCreatorIds,
          onUnmute: _controller.unmuteCreator,
        ),
      ),
    );
  }

  Future<void> _resetRecommendations() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset recommendations?'),
        content: const Text(
          'This resets your recommendation profile and saved Home feed session. '
          'Your posts, follows, likes and comments remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller.resetRecommendations();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DynamicHomeScreen(),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 52),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _showControls,
                  child: Ink(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.96),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Color(0x22000000)),
                      ],
                    ),
                    child: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF111827)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
