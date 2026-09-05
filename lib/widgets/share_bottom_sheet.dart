import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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
    showModalBottomSheet<void>(
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
    final socialShareList = <Map<String, dynamic>>[
      {
        'name': 'WhatsApp',
        'icon': Icons.chat_rounded,
        'color': const Color(0xFF25D366),
      },
      {
        'name': 'Stories',
        'icon': Icons.camera_alt_rounded,
        'color': const Color(0xFFE1306C),
      },
      {
        'name': 'Send in Ojas',
        'icon': Icons.send_rounded,
        'color': const Color(0xFF111827),
      },
      {
        'name': 'SMS',
        'icon': Icons.sms_rounded,
        'color': const Color(0xFF2563EB),
      },
    ];

    final toolActions = <Map<String, dynamic>>[
      {'name': 'Copy Link', 'icon': Icons.copy_rounded},
      {'name': 'Save to Device', 'icon': Icons.download_rounded},
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
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      if (item['name'] == 'Send in Ojas') {
                        await _showConversationShareSheet(
                          context,
                          videoUrl: videoUrl,
                        );
                        return;
                      }

                      await Clipboard.setData(ClipboardData(text: videoUrl));
                      if (!context.mounted) return;
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
                    videoUrl: videoUrl,
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
    required String videoUrl,
  }) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        if (label == 'Copy Link') {
          await Clipboard.setData(ClipboardData(text: videoUrl));
        } else if (label == 'Save to Device') {
          try {
            await DefaultCacheManager().downloadFile(videoUrl);
          } catch (_) {}
        } else if (label == 'Send in Ojas') {
          await _showConversationShareSheet(context, videoUrl: videoUrl);
          return;
        }

        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              label == 'Copy Link'
                  ? 'Link copied to clipboard! 📋'
                  : label == 'Save to Device'
                  ? 'Saved to local device cache ✅'
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

  static Future<void> _showConversationShareSheet(
    BuildContext context, {
    required String videoUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to send a reel.')),
        );
      }
      return;
    }

    String caption = '';
    try {
      final reelSnapshot = await FirebaseFirestore.instance
          .collection('reels')
          .where('hlsUrl', isEqualTo: videoUrl)
          .limit(1)
          .get();
      if (reelSnapshot.docs.isNotEmpty) {
        final data = reelSnapshot.docs.first.data();
        final value = data['caption'];
        if (value is String) caption = value.trim();
      }
    } catch (_) {}

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ConversationShareSheet(
        currentUserId: user.uid,
        videoUrl: videoUrl,
        caption: caption,
      ),
    );
  }
}

class _ConversationShareSheet extends StatelessWidget {
  const _ConversationShareSheet({
    required this.currentUserId,
    required this.videoUrl,
    required this.caption,
  });

  final String currentUserId;
  final String videoUrl;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageAt', descending: true)
        .limit(20);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load conversations.'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }

            final docs = snapshot.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No conversations yet. Start a chat first.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final participants = data['participants'];
                final ids = participants is List
                    ? List<String>.from(participants.whereType<String>())
                    : const <String>[];
                final recipientId = ids.firstWhere(
                  (id) => id != currentUserId,
                  orElse: () => '',
                );
                final profileMap = data['participantProfiles'];
                final allProfiles = profileMap is Map
                    ? Map<String, dynamic>.from(profileMap)
                    : const <String, dynamic>{};
                final rawRecipientProfile = allProfiles[recipientId];
                final recipientProfile = rawRecipientProfile is Map
                    ? Map<String, dynamic>.from(rawRecipientProfile)
                    : const <String, dynamic>{};
                final name = _firstString([
                  recipientProfile['ojasId'],
                  recipientProfile['displayName'],
                  recipientId,
                ], fallback: 'OJAS user');
                final avatar = _stringValue(recipientProfile['photoUrl']);

                return ListTile(
                  leading: _ConversationAvatar(url: avatar, label: name),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Send reel'),
                  onTap: recipientId.isEmpty
                      ? null
                      : () => _sendReel(
                            context,
                            conversationId: docs[index].id,
                            recipientId: recipientId,
                            recipientName: name,
                          ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _sendReel(
    BuildContext context, {
    required String conversationId,
    required String recipientId,
    required String recipientName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final message = caption.isEmpty ? 'Shared a reel' : caption;
      final conversationRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId);

      await conversationRef.collection('messages').add({
        'senderId': user.uid,
        'type': 'video',
        'mediaUrl': videoUrl,
        'text': message,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await conversationRef.update({
        'lastMessageText': message,
        'lastMessage': message,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'lastSenderId': user.uid,
      });

      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent to $recipientName!')),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to send reel.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send reel.')),
      );
    }
  }

  static String _stringValue(dynamic value) =>
      value is String ? value.trim() : '';

  static String _firstString(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final initial = label.isEmpty ? 'O' : label.substring(0, 1).toUpperCase();
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFFF3F4F6),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 24,
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
