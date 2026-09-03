import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ojas_conversation.dart';
import '../models/ojas_message.dart';
import '../models/ojas_profile.dart';
import '../services/media_message_service.dart';
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

  final MediaMessageService _mediaMessageService =
      MediaMessageService.instance;

  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final FocusNode _messageFocusNode =
      FocusNode();

  OjasMessage? _replyingTo;

  bool _isSending = false;

  bool _isUploadingMedia = false;

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

    _messageFocusNode.dispose();

    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending ||
        _isUploadingMedia ||
        !_hasText) {
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

      _showError(
        _errorMessage(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAndSendImage(
    ImageSource source,
  ) async {
    if (_isUploadingMedia ||
        _isSending) {
      return;
    }

    try {
      XFile? image;

      if (source == ImageSource.camera) {
        image =
            await _mediaMessageService
                .pickImageFromCamera();
      } else {
        image =
            await _mediaMessageService
                .pickImageFromGallery();
      }

      if (image == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isUploadingMedia = true;
      });

      HapticFeedback.selectionClick();

      final result =
          await _mediaMessageService
              .uploadChatImage(
        conversationId:
            widget.conversationId,
        sourceFile: image,
      );

      final caption =
          _messageController.text.trim();

      await _messagingService.sendImageMessage(
        conversationId:
            widget.conversationId,
        receiverId:
            widget.otherUser.uid,
        imageUrl: result.downloadUrl,
        storagePath: result.storagePath,
        width: result.width,
        height: result.height,
        caption: caption,
        replyTo: _replyingTo,
      );

      _messageController.clear();

      if (mounted) {
        setState(() {
          _replyingTo = null;
        });
      }

      HapticFeedback.mediumImpact();

      await _messagingService.markConversationRead(
        widget.conversationId,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        _errorMessage(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
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

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (mounted) {
          _messageFocusNode.requestFocus();
        }
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

      _showError(
        _errorMessage(error),
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

      _showError(
        _errorMessage(error),
      );
    }
  }

  void _copyMessage(
    OjasMessage message,
  ) {
    if (message.text.trim().isEmpty) {
      return;
    }

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
  ) {
    final currentUid =
        _messagingService.currentUid;

    final isMe =
        currentUid == message.senderId;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
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
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final emoji in const [
                      '❤️',
                      '👍',
                      '😂',
                      '😮',
                      '😢',
                      '🔥',
                    ])
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(
                            sheetContext,
                          );

                          _reactToMessage(
                            message,
                            emoji,
                          );
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment:
                              Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                const Color(
                              0xFFF5F6F8,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.reply_rounded,
                  ),
                  title: const Text(
                    'Reply',
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _startReply(message);
                  },
                ),
                if (!message.isImage &&
                    message.text.trim().isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.copy_outlined,
                    ),
                    title: const Text(
                      'Copy',
                    ),
                    onTap: () {
                      Navigator.pop(
                        sheetContext,
                      );

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
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(
                        sheetContext,
                      );

                      _deleteMessage(message);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
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
                const SizedBox(height: 18),
                ListTile(
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFF4F5F7),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                    ),
                  ),
                  title: const Text(
                    'Photo library',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Choose a photo from your device',
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _pickAndSendImage(
                      ImageSource.gallery,
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFF4F5F7),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                    ),
                  ),
                  title: const Text(
                    'Camera',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Take a photo now',
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _pickAndSendImage(
                      ImageSource.camera,
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

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
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

    if (error is MediaMessageException) {
      return error.message;
    }

    return 'Unable to complete this action. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid =
        _messagingService.currentUid;

    return Scaffold(
      backgroundColor:
          const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor:
                  const Color(0xFFE5E7EB),
              child: Text(
                widget.otherUser.displayName
                    .trim()
                    .isNotEmpty
                    ? widget.otherUser.displayName
                        .trim()
                        .substring(0, 1)
                        .toUpperCase()
                    : 'O',
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    widget.otherUser.displayName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Color(0xFF111827),
                    ),
                  ),
                  if (widget.otherUser.ojasId
                      .trim()
                      .isNotEmpty)
                    Text(
                      '@${widget.otherUser.ojasId}',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color:
                            Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showMoreActions,
            icon: const Icon(
              Icons.more_horiz_rounded,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<OjasConversation>(
          stream: _messagingService.watchConversation(
            widget.conversationId,
          ),
          builder: (context, conversationSnapshot) {
            final conversation = conversationSnapshot.data;

            return StreamBuilder<List<OjasMessage>>(
                stream:
                    _messagingService.watchMessages(
                  widget.conversationId,
                ),
                builder: (
                  context,
                  snapshot,
                ) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 42,
                              color:
                                  Color(0xFF9CA3AF),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Unable to load messages',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Please try again.',
                              style: TextStyle(
                                color:
                                    Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    );
                  }

                  final messages =
                      snapshot.data!;

                  if (messages.isEmpty) {
                    return const _EmptyConversation();
                  }

                  final otherReadAt =
                  conversation?.lastReadAtFor(
                widget.otherUser.uid,
              );

              return ListView.builder(
                    controller:
                        _scrollController,
                    reverse: true,
                    padding:
                        const EdgeInsets.fromLTRB(
                      14,
                      20,
                      14,
                      16,
                    ),
                    itemCount:
                        messages.length,
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      final message =
                          messages[index];

                      final isMe =
                          currentUid != null &&
                              message.isSentBy(
                                currentUid,
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
                          );
                        },
                        seen: isMe &&
                          otherReadAt != null &&
                          message.createdAt != null &&
                          !message.createdAt!.toDate().isAfter(
                                otherReadAt.toDate(),
                              ),
                      onReactionTap: (emoji) {
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
              _ReplyComposer(
                message: _replyingTo!,
                otherUserName:
                    widget.otherUser.displayName,
                onCancel: _cancelReply,
              ),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      color: Colors.white,
      padding:
          const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        12,
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
                maxHeight: 120,
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
                focusNode:
                    _messageFocusNode,
                enabled:
                    !_isSending &&
                        !_isUploadingMedia,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization:
                    TextCapitalization.sentences,
                decoration:
                    const InputDecoration(
                  hintText:
                      'Message...',
                  counterText: '',
                  border:
                      InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                ),
                onSubmitted: (_) {
                  _sendMessage();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          _hasText
              ? Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF111827),
                    borderRadius:
                        BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed:
                        _isSending ||
                                _isUploadingMedia
                            ? null
                            : _sendMessage,
                    color: Colors.white,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                          ),
                  ),
                )
              : Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFF4F5F7),
                    borderRadius:
                        BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    tooltip: 'Send photo',
                    onPressed:
                        _isUploadingMedia
                            ? null
                            : _showMediaPicker,
                    icon:
                        _isUploadingMedia
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.add_circle_outline_rounded,
                                color:
                                    Color(0xFF111827),
                              ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color:
                    const Color(0xFFF1F3F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 34,
                color:
                    Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Start the conversation',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Send a message or share a photo.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({
    required this.message,
    required this.otherUserName,
    required this.onCancel,
  });

  final OjasMessage message;
  final String otherUserName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final currentUid =
        MessagingService.instance.currentUid;

    final repliedToMe =
        message.senderId == currentUid;

    final senderName =
        repliedToMe
            ? 'You'
            : otherUserName;

    final preview =
        message.isImage
            ? '📷 Photo'
            : message.text;

    return Container(
      color: Colors.white,
      padding:
          const EdgeInsets.fromLTRB(
        16,
        10,
        8,
        10,
      ),
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          12,
          8,
          4,
          8,
        ),
        decoration: BoxDecoration(
          color:
              const Color(0xFFF5F6F8),
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 38,
              decoration: BoxDecoration(
                color:
                    const Color(0xFF111827),
                borderRadius:
                    BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replying to $senderName',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview.isEmpty
                        ? 'Message'
                        : preview,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color:
                          Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onCancel,
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.currentUid,
    required this.otherUserName,
    required this.onLongPress,
    required this.seen,
    required this.onReactionTap,
  });

  final OjasMessage message;
  final bool isMe;
  final String currentUid;
  final String otherUserName;

  final VoidCallback onLongPress;

  final bool seen;

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
                      message.isImage &&
                              message.hasMedia
                          ? const EdgeInsets.fromLTRB(
                              5,
                              5,
                              5,
                              8,
                            )
                          : const EdgeInsets.fromLTRB(
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
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(
                            8,
                            5,
                            8,
                            0,
                          ),
                          child: _ReplyBubble(
                            message: message,
                            isMe: isMe,
                            otherUserName:
                                otherUserName,
                          ),
                        ),

                      if (message.isDeleted)
                        Padding(
                          padding:
                              const EdgeInsets.all(8),
                          child: Text(
                            'This message was deleted.',
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white70
                                  : const Color(
                                      0xFF6B7280,
                                    ),
                              fontSize: 15,
                              fontStyle:
                                  FontStyle.italic,
                            ),
                          ),
                        )
                      else ...[
                        if (message.isImage &&
                            message.hasMedia)
                          _ChatImage(
                            imageUrl:
                                message.mediaUrl!,
                            aspectRatio:
                                message.mediaAspectRatio,
                          ),

                        if (message.text
                            .trim()
                            .isNotEmpty)
                          Padding(
                            padding:
                                EdgeInsets.fromLTRB(
                              message.isImage ? 8 : 0,
                              message.isImage ? 8 : 0,
                              message.isImage ? 8 : 0,
                              0,
                            ),
                            child: Text(
                              message.text,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : const Color(
                                        0xFF111827,
                                      ),
                                fontSize: 15,
                                height: 1.35,
                              ),
                            ),
                          ),
                      ],

                      if (time.isNotEmpty)
                        Align(
                          alignment:
                              Alignment.centerRight,
                          child: Padding(
                            padding:
                                const EdgeInsets.only(
                              top: 5,
                              right: 6,
                            ),
                            child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
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
                  message.replyToType == 'image'
                      ? '📷 Photo'
                      : replyText,
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

class _ChatImage extends StatelessWidget {
  const _ChatImage({
    required this.imageUrl,
    required this.aspectRatio,
  });

  final String imageUrl;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final safeAspectRatio =
        aspectRatio.clamp(
      0.55,
      1.8,
    );

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                _FullScreenImage(
              imageUrl: imageUrl,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio:
              safeAspectRatio,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 1200,
            placeholder: (
              context,
              url,
            ) {
              return Container(
                color:
                    const Color(0xFFF1F3F5),
                child: const Center(
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              );
            },
            errorWidget: (
              context,
              url,
              error,
            ) {
              return Container(
                color:
                    const Color(0xFFF1F3F5),
                child: const Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 32,
                      color:
                          Color(0xFF9CA3AF),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Image unavailable',
                      style: TextStyle(
                        color:
                            Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
          },
        ),
        ),
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (
                  context,
                  url,
                ) {
                  return const Center(
                    child:
                        CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  );
                },
                errorWidget: (
                  context,
                  url,
                  error,
                ) {
                  return const Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 48,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Unable to load image',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.all(12),
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style:
                    IconButton.styleFrom(
                  backgroundColor:
                      Colors.black54,
                  foregroundColor:
                      Colors.white,
                ),
                icon: const Icon(
                  Icons.close_rounded,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
