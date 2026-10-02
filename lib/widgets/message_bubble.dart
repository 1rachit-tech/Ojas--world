import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_theme.dart';
import '../models/ojas_message.dart';
import 'ojas_smart_video_player.dart';
import 'voice_note_bubble.dart';

/// Instagram DM style bubble with animated reactions.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.theme = ChatTheme.classic,
    this.currentUid,
    this.onReply,
    this.onLongPress,
    this.onReact,
    this.imageBuilder,
    this.videoBuilder,
    this.child,
  });

  final OjasMessage message;
  final bool isMine;
  final ChatTheme theme;
  final String? currentUid;
  final VoidCallback? onReply;
  final VoidCallback? onLongPress;
  final ValueChanged<String>? onReact;
  final Widget Function()? imageBuilder;
  final Widget Function()? videoBuilder;
  final Widget? child;

  static const List<String> quickReactions = [
    '❤️',
    '😂',
    '😮',
    '😢',
    '😡',
    '👍',
  ];

  @override
  Widget build(BuildContext context) {
    final surface = isMine ? theme.mineBubble : theme.theirsBubble;
    final foreground = isMine ? theme.mineText : theme.theirsText;

    final displayText = message.isDeleted
        ? 'This message was deleted'
        : message.text;

    Widget? mediaChild;
    if (child != null) {
      mediaChild = child;
    } else if (message.isVideo && message.hasMedia) {
      mediaChild = videoBuilder?.call() ??
          OjasSmartVideoPlayer(
            videoUrl: message.mediaUrl!,
            aspectRatio: message.mediaAspectRatio,
          );
    } else if (message.isImage && message.hasMedia) {
      mediaChild = imageBuilder?.call();
    } else if (message.isAudio && message.hasMedia) {
      mediaChild = VoiceNoteBubble(
        url: message.mediaUrl!,
        isMine: isMine,
        accent: theme.accent,
      );
    }

    final summary = message.reactionSummary;
    final myReaction =
        currentUid == null ? null : message.reactionOf(currentUid!);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          if (onLongPress != null) {
            onLongPress!();
          } else if (onReply != null && !message.isDeleted) {
            onReply!();
          }
        },
        onDoubleTap: () {
          if (onReact != null && !message.isDeleted) {
            HapticFeedback.lightImpact();
            onReact!('❤️');
          }
        },
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              margin: EdgeInsets.only(
                left: isMine ? 48 : 12,
                right: isMine ? 12 : 48,
                top: 2,
                bottom: summary.isEmpty ? 2 : 0,
              ),
              padding: mediaChild != null && displayText.trim().isEmpty
                  ? const EdgeInsets.all(3)
                  : const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: surface.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (message.hasReply &&
                      (message.replyToText?.trim().isNotEmpty ?? false))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                            color: foreground.withValues(alpha: 0.45),
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Text(
                        message.replyToText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.85),
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (mediaChild != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: mediaChild,
                    ),
                  if (displayText.trim().isNotEmpty)
                    Padding(
                      padding: mediaChild != null
                          ? const EdgeInsets.fromLTRB(4, 6, 4, 2)
                          : EdgeInsets.zero,
                      child: Text(
                        displayText,
                        style: TextStyle(
                          color: foreground.withValues(
                            alpha: message.isDeleted ? 0.65 : 1,
                          ),
                          fontSize: 15.5,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                          fontStyle: message.isDeleted
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                  if (isMine && !message.isDeleted)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(
                        message.status == 'seen'
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 14,
                        color: message.status == 'seen'
                            ? const Color(0xFF93C5FD)
                            : foreground.withValues(alpha: 0.55),
                      ),
                    ),
                ],
              ),
            ),
            if (summary.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  left: isMine ? 48 : 16,
                  right: isMine ? 16 : 48,
                  bottom: 4,
                  top: 2,
                ),
                child: Wrap(
                  spacing: 4,
                  children: summary.entries.map((entry) {
                    final selected = myReaction == entry.key;
                    return GestureDetector(
                      onTap: onReact == null
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              onReact!(entry.key);
                            },
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.6, end: 1.0),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.accent.withValues(alpha: 0.15)
                                : (theme.isDark
                                    ? const Color(0xFF1F2937)
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? theme.accent
                                  : const Color(0xFFE5E7EB),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '${entry.key} ${entry.value}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
