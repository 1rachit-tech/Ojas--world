import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/social_interaction.dart';
import '../services/social_interaction_service.dart';

class ShareBottomSheet extends StatelessWidget {
  final String videoUrl;
  final String creatorName;
  final String? contentId;

  const ShareBottomSheet({
    super.key,
    required this.videoUrl,
    required this.creatorName,
    this.contentId,
  });

  static void show(
    BuildContext context, {
    required String videoUrl,
    required String creatorName,
    String? contentId,
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ShareBottomSheet(
        videoUrl: videoUrl,
        creatorName: creatorName,
        contentId: contentId,
      ),
    );
  }

  String get _resolvedContentId {
    if (contentId != null && contentId!.isNotEmpty) return contentId!;
    final uri = Uri.tryParse(videoUrl);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final idx = uri.pathSegments.indexOf('post');
      if (idx >= 0 && idx + 1 < uri.pathSegments.length) {
        return uri.pathSegments[idx + 1];
      }
    }
    return '';
  }

  Future<void> _track(String channel, String intent, {String? destination}) async {
    final id = _resolvedContentId;
    if (id.isEmpty) return;
    try {
      await SocialInteractionService.instance.trackShare(ShareTrackEvent(
        contentId: id,
        channel: channel,
        intent: intent,
        destination: destination,
      ));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final socialShareList = <Map<String, dynamic>>[
      {'name': 'WhatsApp', 'icon': Icons.chat_rounded, 'color': const Color(0xFF25D366)},
      {'name': 'Telegram', 'icon': Icons.send_rounded, 'color': const Color(0xFF229ED9)},
      {'name': 'Instagram', 'icon': Icons.camera_alt_rounded, 'color': const Color(0xFFE1306C)},
      {'name': 'Send in Ojas', 'icon': Icons.sms_rounded, 'color': const Color(0xFF2563EB)},
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
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 82,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: socialShareList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final item = socialShareList[index];
                  return GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      if (item['name'] == 'Send in Ojas') {
                        await _track('internal', 'opened');
                        await _showConversationShareSheet(context, videoUrl: videoUrl);
                        return;
                      }
                      await Clipboard.setData(ClipboardData(text: videoUrl));
                      await _track('external', 'opened', destination: item['name'] as String?);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ready to share via ${item['name']}'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF111827),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: (item['color'] as Color).withValues(alpha: 0.15),
                          child: Icon(item['icon'] as IconData, color: item['color'] as Color),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['name'] as String,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF4B5563)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Divider(color: Color(0xFFF3F4F6), height: 1),
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
          await _track('copy_link', 'copied');
        } else if (label == 'Save to Device') {
          try {
            await DefaultCacheManager().downloadFile(videoUrl);
          } catch (_) {}
        } else if (label == 'Send in Ojas') {
          await _track('internal', 'opened');
          await _showConversationShareSheet(context, videoUrl: videoUrl);
          return;
        }
        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              label == 'Copy Link'
                  ? 'Link copied to clipboard'
                  : label == 'Save to Device'
                      ? 'Saved to device cache'
                      : '$label done',
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
            child: Icon(icon, color: const Color(0xFF111827), size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Future<void> _showConversationShareSheet(
    BuildContext context, {
    required String videoUrl,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ConversationShareSheet(
        videoUrl: videoUrl,
        contentId: _resolvedContentId,
        onShared: () => _track('internal', 'completed'),
      ),
    );
  }
}

class _ConversationShareSheet extends StatelessWidget {
  const _ConversationShareSheet({
    required this.videoUrl,
    required this.contentId,
    this.onShared,
  });

  final String videoUrl;
  final String contentId;
  final VoidCallback? onShared;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Sign in to share in OJAS'),
      );
    }

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Send in OJAS',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('conversations')
                    .where('participants', arrayContains: uid)
                    .limit(30)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No conversations yet'));
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final participants = (data['participants'] as List?) ?? [];
                      final otherId = participants.cast<String?>().firstWhere(
                            (p) => p != null && p != uid,
                            orElse: () => null,
                          ) ??
                          '';
                      final profiles = data['participantProfiles'];
                      String name = 'OJAS User';
                      if (profiles is Map && otherId.isNotEmpty) {
                        final p = profiles[otherId];
                        if (p is Map && p['displayName'] is String) {
                          name = (p['displayName'] as String).trim().isEmpty
                              ? name
                              : p['displayName'] as String;
                        }
                      }
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF111827),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'O',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(name),
                        onTap: otherId.isEmpty
                            ? null
                            : () async {
                                try {
                                  final convId = docs[index].id;
                                  await FirebaseFirestore.instance
                                      .collection('conversations')
                                      .doc(convId)
                                      .collection('messages')
                                      .add({
                                    'conversationId': convId,
                                    'senderId': uid,
                                    'text': contentId.isNotEmpty
                                        ? 'Shared a post'
                                        : 'Shared media',
                                    'type': 'text',
                                    'status': 'sent',
                                    'isDeleted': false,
                                    'reactions': <String, String>{},
                                    'sharedContentId': contentId,
                                    'mediaUrl': videoUrl,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                                  await FirebaseFirestore.instance
                                      .collection('conversations')
                                      .doc(convId)
                                      .set({
                                    'lastMessage': 'Shared a post',
                                    'lastMessageSenderId': uid,
                                    'lastMessageAt': FieldValue.serverTimestamp(),
                                    'unreadCounts.$otherId': FieldValue.increment(1),
                                  }, SetOptions(merge: true));
                                  onShared?.call();
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Sent in OJAS')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not send: $e')),
                                    );
                                  }
                                }
                              },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
