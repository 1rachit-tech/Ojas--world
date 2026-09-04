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
  final List<OjasMessage> _loadedMessages = <OjasMessage>[];

  StreamSubscription<RealtimePresenceState>? _presenceSubscription;
  Timer? _typingTimer;
  bool _isSending = false;
  bool _isUploadingMedia = false;
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;
  bool _isTyping = false;
  bool _otherUserOnline = false;
  bool _didInitialLoad = false;
  OjasMessage? _replyingTo;
  DocumentSnapshot<Map<String, dynamic>>? _paginationCursor;
  Timestamp? _lastDeliveredAt;
  String? _lastError;

  bool get _hasText => _messageController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
    _presenceSubscription = _presenceService.watch(widget.otherUser.uid).listen(
      (state) {
        if (mounted) {
          setState(() => _otherUserOnline = state.online);
        }
      },
      onError: (_) {},
    );
    _markRead();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _presenceSubscription?.cancel();
    _messageController
      ..removeListener(_onTextChanged)
      ..dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _setTyping(false);
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLoadingOlder ||
        !_hasMoreOlder ||
        _scrollController.position.extentAfter > 200) {
      return;
    }
    unawaited(_loadOlderMessages());
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlder || !_hasMoreOlder) return;
    setState(() => _isLoadingOlder = true);
    try {
      final page = await _paginationService.loadPage(
        conversationId: widget.conversationId,
        cursor: _paginationCursor,
      );
      final existingIds = _loadedMessages.map((message) => message.id).toSet();
      final additions = page.messages.where(
        (message) => !existingIds.contains(message.id),
      );
      final combined = <OjasMessage>[..._loadedMessages, ...additions];
      if (!mounted) return;
      setState(() {
        _loadedMessages
          ..clear()
          ..addAll(MessageMemoryWindow.takeNewest(combined, _maxInMemoryMessages));
        _paginationCursor = page.cursor;
        _hasMoreOlder = page.hasMore;
      });
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoadingOlder = false);
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
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return -1;
      if (bTime == null) return 1;
      return bTime.compareTo(aTime);
    });
    return MessageMemoryWindow.takeNewest(messages, _maxInMemoryMessages);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
    final hasText = _hasText;
    if (!hasText) {
      _setTyping(false);
      return;
    }
    _setTyping(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 1800), () => _setTyping(false));
  }

  void _setTyping(bool value) {
    if (_isTyping == value) return;
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
    if (currentUid == null) return;
    Timestamp? newestIncoming;
    for (final message in messages) {
      if (message.senderId == currentUid || message.createdAt == null) continue;
      final createdAt = message.createdAt!;
      if (newestIncoming == null || createdAt.compareTo(newestIncoming) > 0) {
        newestIncoming = createdAt;
      }
    }
    if (newestIncoming == null) return;
    if (_lastDeliveredAt != null && newestIncoming.compareTo(_lastDeliveredAt!) <= 0) return;
    _lastDeliveredAt = newestIncoming;
    unawaited(_deliveryService.markDeliveredUntil(
      conversationId: widget.conversationId,
      messageCreatedAt: newestIncoming,
    ));
  }

  Future<void> _sendMessage() async {
    if (_isSending || _isUploadingMedia || !_hasText) return;
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
      if (mounted) setState(() => _replyingTo = null);
      HapticFeedback.lightImpact();
      _markRead();
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_isUploadingMedia || _isSending) return;
    _typingTimer?.cancel();
    _setTyping(false);
    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) return;
      if (mounted) setState(() => _isUploadingMedia = true);
      final uploaded = await _mediaMessageService.uploadChatImage(
        sourceFile: picked,
        conversationId: widget.conversationId,
      );
      await _messagingService.sendImageMessage(
        conversationId: widget.conversationId,
        receiverId: widget.otherUser.uid,
        mediaUrl: uploaded.downloadUrl,
        storagePath: uploaded.storagePath,
        width: uploaded.width,
        height: uploaded.height,
        mediaBytes: uploaded.compressedBytes,
        caption: null,
        replyTo: _replyingTo,
      );
      if (mounted) setState(() => _replyingTo = null);
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  String _errorMessage(Object error) {
    if (error is MessagingException) return error.message;
    if (error is FirebaseException) return error.message ?? 'Message action failed.';
    return 'Something went wrong. Please try again.';
  }

  void _showError(String message) {
    _lastError = message;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildMessageBubble(OjasMessage message, String? currentUid) {
    final isMine = message.senderId == currentUid;
    final text = message.isDeleted ? 'This message was deleted.' : message.text;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => setState(() => _replyingTo = message),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: isMine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.replyToText != null && message.replyToText!.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(message.replyToText!, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
              if (message.isImage && message.mediaUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(imageUrl: message.mediaUrl!),
                ),
              if (text.isNotEmpty) Text(text),
              if (isMine)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    message.status == 'seen'
                      ? 'Seen'
                      : message.status == 'delivered'
                        ? 'Delivered'
                        : 'Sent',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUser.displayName),
            Text(_otherUserOnline ? 'Online' : 'Offline', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<OjasMessage>>(
                stream: _messagingService.watchMessages(widget.conversationId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text(_errorMessage(snapshot.error!)));
                  }
                  final messages = _mergeMessages(snapshot.data ?? const <OjasMessage>[]);
                  final currentUid = _messagingService.currentUid;
                  _markDelivered(messages, currentUid);
                  if (messages.any((message) => message.senderId != currentUid)) _markRead();
                  if (snapshot.connectionState == ConnectionState.waiting && messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: messages.length + (_isLoadingOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoadingOlder && index == messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _buildMessageBubble(messages[index], currentUid);
                    },
                  );
                },
              ),
            ),
            if (_replyingTo != null)
              Material(
                child: ListTile(
                  title: Text('Replying to ${_replyingTo!.senderId == _messagingService.currentUid ? 'yourself' : widget.otherUser.displayName}'),
                  subtitle: Text(_replyingTo!.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _replyingTo = null)),
                ),
              ),
            if (_lastError != null) const SizedBox.shrink(),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _isUploadingMedia ? null : () => _pickAndSendImage(ImageSource.gallery),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Message'),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
