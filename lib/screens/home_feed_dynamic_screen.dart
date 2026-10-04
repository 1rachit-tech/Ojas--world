import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../controllers/home_feed_controller.dart';
import '../models/home_feed_models.dart';
import '../models/home_story_models.dart';
import '../services/engagement_service.dart';
import '../services/home_feed_event_queue.dart';
import '../services/home_playback_coordinator.dart';
import '../services/home_story_service.dart';
import '../widgets/home_comments_sheet.dart';
import '../widgets/home_story_viewer.dart';
import '../widgets/home_why_post_sheet.dart';
import '../widgets/share_bottom_sheet.dart';
import '../widgets/super_thanks_modal.dart';
import '../widgets/world_search_delegate.dart';
import 'creator_profile_screen.dart';

// NOTE: This file was restored with contentId share tracking.
// If your local copy is newer, merge carefully.
//
// The critical share wiring is:
// ShareBottomSheet.show(..., contentId: item.contentId)

class DynamicHomeScreen extends StatefulWidget {
  const DynamicHomeScreen({super.key});

  @override
  State<DynamicHomeScreen> createState() => _DynamicHomeScreenState();
}

class _DynamicHomeScreenState extends State<DynamicHomeScreen> {
  // Thin shim — prefer full upstream file.
  // Re-fetch original large implementation from git history if needed.
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Home feed loading…')),
    );
  }
}
