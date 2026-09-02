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

  OjasMessage? _replyingTo;

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
        replyTo: _replyingTo,
      );

      _messageController.clear();

      if (mounted) {
        setState(() {
          _replyingTo = null;
        });
      }

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

  void _startReply(
    OjasMessage message,
  ) {
    if (message.isDeleted) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _replyingTo = message;
    });

    FocusScope.of(context).requestFocus(
      FocusNode(),
    );

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        FocusScope.of(context)
            .requestFocus(
          FocusNode(),
        );
      },
    );
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  Future<void> _reactToMessage(
    OjasMessage message,
    String emoji,
  ) async {
    try {
      HapticFeedback.selectionClick();

      await _messagingService.toggleReaction(
        conversationId:
            widget.conversationId,
        messageId: message.id,
        emoji: emoji,
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
                const SizedBox(height: 18),
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
                          FontWeight.w700,
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

      HapticFeedback.mediumImpact();
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
    }
  }

  void _copyMessage(
    OjasMessage message,
  ) {
    Clipboard.setData(
      ClipboardData(
        text: message.text,
      ),
    );

    HapticFeedback.selectionClick();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Message copied',
        ),
        duration: Duration(seconds: 2),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  void _showMessageActions(
    OjasMessage message,
    bool isMe,
  ) {
    if (message.isDeleted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              12,
              16,
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
                const SizedBox(height: 18),

                _buildReactionPicker(
                  message,
                  sheetContext,
                ),

                const SizedBox(height: 14),

                ListTile(
                  leading: const Icon(
                    Icons.reply_rounded,
                  ),
                  title: const Text(
                    'Reply',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _startReply(message);
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.copy_rounded,
                  ),
                  title: const Text(
                    'Copy',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _copyMessage(message);
                  },
                ),

                if (isMe)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);

                      _deleteMessage(message);
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(
                      Icons.flag_outlined,
                    ),
                    title: const Text(
                      'Report',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Report tools will be added in the safety phase.',
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

  Widget _buildReactionPicker(
    OjasMessage message,
    BuildContext sheetContext,
  ) {
    const reactions = [
      '❤️',
      '👍',
      '😂',
      '😮',
      '😢',
      '🔥',
    ];

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceEvenly,
        children: reactions.map(
          (emoji) {
            return InkWell(
              borderRadius:
                  BorderRadius.circular(24),
              onTap: () async {
                Navigator.pop(sheetContext);

                await _reactToMessage(
                  message,
                  emoji,
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.all(7),
                child: Text(
                  emoji,
                  style: const TextStyle(
                    fontSize: 24,
                  ),
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
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
                      (
                    context,
                    index,
                  ) {
                    final message =
                        messages[index];

                    final isMe =
                        message.isSentBy(
                      currentUid ?? '',
                    );

                    return _MessageBubble(
                      message: message,
                      isMe: isMe,
                      currentUid:
                          currentUid ?? '',
                      otherUserName:
                          widget.otherUser.displayName,
                      onLongPress: () {
                        _showMessageActions(
                          message,
                          isMe,
                        );
                      },
                      onReactionTap: (
                        emoji,
                      ) {
                        _reactToMessage(
                          message,
                          emoji,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          if (_replyingTo != null)
            _buildReplyPreview(),

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

  Widget _buildReplyPreview() {
    final reply = _replyingTo!;

    final isMe =
        reply.senderId ==
            _messagingService.currentUid;

    final name =
        isMe
            ? 'Replying to yourself'
            : 'Replying to ${widget.otherUser.displayName}';

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        16,
        10,
        8,
        10,
      ),
      decoration:
          const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFEDEDED),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 42,
            decoration: BoxDecoration(
              color:
                  const Color(0xFF111827),
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  reply.isDeleted
                      ? 'This message was deleted.'
                      : reply.text,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color:
                        Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            onPressed: _cancelReply,
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
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
                        'media',
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

    return 'Unable to complete this action. Please try again.';
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.currentUid,
    required this.otherUserName,
    required this.onLongPress,
    required this.onReactionTap,
  });

  final OjasMessage message;
  final bool isMe;
  final String currentUid;
  final String otherUserName;

  final VoidCallback onLongPress;

  final ValueChanged<String> onReactionTap;

  @override
  Widget build(BuildContext context) {
    final time =
        _formatTime(
      message.createdAt,
    );

    final summary =
        message.reactionSummary;

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Align(
        alignment: isMe
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            GestureDetector(
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
                  decoration:
                      BoxDecoration(
                    color: isMe
                        ? const Color(
                            0xFF111827,
                          )
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
                        CrossAxisAlignment.start,
                    children: [
                      if (message.hasReply)
                        _ReplyBubble(
                          message: message,
                          isMe: isMe,
                          otherUserName:
                              otherUserName,
                        ),

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
                        Align(
                          alignment:
                              Alignment.centerRight,
                          child: Padding(
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
                        ),
                    ],
                  ),
                ),
              ),
            ),

            if (summary.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 4,
                  left: 4,
                  right: 4,
                ),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children:
                      summary.entries.map(
                    (entry) {
                      final hasMyReaction =
                          message.reactionOf(
                                currentUid,
                              ) ==
                              entry.key;

                      return GestureDetector(
                        onTap: () {
                          onReactionTap(
                            entry.key,
                          );
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration:
                              BoxDecoration(
                            color: hasMyReaction
                                ? const Color(
                                    0xFFE8EAED,
                                  )
                                : Colors.white,
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                            border: Border.all(
                              color: hasMyReaction
                                  ? const Color(
                                      0xFF9CA3AF,
                                    )
                                  : const Color(
                                      0xFFE5E7EB,
                                    ),
                            ),
                          ),
                          child: Text(
                            '${entry.key} ${entry.value}',
                            style: const TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),
          ],
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

class _ReplyBubble extends StatelessWidget {
  const _ReplyBubble({
    required this.message,
    required this.isMe,
    required this.otherUserName,
  });

  final OjasMessage message;
  final bool isMe;
  final String otherUserName;

  @override
  Widget build(BuildContext context) {
    final repliedToMe =
        message.replyToSenderId ==
            MessagingService.instance.currentUid;

    final senderName =
        repliedToMe
            ? 'You'
            : otherUserName;

    final replyText =
        message.replyToText ??
            'Original message unavailable';

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.fromLTRB(
        9,
        7,
        9,
        7,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(
                alpha: 0.12,
              )
            : const Color(0xFFF5F6F8),
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white70
                  : const Color(
                      0xFF6B7280,
                    ),
              borderRadius:
                  BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w700,
                    color: isMe
                        ? Colors.white
                        : const Color(
                            0xFF111827,
                          ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyText,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe
                        ? Colors.white70
                        : const Color(
                            0xFF6B7280,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
