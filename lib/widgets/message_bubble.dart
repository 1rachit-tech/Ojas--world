import 'package:flutter/material.dart';

import '../models/ojas_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onLongPress,
    this.child,
  });

  final OjasMessage message;
  final bool isMine;
  final VoidCallback? onLongPress;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = isMine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = isMine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final displayText = message.isDeleted
        ? 'This message was deleted.'
        : message.text;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 330),
          margin: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 3,
          ),
          padding: const EdgeInsets.fromLTRB(5, 5, 8, 5),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 5),
              bottomRight: Radius.circular(isMine ? 5 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.replyToText != null &&
                  message.replyToText!.trim().isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message.replyToText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground.withValues(alpha: 0.78),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              if (child != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: child,
                ),
              if (displayText.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 15.5,
                      height: 1.32,
                      fontStyle: message.isDeleted
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
              if (isMine)
                Padding(
                  padding: const EdgeInsets.only(
                    right: 5,
                    bottom: 2,
                  ),
                  child: Text(
                    _statusLabel(message.status),
                    style: TextStyle(
                      color: foreground.withValues(alpha: 0.72),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'seen':
        return 'Seen';
      case 'delivered':
        return 'Delivered';
      default:
        return 'Sent';
    }
  }
}
