import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ojas_conversation.dart';
import '../models/ojas_message.dart';
import '../models/ojas_profile.dart';
import '../services/media_message_service.dart';
import '../services/message_delivery_service.dart';
import '../services/message_memory_window.dart';
import '../services/message_pagination_service.dart';
import '../services/messaging_service.dart';
import '../services/realtime_presence_service.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    required this.otherUser,
  });

  final String conversationId;
  final OjasProfile otherUser;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  static const int _maxInMemoryMessages = 400;

  final MessagingService _messagingService = MessagingService.instance;
  final MediaMessageService _mediaMessageService = MediaMessageService.instance;
  final MessageDeliveryService _deliveryService = MessageDeliveryService.instance;
  final MessagePaginationService _paginationService =
      MessagePaginationService.instance;
  final RealtimePresenceService _presenceService =
      RealtimePresenceService.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  OjasMessage? _replyingTo;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isSending = false;
  bool _isUploadingMedia = false;

  final List<OjasMessage> _loadedMessages = <OjasMessage>[];
  DocumentSnapshot<Map<String, dynamic>>? _paginationCursor;
  bool _hasMoreOlder = true;
  bool _isLoadingOlder = false;
  bool _paginationInitialized = false;
  Timestamp? _lastDeliveredAt;

  bool get _hasText => _messageController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messagingService.registerPresenceConversation(widget.conversationId);
    unawaited(_presenceService.start());
    _messageController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRead();
      unawaited(_initializePagination());
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    if (_isTyping) {
      unawaited(_messagingService.setTyping(
        conversationId: widget.conversationId,
        isTyping: false,
      ));
    }
    _messagingService.unregisterPresenceConversation(widget.conversationId);
    unawaited(_presenceService.stop());
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLoadingOlder ||
        !_paginationInitialized ||
        !_hasMoreOlder) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _initializePagination() async {
    if (_paginationInitialized) {
      return;
    }

    try {
      final page = await _paginationService.loadPage(
        conversationId: widget.conversationId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loadedMessages
          ..clear()
          ..addAll(
            MessageMemoryWindow.takeNewest(
              page.messages,
              _maxInMemoryMessages,
            ),
          );
        _paginationCursor = page.cursor;
        _hasMoreOlder = page.hasMore;
        _paginationInitialized = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _paginationInitialized = true);
      _showError(_errorMessage(error));
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlder || !_hasMoreOlder || !_paginationInitialized) {
      return;
    }

    final cursor = _paginationCursor;
    if (cursor == null && _loadedMessages.isNotEmpty) {
      return;
    }

    setState(() => _isLoadingOlder = true);

    try {
      final page = await _paginationService.loadPage(
        conversationId: widget.conversationId,
        cursor: cursor,
      );

      if (!mounted) {
        return;
      }

      final existingIds = _loadedMessages.map((message) => message.id).toSet();
      final additions = page.messages.where(
        (message) => !existingIds.contains(message.id),
      );
      final combined = <OjasMessage>[...\_loadedMessages, ...additions];

      setState(() {
        _loadedMessages
          ..clear()
          ..addAll(
            MessageMemoryWindow.takeNewest(
              combined,
              _maxInMemoryMessages,
            ),
          );
        _paginationCursor = page.cursor;
        _hasMoreOlder = page.hasMore;
      });
    } catch (error) {
      if (mounted) {
        _showError(_errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingOlder = false);
      }
    }
  }

  List<OjasMessage> _mergeMessages(List<OjasMessage> liveMessages) {
    final byId = <String, OjasMessage>{};
    for (final message in _loadedMessages) {
      byId[message.id] = message;
    }
    for (final message in liveMessages) {
      byId[message.id] = message;
    }

    final messages = byId.values.toList();
    messages.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null && bTime == null) {
        return 0;
      }
      if (aTime == null) {
        return -1;
      }
      if (bTime == null) {
        return 1;
      }
      return bTime.compareTo(aTime);
    });

    return MessageMemoryWindow.takeNewest(messages, _maxInMemoryMessages);
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }

    final hasText = _messageController.text.trim().isNotEmpty;
    if (!hasText) {
      _setTyping(false);
      return;
    }

    _setTyping(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(
      const Duration(milliseconds: 1800),
      () => _setTyping(false),
    );
  }

  void _setTyping(bool value) {
    if (_isTyping == value) {
      return;
    }
    _isTyping = value;
    unawaited(_messagingService.setTyping(
      conversationId: widget.conversationId,
      isTyping: value,
    ));
  }

  void _markRead() {
    unawaited(_messagingService.markConversationRead(widget.conversationId));
  }

  void _markDelivered(List<OjasMessage> messages, String? currentUid) {
    if (currentUid == null) {
      return;
    }

    Timestamp? newestIncoming;
    for (final message in messages) {
      if (message.senderId == currentUid || message.createdAt == null) {
        continue;
      }
      final createdAt = message.createdAt!;
      if (newestIncoming == null || createdAt.compareTo(newestIncoming) > 0) {
        newestIncoming = createdAt;
      }
    }

    if (newestIncoming == null) {
      return;
    }
    if (_lastDeliveredAt != null &&
        newestIncoming.compareTo(_lastDeliveredAt!) <= 0) {
      return;
    }

    _lastDeliveredAt = newestIncoming;
    unawaited(_deliveryService.markDeliveredUntil(
      conversationId: widget.conversationId,
      messageCreatedAt: newestIncoming,
    ));
  }

  Future<void> _sendMessage() async {
    if (_isSending || _isUploadingMedia || !_hasText) {
      return;
    }

    final text = _messageController.text.trim();
    _typingTimer?.cancel();
    _setTyping(false);
    setState(() => _isSending = true);

    try {
      await _messagingService.sendTextMessage(
        conversationId: widget.conversationId,
        receiverId: widget.otherUser.uid,
        text: text,
        replyTo: _replyingTo,
      );
      _messageController.clear();
      if (mounted) {
        setState(() => _replyingTo = null);
      }
      HapticFeedback.lightImpact();
      _markRead();
    } catch (error) {
      if (mounted) {
        _showError(_errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_isUploadingMedia || _isSending) {
      return;
    }

    _typingTimer?.cancel();
    _setTyping(false);

    try {
      final image = source == ImageSource.camera
          ? await _mediaMessageService.pickImageFromCamera()
          : await _mediaMessageService.pickImageFromGallery();
      if (image == null) {
        return;
      }

      if (mounted) {
        setState(() => _isUploadingMedia = true);
      }

      HapticFeedback.selectionClick();
      final result = await _mediaMessageService.uploadChatImage(
        conversationId: widget.conversationId,
        sourceFile: image,
      );

      await _messagingService.sendImageMessage(
        conversationId: widget.conversationId,
        receiverId: widget.otherUser.uid,
        imageUrl: result.downloadUrl,
        storagePath: result.storagePath,
        width: result.width,
        height: result.height,
        mediaBytes: result.compressedBytes,
        caption: _messageController.text.trim(),
        replyTo: _replyingTo,
      );

      _messageController.clear();
      if (mounted) {
        setState(() => _replyingTo = null);
      }
      HapticFeedback.mediumImpact();
      _markRead();
    } catch (error) {
      if (mounted) {
        _showError(_errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  void _startReply(OjasMessage message) {
    if (message.isDeleted) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _replyingTo = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _messageFocusNode.requestFocus();
      }
    });
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _reactToMessage(OjasMessage message, String emoji) async {
    try {
      HapticFeedback.selectionClick();
      await _messagingService.toggleReaction(
        conversationId: widget.conversationId,
        messageId: message.id,
        emoji: emoji,
      );
    } catch (error) {
      if (mounted) {
        _showError(_errorMessage(error));
      }
    }
  }

  Future<void> _deleteMessage(OjasMessage message) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          title: const Text(
            'Delete message',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _messagingService.deleteMessage(
        conversationId: widget.conversationId,
        messageId: message.id,
      );
      HapticFeedback.mediumImpact();
    } catch (error) {
      if (mounted) {
        _showError(_errorMessage(error));
      }
    }
  }

  void _copyMessage(OjasMessage message) {
    if (message.text.trim().isEmpty) {
      return;
    }
    Clipboard.setData(ClipboardData(text: message.text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMessageActions(OjasMessage message) {
    final currentUid = _messagingService.currentUid;
    final isMe = currentUid == message.senderId;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 10,
                children: [
                  for (final emoji in const ['❤️', '👍', '😂', '😮', '😢', '🔥'])
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _reactToMessage(message, emoji);
                      },
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6F8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 23)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startReply(message);
                },
              ),
              if (!message.isImage && message.text.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_outlined),
                  title: const Text('Copy'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _copyMessage(message);
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deleteMessage(message);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photo library'),
                subtitle: const Text('Choose a photo from your device'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                subtitle: const Text('Take a photo now'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _errorMessage(Object error) {
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
    final currentUid = _messagingService.currentUid;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFFE5E7EB),
              child: Text(
                _initial(widget.otherUser.displayName),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<OjasConversation>(
                stream: _messagingService.watchConversation(widget.conversationId),
                builder: (context, conversationSnapshot) {
                  final conversation = conversationSnapshot.data;
                  return StreamBuilder<RealtimePresenceState>(
                    stream: _presenceService.watch(widget.otherUser.uid),
                    builder: (context, presenceSnapshot) {
                      final presence = presenceSnapshot.data;
                      final typing = conversation?.isTyping(widget.otherUser.uid) ?? false;
                      final online = presence?.online ??
                          (conversation?.isOnline(widget.otherUser.uid) ?? false);
                      final lastActiveAt = presence?.lastChanged != null
                          ? Timestamp.fromDate(presence!.lastChanged!)
                          : conversation?.lastActiveAtFor(widget.otherUser.uid);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.otherUser.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            typing
                                ? 'typing…'
                                : online
                                    ? 'Online'
                                    : _formatLastSeen(lastActiveAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: typing
                                  ? const Color(0xFF2563EB)
                                  : online
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF6B7280),
                              fontWeight: typing || online
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<OjasConversation>(
                stream: _messagingService.watchConversation(widget.conversationId),
                builder: (context, conversationSnapshot) {
                  final conversation = conversationSnapshot.data;
                  final otherReadAt = conversation?.lastReadAtFor(widget.otherUser.uid);
                  final deliveredAt = conversation?.deliveredAtFor(widget.otherUser.uid);

                  return StreamBuilder<List<OjasMessage>>(
                    stream: _messagingService.watchMessages(widget.conversationId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const _MessageLoadError();
                      }
                      if (!snapshot.hasData && !_paginationInitialized) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }

                      final messages = _mergeMessages(
                        snapshot.data ?? const <OjasMessage>[],
                      );
                      _markDelivered(messages, currentUid);

                      if (messages.isEmpty && _paginationInitialized) {
                        return const _EmptyConversation();
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
                        itemCount: messages.length +
                            (_isLoadingOlder || _hasMoreOlder ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Center(
                                child: _isLoadingOlder
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(
                                        'Scroll for older messages',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                              ),
                            );
                          }

                          final message = messages[index];
                          final isMe = currentUid != null && message.isSentBy(currentUid);
                          final createdAt = message.createdAt;
                          final seen = isMe &&
                              otherReadAt != null &&
                              createdAt != null &&
                              !createdAt.toDate().isAfter(otherReadAt.toDate());
                          final delivered = isMe &&
                              !seen &&
                              deliveredAt != null &&
                              createdAt != null &&
                              !createdAt.toDate().isAfter(deliveredAt.toDate());
                          final sending = isMe && createdAt == null;

                          return _MessageBubble(
                            message: message,
                            isMe: isMe,
                            sending: sending,
                            delivered: delivered,
                            seen: seen,
                            currentUid: currentUid ?? '',
                            otherUserName: widget.otherUser.displayName,
                            onLongPress: () => _showMessageActions(message),
                            onReactionTap: (emoji) => _reactToMessage(message, emoji),
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
                otherUserName: widget.otherUser.displayName,
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                enabled: !_isSending && !_isUploadingMedia,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Message...',
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _hasText
              ? Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed: _isSending || _isUploadingMedia ? null : _sendMessage,
                    color: Colors.white,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                )
              : Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F7),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    tooltip: 'Send photo',
                    onPressed: _isUploadingMedia ? null : _showMediaPicker,
                    icon: _isUploadingMedia
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF111827)),
                  ),
                ),
        ],
      ),
    );
  }

  static String _initial(String name) {
    final clean = name.trim();
    return clean.isEmpty ? 'O' : clean.substring(0, 1).toUpperCase();
  }

  static String _formatLastSeen(Timestamp? timestamp) {
    if (timestamp == null) return 'Last seen recently';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final difference = today.difference(dateOnly).inDays;
    final time = _formatTime(timestamp);
    if (difference == 0) return 'Last seen $time';
    if (difference == 1) return 'Last seen yesterday $time';
    return 'Last seen ${date.day} ${_monthName(date.month)} $time';
  }

  static String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  static String _monthName(int month) {
    const months = <String>['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[(month - 1).clamp(0, 11)];
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.sending,
    required this.delivered,
    required this.seen,
    required this.currentUid,
    required this.otherUserName,
    required this.onLongPress,
    required this.onReactionTap,
  });

  final OjasMessage message;
  final bool isMe;
  final bool sending;
  final bool delivered;
  final bool seen;
  final String currentUid;
  final String otherUserName;
  final VoidCallback onLongPress;
  final ValueChanged<String> onReactionTap;

  @override
  Widget build(BuildContext context) {
    final summary = message.reactionSummary;
    final time = _ChatTime.format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: onLongPress,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                child: Container(
                  padding: message.isImage && message.hasMedia
                      ? const EdgeInsets.fromLTRB(5, 5, 5, 8)
                      : const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF111827) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    border: isMe ? null : Border.all(color: const Color(0xFFEAEAEA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.hasReply)
                        _ReplyBubble(
                          message: message,
                          isMe: isMe,
                          otherUserName: otherUserName,
                        ),
                      if (message.isDeleted)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'This message was deleted.',
                            style: TextStyle(
                              color: isMe ? Colors.white70 : const Color(0xFF6B7280),
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else ...[
                        if (message.isImage && message.hasMedia)
                          _ChatImage(
                            imageUrl: message.mediaUrl!,
                            aspectRatio: message.mediaAspectRatio,
                          ),
                        if (message.text.trim().isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              message.isImage ? 8 : 0,
                              message.isImage ? 8 : 0,
                              message.isImage ? 8 : 0,
                              0,
                            ),
                            child: Text(
                              message.text,
                              style: TextStyle(
                                color: isMe ? Colors.white : const Color(0xFF111827),
                                fontSize: 15,
                                height: 1.35,
                              ),
                            ),
                          ),
                      ],
                      if (time.isNotEmpty || sending)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (time.isNotEmpty)
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe ? Colors.white70 : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              if (isMe) ...[
                                if (time.isNotEmpty) const SizedBox(width: 4),
                                if (sending)
                                  const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(strokeWidth: 1.7, color: Colors.white70),
                                  )
                                else
                                  Icon(
                                    seen || delivered ? Icons.done_all_rounded : Icons.done_rounded,
                                    size: 15,
                                    color: seen ? const Color(0xFF60A5FA) : Colors.white70,
                                  ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: summary.entries.map((entry) {
                    final mine = message.reactionOf(currentUid) == entry.key;
                    return GestureDetector(
                      onTap: () => onReactionTap(entry.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: mine ? const Color(0xFFE8EAED) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: mine ? const Color(0xFF9CA3AF) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text('${entry.key} ${entry.value}', style: const TextStyle(fontSize: 12)),
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

class _ChatTime {
  static String format(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _ReplyBubble extends StatelessWidget {
  const _ReplyBubble({required this.message, required this.isMe, required this.otherUserName});
  final OjasMessage message;
  final bool isMe;
  final String otherUserName;

  @override
  Widget build(BuildContext context) {
    final currentUid = MessagingService.instance.currentUid;
    final senderName = message.replyToSenderId == currentUid ? 'You' : otherUserName;
    final replyText = message.replyToText ?? 'Original message unavailable';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: isMe ? Colors.white70 : const Color(0xFF6B7280),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(senderName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isMe ? Colors.white : const Color(0xFF111827))),
                const SizedBox(height: 2),
                Text(
                  message.replyToType == 'image' ? '📷 Photo' : replyText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : const Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({required this.message, required this.otherUserName, required this.onCancel});
  final OjasMessage message;
  final String otherUserName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final currentUid = MessagingService.instance.currentUid;
    final senderName = message.senderId == currentUid ? 'You' : otherUserName;
    final preview = message.isImage ? '📷 Photo' : message.text;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(color: const Color(0xFFF5F6F8), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 38,
              decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Replying to $senderName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text(preview.trim().isEmpty ? 'Message' : preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            IconButton(onPressed: onCancel, icon: const Icon(Icons.close_rounded, size: 20)),
          ],
        ),
      ),
    );
  }
}

class _ChatImage extends StatelessWidget {
  const _ChatImage({required this.imageUrl, required this.aspectRatio});
  final String imageUrl;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _FullScreenImage(imageUrl: imageUrl)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: aspectRatio.clamp(0.55, 1.8),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 900,
            maxWidthDiskCache: 1200,
            maxHeightDiskCache: 1440,
            placeholder: (context, url) => Container(
              color: const Color(0xFFF1F3F5),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (context, url, error) => Container(
              color: const Color(0xFFF1F3F5),
              child: const Center(child: Icon(Icons.broken_image_outlined, size: 32, color: Color(0xFF9CA3AF))),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.imageUrl});
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
                memCacheWidth: 1600,
                maxWidthDiskCache: 1920,
                maxHeightDiskCache: 1920,
                placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                icon: const Icon(Icons.close_rounded),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Color(0xFF6B7280)),
            SizedBox(height: 14),
            Text('Start the conversation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Send a message to say hello.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

class _MessageLoadError extends StatelessWidget {
  const _MessageLoadError();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 42, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text('Unable to load messages', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Please try again.', style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}
