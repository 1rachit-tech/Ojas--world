import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ojas_conversation.dart';
import '../models/ojas_message.dart';
import '../models/ojas_profile.dart';
import '../services/chat_video_media_service.dart';
import '../services/chat_video_message_service.dart';
import '../services/media_message_service.dart';
import '../services/message_delivery_service.dart';
import '../services/message_memory_window.dart';
import '../services/message_pagination_service.dart';
import '../services/messaging_service.dart';
import '../services/realtime_presence_service.dart';
import '../widgets/message_bubble.dart';

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
  static const int _initialPageSize = 20;

  final MessagingService _messagingService = MessagingService.instance;
  final MediaMessageService _mediaMessageService = MediaMessageService.instance;
  final ChatVideoMediaService _chatVideoMediaService =
      ChatVideoMediaService.instance;
  final ChatVideoMessageService _chatVideoMessageService =
      ChatVideoMessageService.instance;
  final MessageDeliveryService _deliveryService = MessageDeliveryService.instance;
  final MessagePaginationService _paginationService = MessagePaginationService.instance;
  final RealtimePresenceService _presenceService = RealtimePresenceService.instance;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<OjasMessage> _loadedMessages = <OjasMessage>[];

  StreamSubscription<RealtimePresenceState>? _presenceSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _conversationSubscription;
  Timer? _typingTimer;

  bool _isSending = false;
  bool _isUploadingMedia = false;
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;
  bool _isTyping = false;
  bool _otherUserTyping = false;
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

    // Watch other user's typing indicator from the conversation document.
    _conversationSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted || !snapshot.exists) return;
        final data = snapshot.data();
        if (data == null) return;
        final typingBy = data['typingBy'];
        final otherUid = widget.otherUser.uid;
        var isTyping = false;
        if (typingBy is Map && otherUid.isNotEmpty) {
          final value = typingBy[otherUid];
          isTyping = value == true;
        }
        if (_otherUserTyping != isTyping) {
          setState(() => _otherUserTyping = isTyping);
        }
      },
      onError: (_) {},
    );

    unawaited(_loadInitialMessages());
    _markRead();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _presenceSubscription?.cancel();
    _conversationSubscription?.cancel();
    _messageController
      ..removeListener(_onTextChanged)
      ..dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _setTyping(false);
    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    if (_didInitialLoad) return;

    try {
      final page = await _paginationService.loadPage(
        conversationId: widget.conversationId,
      );

      if (!mounted) return;

      setState(() {
        _loadedMessages
          ..clear()
          ..addAll(
            MessageMemoryWindow.takeNewest(
              page.messages,
              _initialPageSize,
            ),
          );
        _paginationCursor = page.cursor;
        _hasMoreOlder = page.hasMore;
        _didInitialLoad = true;
      });
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLoadingOlder ||
        !_hasMoreOlder) {
      return;
    }

    // reverse:true: extentBefore is the distance toward older messages.
    if (_scrollController.position.extentBefore <= 220) {
      unawaited(_loadOlderMessages());
    }
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

    // The realtime stream is intentionally bounded to the newest page.
    // Older history is owned by cursor pagination above.
    for (final message in liveMessages.take(_initialPageSize)) {
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

    return MessageMemoryWindow.takeNewest(
      messages,
      _maxInMemoryMessages,
    );
  }

  void _onTextChanged() {
    if (mounted) setState(() {});

    if (!_hasText) {
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
    if (_isTyping == value) return;
    _isTyping = value;

    unawaited(
      _messagingService.setTyping(
        conversationId: widget.conversationId,
        isTyping: value,
      ),
    );
  }

  void _markRead() {
    unawaited(
      _messagingService.markConversationRead(
        widget.conversationId,
      ),
    );
  }

  void _markDelivered(List<OjasMessage> messages, String? currentUid) {
    if (currentUid == null) return;

    Timestamp? newestIncoming;

    for (final message in messages) {
      if (message.senderId == currentUid || message.createdAt == null) {
        continue;
      }

      final createdAt = message.createdAt!;

      if (newestIncoming == null ||
          createdAt.compareTo(newestIncoming) > 0) {
        newestIncoming = createdAt;
      }
    }

    if (newestIncoming == null) return;

    if (_lastDeliveredAt != null &&
        newestIncoming.compareTo(_lastDeliveredAt!) <= 0) {
      return;
    }

    _lastDeliveredAt = newestIncoming;

    unawaited(
      _deliveryService.markDeliveredUntil(
        conversationId: widget.conversationId,
        messageCreatedAt: newestIncoming,
      ),
    );
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

      // Keep the existing image media pipeline unchanged.
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
        caption: '',
        replyTo: _replyingTo,
      );

      if (mounted) setState(() => _replyingTo = null);
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _pickAndSendVideo() async {
    if (_isUploadingMedia || _isSending) return;

    _typingTimer?.cancel();
    _setTyping(false);

    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked == null) return;

      if (mounted) setState(() => _isUploadingMedia = true);

      final uploaded = await _chatVideoMediaService.prepareAndUpload(
        sourceFile: picked,
        conversationId: widget.conversationId,
      );

      await _chatVideoMessageService.sendVideoMessage(
        conversationId: widget.conversationId,
        receiverId: widget.otherUser.uid,
        mediaUrl: uploaded.mediaUrl,
        mediaHash: uploaded.mediaHash,
        mediaStoragePath: uploaded.storagePath,
        mediaBytes: uploaded.mediaBytes,
        width: uploaded.width,
        height: uploaded.height,
        durationMs: uploaded.durationMs,
        replyTo: _replyingTo,
      );

      if (mounted) setState(() => _replyingTo = null);
      HapticFeedback.lightImpact();
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  String _errorMessage(Object error) {
    if (error is MessagingException) return error.message;
    if (error is ChatVideoMediaException) return error.message;
    if (error is FirebaseException) {
      return error.message ?? 'Message action failed.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _showError(String message) {
    _lastError = message;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildImageBubble(OjasMessage message) {
    final url = message.mediaUrl;

    if (url == null || url.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 250,
      height: 250,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 900,
        maxWidthDiskCache: 1200,
        placeholder: (_, _) => const Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }

  Widget _buildVideoBubble(OjasMessage message) {
    final url = message.mediaUrl;

    if (url == null || url.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 260,
      height: 170,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 58,
            ),
            Positioned(
              left: 12,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'VIDEO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: const BackButton(color: Color(0xFF111827)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFF0F2F5),
              backgroundImage:
                  _usableImage(widget.otherUser.photoUrl)
                      ? NetworkImage(widget.otherUser.photoUrl)
                      : null,
              child: _usableImage(widget.otherUser.photoUrl)
                  ? null
                  : const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF6B7280),
                      size: 19,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _otherUserOnline
                        ? 'Online'
                        : '@${widget.otherUser.ojasId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _otherUserOnline
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF6B7280),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'More',
              onPressed: () {},
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_otherUserTyping)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 4, 18, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Typing…',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: StreamBuilder<List<OjasMessage>>(
                stream: _messagingService.watchMessages(
                  widget.conversationId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(_errorMessage(snapshot.error!)),
                    );
                  }

                  final messages = _mergeMessages(
                    snapshot.data ?? const <OjasMessage>[],
                  );
                  final currentUid = _messagingService.currentUid;

                  _markDelivered(messages, currentUid);

                  if (messages.any(
                    (message) => message.senderId != currentUid,
                  )) {
                    _markRead();
                  }

                  if (!_didInitialLoad &&
                      snapshot.connectionState ==
                          ConnectionState.waiting &&
                      messages.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                    itemCount:
                        messages.length + (_isLoadingOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoadingOlder && index == messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        );
                      }

                      final message = messages[index];
                      final isMine = message.senderId == currentUid;

                      return MessageBubble(
                        message: message,
                        isMine: isMine,
                        onReply: () {
                          setState(() => _replyingTo = message);
                        },
                        imageBuilder: message.isImage
                            ? () => _buildImageBubble(message)
                            : null,
                        videoBuilder: message.isVideo
                            ? () => _buildVideoBubble(message)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            if (_replyingTo != null) _buildReplyBar(),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBar() {
    final reply = _replyingTo!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F5F7),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 18, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reply.text.isEmpty
                  ? (reply.isImage
                      ? 'Photo'
                      : reply.isVideo
                          ? 'Video'
                          : 'Message')
                  : reply.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            onPressed: () => setState(() => _replyingTo = null),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Photo',
              onPressed: _isUploadingMedia || _isSending
                  ? null
                  : () => _pickAndSendImage(ImageSource.gallery),
              icon: const Icon(Icons.image_outlined, color: Color(0xFF111827)),
            ),
            IconButton(
              tooltip: 'Camera',
              onPressed: _isUploadingMedia || _isSending
                  ? null
                  : () => _pickAndSendImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined, color: Color(0xFF111827)),
            ),
            IconButton(
              tooltip: 'Video',
              onPressed: _isUploadingMedia || _isSending
                  ? null
                  : _pickAndSendVideo,
              icon: const Icon(Icons.videocam_outlined, color: Color(0xFF111827)),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: const Color(0xFFF4F5F7),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Send',
              onPressed: (_hasText && !_isSending && !_isUploadingMedia)
                  ? _sendMessage
                  : null,
              icon: _isSending || _isUploadingMedia
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: Color(0xFF111827)),
            ),
          ],
        ),
      ),
    );
  }

  bool _usableImage(String value) {
    return value.trim().isNotEmpty &&
        (value.startsWith('http://') || value.startsWith('https://'));
  }
}
