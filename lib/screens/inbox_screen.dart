import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (context) => const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'New chat',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Chat creation will be available in the next step.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: userId == null
          ? const _InboxMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in required',
              message: 'Please sign in to view your messages.',
            )
          : _ConversationStream(userId: userId),
    );
  }
}

class _ConversationStream extends StatelessWidget {
  const _ConversationStream({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _InboxMessage(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load messages',
            message: 'Please check your connection and try again.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final conversations = snapshot.data?.docs ?? const [];

        if (conversations.isEmpty) {
          return const _InboxMessage(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No messages yet',
            message: 'Your conversations will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: 84,
            color: Color(0xFFF3F4F6),
          ),
          itemBuilder: (context, index) {
            final doc = conversations[index];
            return _ConversationTile(
              conversationId: doc.id,
              currentUserId: userId,
              data: doc.data(),
            );
          },
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversationId,
    required this.currentUserId,
    required this.data,
  });

  final String conversationId;
  final String currentUserId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final participants = List<String>.from(
      data['participants'] is List ? data['participants'] as List : const <String>[],
    );
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    final participantProfiles = data['participantProfiles'];
    final profiles = participantProfiles is Map
        ? Map<String, dynamic>.from(participantProfiles)
        : const <String, dynamic>{};
    final rawProfile = profiles[otherUserId];
    final profile = rawProfile is Map
        ? Map<String, dynamic>.from(rawProfile)
        : const <String, dynamic>{};

    final username = _firstString([
      profile['username'],
      profile['ojasId'],
      profile['displayName'],
      otherUserId.isEmpty ? null : otherUserId,
    ], fallback: 'OJAS user');
    final avatarUrl = _firstString([
      profile['photoUrl'],
      profile['avatarUrl'],
    ]);
    final lastMessage = _firstString([
      data['lastMessageText'],
      data['lastMessage'],
    ], fallback: 'No messages yet');
    final unreadCount = _readUnreadCount(data['unreadCounts'], currentUserId);
    final lastMessageAt = data['lastMessageAt'];
    final time = _formatTime(lastMessageAt);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: _Avatar(url: avatarUrl, label: username),
      title: Text(
        username,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: const Color(0xFF111827),
          fontWeight: unreadCount > 0 ? FontWeight.w800 : FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unreadCount > 0
                ? const Color(0xFF374151)
                : const Color(0xFF6B7280),
            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          if (unreadCount > 0)
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(5),
                child: Text(
                  '•',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 0.8,
                  ),
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat room will open in the next step.'),
            duration: Duration(seconds: 1),
          ),
        );
      },
    );
  }

  static String _firstString(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  static int _readUnreadCount(dynamic unreadCounts, String userId) {
    if (unreadCounts is! Map) return 0;
    final value = unreadCounts[userId];
    if (value is num) return value.toInt().clamp(0, 999999);
    return 0;
  }

  static String _formatTime(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'now';
      if (difference.inHours < 1) return '${difference.inMinutes}m';
      if (difference.inDays < 1) return '${difference.inHours}h';
      if (difference.inDays < 7) return '${difference.inDays}d';
      return '${date.day}/${date.month}';
    }
    return '';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final initial = label.isEmpty ? 'O' : label.substring(0, 1).toUpperCase();

    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFFF3F4F6),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFFF3F4F6),
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    );
  }
}

class _InboxMessage extends StatelessWidget {
  const _InboxMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(0xFFD1D5DB)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
