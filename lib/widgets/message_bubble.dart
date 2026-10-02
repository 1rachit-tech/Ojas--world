import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_theme.dart';
import '../models/ojas_message.dart';
import 'ojas_smart_video_player.dart';

/// Minimal modern chat bubble — theme-aware (Mitra / Family / Partner…).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.theme = ChatTheme.classic,
    this.onReply,
    this.onLongPress,
    this.imageBuilder,
    this.videoBuilder,
    this.child,
  });

  final OjasMessage message;
  final bool isMine;
  final ChatTheme theme;
  final VoidCallback? onReply;
  final VoidCallback? onLongPress;
  final Widget Function()? imageBuilder;
  final Widget Function()? videoBuilder;
  final Widget? child;

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
    }

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
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          margin: EdgeInsets.only(
            left: isMine ? 48 : 12,
            right: isMine ? 12 : 48,
            top: 2,
            bottom: 2,
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
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
      ),
    );
  }
}
