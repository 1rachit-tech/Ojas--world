import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Real Mitra compatibility verification trigger; no runtime behavior change.
import '../models/ojas_profile.dart';
import '../services/notification_service.dart';
import 'chat_room_screen.dart';

class NotificationChatRouter extends StatefulWidget {
  const NotificationChatRouter({
    super.key,
    required this.openData,
  });

  final NotificationOpenData openData;

  @override
  State<NotificationChatRouter> createState() => _NotificationChatRouterState();
}

class _NotificationChatRouterState extends State<NotificationChatRouter> {
  String _error = '';

  @override
  void initState() {
    super.initState();
    _openChat();
  }

  Future<void> _openChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _error = 'Please sign in again to open this message.');
      }
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.openData.conversationId)
          .get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('Conversation not found.');
      }

      final participants = data['participants'];
      if (participants is! List ||
          !participants.contains(user.uid) ||
          !participants.contains(widget.openData.senderId)) {
        throw StateError('You are not a participant in this conversation.');
      }

      final profiles = data['participantProfiles'];
      if (profiles is! Map) {
        throw StateError('Conversation profile data is unavailable.');
      }

      final rawProfile = profiles[widget.openData.senderId];
      if (rawProfile is! Map) {
        throw StateError('The sender profile is unavailable.');
      }

      final profile = OjasProfile.fromMap(
        Map<String, dynamic>.from(rawProfile),
        uid: widget.openData.senderId,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            conversationId: widget.openData.conversationId,
            otherUser: profile,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This conversation is no longer available.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 48),
              const SizedBox(height: 16),
              Text(_error, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
