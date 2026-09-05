import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';

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
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: userId == null
                ? null
                : () => _showNewChatSheet(context, userId),
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

  static Future<void> _showNewChatSheet(
    BuildContext context,
    String currentUserId,
  ) async {
    final selected = await showModalBottomSheet<_SelectedUser>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NewChatSheet(currentUserId: currentUserId),
    );

    if (!context.mounted || selected == null) return;

    try {
      final conversationId = currentUserId.compareTo(selected.uid) < 0
          ? '${currentUserId}_${selected.uid}'
          : '${selected.uid}_$currentUserId';
      final ref = FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId);
      final existing = await ref.get();

      if (!existing.exists) {
        final currentUser = FirebaseAuth.instance.currentUser;
        await ref.set({
          'participants': [currentUserId, selected.uid],
          'participantProfiles': {
            currentUserId: {
              'displayName': currentUser?.displayName?.trim() ?? '',
              'ojasId': currentUser?.email?.trim() ?? '',
              'photoUrl': currentUser?.photoURL?.trim() ?? '',
            },
            selected.uid: {
              'displayName': selected.name,
              'ojasId': selected.ojasId,
              'photoUrl': selected.avatarUrl,
            },
          },
          'unreadCounts': {
            currentUserId: 0,
            selected.uid: 0,
          },
          'lastMessage': '',
          'lastMessageText': '',
          'lastMessageSenderId': '',
          'lastSenderId': '',
          'typingBy': {},
        });
      }

      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            recipientId: selected.uid,
            recipientName: selected.name.isNotEmpty
                ? selected.name
                : selected.ojasId,
            recipientAvatar: selected.avatarUrl,
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to start chat.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start chat.')),
      );
    }
  }
}

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet({required this.currentUserId});

  final String currentUserId;

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final ojasId = _controller.text.trim().toLowerCase();
    if (ojasId.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('publicProfiles')
          .where('ojasId', isEqualTo: ojasId)
          .limit(1)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        setState(() => _error = 'OJAS ID not found.');
        return;
      }

      final doc = snapshot.docs.first;
      if (doc.id == widget.currentUserId) {
        setState(() => _error = 'You cannot start a chat with yourself.');
        return;
      }

      final data = doc.data();
      final name = _stringValue(data['displayName']);
      final resolvedOjasId = _stringValue(data['ojasId']);
      final avatarUrl = _stringValue(data['photoUrl']);

      Navigator.of(context).pop(
        _SelectedUser(
          uid: doc.id,
          name: name,
          ojasId: resolvedOjasId.isNotEmpty ? resolvedOjasId : ojasId,
          avatarUrl: avatarUrl,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message ?? 'Unable to search for that OJAS ID.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to search for that OJAS ID.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _stringValue(dynamic value) {
    return value is String ? value.trim() : '';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New chat',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter an exact OJAS ID to start a private conversation.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_loading,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'OJAS ID',
              hintText: 'e.g. rachit_ojas',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _loading ? null : _search,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: const Text('Find user'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedUser {
  const _SelectedUser({
    required this.uid,
    required this.name,
    required this.ojasId,
    required this.avatarUrl,
  });

  final String uid;
  final String name;
  final String ojasId;
  final String avatarUrl;
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
      data['participants'] is List
          ? data['participants'] as List
          : const <String>[],
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
    final time = _formatTime(data['lastMessageAt']);

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
            _UnreadBadge(count: unreadCount),
        ],
      ),
      onTap: otherUserId.isEmpty
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(
                    conversationId: conversationId,
                    recipientId: otherUserId,
                    recipientName: username,
                    recipientAvatar: avatarUrl,
                  ),
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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
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
            Icon(icon, size: 42, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 7),
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
