import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ojas_message.dart';
import '../models/ojas_profile.dart';
import '../services/messaging_service.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    required this.otherUser,
  });

  final String conversationId;

  final OjasProfile otherUser;

  @override
  State<ChatRoomScreen> createState() =>
      _ChatRoomScreenState();
}

class _ChatRoomScreenState
    extends State<ChatRoomScreen> {
  final MessagingService _messagingService =
      MessagingService.instance;

  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  bool _isSending = false;

  bool get _hasText =>
      _messageController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    _messageController.addListener(
      _onTextChanged,
    );

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        _messagingService.markConversationRead(
          widget.conversationId,
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.removeListener(
      _onTextChanged,
    );

    _messageController.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending || !_hasText) {
      return;
    }

    final text =
        _messageController.text.trim();

    setState(() {
      _isSending = true;
    });

    try {
      await _messagingService.sendTextMessage(
        conversationId:
            widget.conversationId,
        receiverId:
            widget.otherUser.uid,
        text: text,
      );

      _messageController.clear();

      HapticFeedback.lightImpact();

      await _messagingService.markConversationRead(
        widget.conversationId,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            _errorMessage(error),
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _deleteMessage(
    OjasMessage message,
  ) async {
    final confirm =
        await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFE5E7EB),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Delete message',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      true,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await _messagingService.deleteMessage(
        conversationId:
            widget.conversationId,
        messageId: message.id,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to delete message.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid =
        _messagingService.currentUid;

    return Scaffold(
      backgroundColor:
          const Color(0xFFFAFAFA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child:
                StreamBuilder<List<OjasMessage>>(
              stream:
                  _messagingService.watchMessages(
                widget.conversationId,
              ),
              builder: (
                context,
                snapshot,
              ) {
                if (snapshot.hasData) {
                  WidgetsBinding.instance
                      .addPostFrameCallback(
                    (_) {
                      _messagingService
                          .markConversationRead(
                        widget.conversationId,
                      );
                    },
                  );
                }

                if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Unable to load messages.',
                    ),
                  );
                }

                final messages =
                    snapshot.data ?? [];

                if (messages.isEmpty) {
                  return _buildEmptyChat();
                }

                return ListView.builder(
                  controller:
                      _scrollController,
                  reverse: true,
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    20,
                    16,
                    20,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior
                          .onDrag,
                  itemCount:
                      messages.length,
                  itemBuilder:
                      (context, index) {
                    final message =
                        messages[index];

                    final isMe =
                        message.isSentBy(
                      currentUid ?? '',
                    );

                    return _MessageBubble(
                      message: message,
                      isMe: isMe,
                      onLongPress:
                          isMe && !message.isDeleted
                              ? () {
                                  _deleteMessage(
                                    message,
                                  );
                                }
                              : null,
                    );
                  },
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final photoUrl =
        widget.otherUser.photoUrl.trim();

    final initial =
        widget.otherUser.displayName
                .trim()
                .isEmpty
            ? 'O'
            : widget.otherUser.displayName
                .trim()[0]
                .toUpperCase();

    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor:
          Colors.transparent,
      elevation: 0,
      leadingWidth: 48,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () {
          Navigator.pop(context);
        },
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Color(0xFF111827),
          size: 20,
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor:
                const Color(0xFFF1F3F5),
            backgroundImage:
                photoUrl.startsWith('http')
                    ? NetworkImage(photoUrl)
                    : null,
            child:
                photoUrl.startsWith('http')
                    ? null
                    : Text(
                        initial,
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.w800,
                          color:
                              Color(0xFF111827),
                        ),
                      ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.otherUser.displayName,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:
                              Color(0xFF111827),
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                    if (widget.otherUser.isVerified)
                      const Padding(
                        padding:
                            EdgeInsets.only(
                          left: 4,
                        ),
                        child: Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color:
                              Color(0xFF3B82F6),
                        ),
                      ),
                  ],
                ),
                Text(
                  widget.otherUser.ojasId.isEmpty
                      ? 'OJAS'
                      : '@${widget.otherUser.ojasId}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'More',
          onPressed: _showMoreActions,
          icon: const Icon(
            Icons.more_horiz_rounded,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 40,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor:
                  const Color(0xFFF1F3F5),
              child: Text(
                widget.otherUser.displayName
                        .trim()
                        .isEmpty
                    ? 'O'
                    : widget.otherUser.displayName
                        .trim()[0]
                        .toUpperCase(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.otherUser.displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Start your conversation',
              style: TextStyle(
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          12,
        ),
        decoration:
            const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Color(0xFFF0F0F0),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints:
                    const BoxConstraints(
                  minHeight: 48,
                  maxHeight: 130,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFF4F5F7),
                  borderRadius:
                      BorderRadius.circular(24),
                ),
                child: TextField(
                  controller:
                      _messageController,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization:
                      TextCapitalization.sentences,
                  textInputAction:
                      TextInputAction.newline,
                  decoration:
                      const InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration:
                  const Duration(milliseconds: 160),
              child: _hasText
                  ? IconButton(
                      key: const ValueKey(
                        'send',
                      ),
                      tooltip: 'Send',
                      onPressed:
                          _isSending
                              ? null
                              : _sendMessage,
                      style:
                          IconButton.styleFrom(
                        backgroundColor:
                            const Color(
                          0xFF111827,
                        ),
                        foregroundColor:
                            Colors.white,
                      ),
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                            ),
                    )
                  : IconButton(
                      key: const ValueKey(
                        'camera',
                      ),
                      tooltip:
                          'Media coming soon',
                      onPressed:
                          _showMediaComingSoon,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color:
                            Color(0xFF111827),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFE5E7EB),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline_rounded,
                  ),
                  title: const Text(
                    'Conversation info',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_off_outlined,
                  ),
                  title: const Text(
                    'Mute notifications',
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Notification controls are coming soon.',
                        ),
                        behavior:
                            SnackBarBehavior
                                .floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMediaComingSoon() {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Photo, video and voice messages are the next upgrade.',
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  String _errorMessage(
    Object error,
  ) {
    if (error is MessagingException) {
      return error.message;
    }

    return 'Unable to send message. Please try again.';
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.onLongPress,
  });

  final OjasMessage message;

  final bool isMe;

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final time =
        _formatTime(
      message.createdAt,
    );

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Align(
        alignment: isMe
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(
              maxWidth:
                  MediaQuery.of(context)
                          .size
                          .width *
                      0.76,
            ),
            child: Container(
              padding:
                  const EdgeInsets.fromLTRB(
                14,
                10,
                14,
                8,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF111827)
                    : Colors.white,
                borderRadius:
                    BorderRadius.only(
                  topLeft:
                      const Radius.circular(18),
                  topRight:
                      const Radius.circular(18),
                  bottomLeft:
                      Radius.circular(
                    isMe ? 18 : 4,
                  ),
                  bottomRight:
                      Radius.circular(
                    isMe ? 4 : 18,
                  ),
                ),
                border: isMe
                    ? null
                    : Border.all(
                        color:
                            const Color(
                          0xFFEAEAEA,
                        ),
                      ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    message.isDeleted
                        ? 'This message was deleted.'
                        : message.text,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : const Color(
                              0xFF111827,
                            ),
                      fontSize: 15,
                      height: 1.35,
                      fontStyle:
                          message.isDeleted
                              ? FontStyle.italic
                              : FontStyle.normal,
                    ),
                  ),
                  if (time.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 5,
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white70
                              : const Color(
                                  0xFF9CA3AF,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTime(
    Timestamp? timestamp,
  ) {
    if (timestamp == null) {
      return '';
    }

    final date =
        timestamp.toDate();

    final hour =
        date.hour > 12
            ? date.hour - 12
            : date.hour == 0
                ? 12
                : date.hour;

    final minute =
        date.minute
            .toString()
            .padLeft(2, '0');

    final period =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $period';
  }
}
