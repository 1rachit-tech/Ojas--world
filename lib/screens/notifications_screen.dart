import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/social_interaction.dart';
import '../services/social_interaction_service.dart';

/// Real notifications: incoming follow requests + recent activity aggregates.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF111827), size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: uid == null
          ? const Center(
              child: Text(
                'Sign in to see notifications',
                style: TextStyle(color: Color(0xFF9CA3AF)),
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                StreamBuilder<List<FollowRequest>>(
                  stream: SocialInteractionService.instance
                      .watchIncomingFollowRequests(),
                  builder: (context, snap) {
                    final requests = snap.data ?? const <FollowRequest>[];
                    if (requests.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Follow requests',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        ...requests.map((r) => _FollowRequestTile(request: r)),
                        const Divider(height: 24, color: Color(0xFFF3F4F6)),
                      ],
                    );
                  },
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('notificationAggregates')
                      .where('recipientId', isEqualTo: uid)
                      .orderBy('updatedAt', descending: true)
                      .limit(40)
                      .snapshots(),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty &&
                        snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'No new notifications',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: docs.map((d) {
                        final data = d.data();
                        return _AggregateTile(data: data);
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _FollowRequestTile extends StatelessWidget {
  const _FollowRequestTile({required this.request});

  final FollowRequest request;

  @override
  Widget build(BuildContext context) {
    final name =
        request.requesterName.trim().isEmpty ? 'OJAS User' : request.requesterName;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF111827),
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: const Text(
        'requested to follow you',
        style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              try {
                await SocialInteractionService.instance
                    .acceptFollowRequest(request.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Confirm', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () async {
              HapticFeedback.selectionClick();
              await SocialInteractionService.instance
                  .declineFollowRequest(request.id);
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Delete', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _AggregateTile extends StatelessWidget {
  const _AggregateTile({required this.data});

  final Map<String, dynamic> data;

  String get _body {
    final action = data['action'] as String? ?? '';
    final count = (data['count'] as num?)?.toInt() ?? 1;
    final actors = (data['actorIds'] as List?)?.whereType<String>().toList() ?? [];
    final first = actors.isNotEmpty ? 'Someone' : 'Someone';
    switch (action) {
      case 'like':
        return count > 1
            ? '$first and ${count - 1} others liked your post'
            : '$first liked your post';
      case 'comment':
        return count > 1
            ? '$first and ${count - 1} others commented'
            : '$first commented on your post';
      case 'reply':
        return '$first replied to a comment';
      case 'comment_like':
        return '$first liked your comment';
      case 'follow':
        return '$first started following you';
      case 'follow_request':
        return '$first requested to follow you';
      default:
        return '$first interacted with you';
    }
  }

  IconData get _icon {
    switch (data['action'] as String? ?? '') {
      case 'like':
      case 'comment_like':
        return Icons.favorite_rounded;
      case 'comment':
      case 'reply':
        return Icons.mode_comment_rounded;
      case 'follow':
      case 'follow_request':
        return Icons.person_add_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get _color {
    switch (data['action'] as String? ?? '') {
      case 'like':
      case 'comment_like':
        return const Color(0xFFEF4444);
      case 'comment':
      case 'reply':
        return const Color(0xFF3B82F6);
      case 'follow':
      case 'follow_request':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: _color.withValues(alpha: 0.15),
        child: Icon(_icon, color: _color, size: 20),
      ),
      title: Text(
        _body,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF374151),
          height: 1.35,
        ),
      ),
    );
  }
}
