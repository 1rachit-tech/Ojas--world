import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_theme.dart';
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
import '../services/safety_service.dart';
import '../widgets/message_bubble.dart';
import 'encrypted_call_screen.dart';

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
  final MessagePaginationService _paginationService =
      MessagePaginationService.instance;
  final RealtimePresenceService _presenceService =
      RealtimePresenceService.instance;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<OjasMessage> _loadedMessages = <OjasMessage>[];
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<RealtimePresenceState>? _presenceSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _conversationSubscription;
  Timer? _typingTimer;

  bool _isSending = false;
  bool _isUploadingMedia = false;
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  bool _otherUserOnline = false;
  bool _didInitialLoad = false;
  bool _recording = false;
  bool _uploadingAudio = false;
  ChatTheme _chatTheme = ChatTheme.classic;

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
        if (mounted) setState(() => _otherUserOnline = state.online);
      },
      onError: (_) {},
    );

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
          isTyping = typingBy[otherUid] == true;
        }
        if (_otherUserTyping != isTyping) {
          setState(() => _otherUserTyping = isTyping);
        }
      },
      onError: (_) {},
    );

    unawaited(_loadChatTheme());
    unawaited(_loadInitialMessages());
    _markRead();
  }

  Future<void> _loadChatTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('chat_theme_${widget.conversationId}');
      if (!mounted) return;
      setState(() => _chatTheme = ChatTheme.byId(id));
    } catch (_) {}
  }

  Future<void> _saveChatTheme(ChatTheme theme) async {
    setState(() => _chatTheme = theme);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_theme_${widget.conversationId}', theme.id);
    } catch (_) {}
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
    if (_recording) unawaited(_recorder.stop());
    unawaited(_recorder.dispose());
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
          ..addAll(MessageMemoryWindow.takeNewest(page.messages, _initialPageSize));
        _paginationCursor = page.cursor;
        _hasMoreOlder = page.hasMore;
        _didInitialLoad = true;
      });
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingOlder || !_hasMoreOlder) return;
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
      final existingIds = _loadedMessages.map((m) => m.id).toSet();
      final additions = page.messages.where((m) => !existingIds.contains(m.id));
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
    return MessageMemoryWindow.takeNewest(messages, _maxInMemoryMessages);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
    if (!_hasText) {
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

  Future<void> _startRecording() async {
    if (_isSending || _isUploadingMedia || _uploadingAudio || _recording) return;
    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted || !await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission required for voice notes.'),
            ),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/ojas_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 22050,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) {
        unawaited(_recorder.stop());
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() => _recording = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start voice recording.')),
        );
      }
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    if (!_recording) return;
    setState(() => _recording = false);
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      return;
    }
    if (!send || path == null || path.isEmpty) return;
    await _uploadVoice(path);
  }

  Future<void> _uploadVoice(String localPath) async {
    final file = File(localPath);
    if (!await file.exists() || _uploadingAudio) return;
    setState(() => _uploadingAudio = true);
    try {
      final bytes = await file.length();
      final storagePath =
          'chat_media/audio/${widget.conversationId}/${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putFile(file, SettableMetadata(contentType: 'audio/mp4'));
      final url = await ref.getDownloadURL();
      await _messagingService.sendAudioMessage(
        conversationId: widget.conversationId,
        receiverId: widget.otherUser.uid,
        mediaUrl: url,
        storagePath: storagePath,
        mediaBytes: bytes,
        replyTo: _replyingTo,
      );
      if (mounted) setState(() => _replyingTo = null);
      HapticFeedback.lightImpact();
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      if (mounted) setState(() => _uploadingAudio = false);
    }
  }

  void _showSafetyMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.block_rounded, color: Color(0xFFDC2626)),
                title: const Text('Block user'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await SafetyService.instance.blockUser(
                      targetUid: widget.otherUser.uid,
                      displayName: widget.otherUser.displayName,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User blocked')),
                      );
                      Navigator.of(context).maybePop();
                    }
                  } catch (e) {
                    if (mounted) _showError(_errorMessage(e));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report user'),
                onTap: () {
                  Navigator.pop(context);
                  _showReportSheet();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportSheet() {
    const reasons = [
      'Spam',
      'Harassment',
      'Inappropriate content',
      'Scam or fraud',
      'Other',
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Report reason',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              for (final reason in reasons)
                ListTile(
                  title: Text(reason),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await SafetyService.instance.reportUser(
                        targetUid: widget.otherUser.uid,
                        reason: reason,
                        conversationId: widget.conversationId,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report submitted. Thank you.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) _showError(_errorMessage(e));
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _startCall({required bool isVideo}) {
    HapticFeedback.mediumImpact();
    final key =
        '${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}';
    EncryptedCallScreen.startCall(
      context,
      peerName: widget.otherUser.displayName.isEmpty
          ? 'OJAS User'
          : widget.otherUser.displayName,
      peerHandle:
          widget.otherUser.ojasId.isEmpty ? 'ojas' : widget.otherUser.ojasId,
      isVideoCall: isVideo,
      sessionKey: key,
    );
  }

  Future<void> _reactToMessage(OjasMessage message, String emoji) async {
    try {
      await _messagingService.toggleReaction(
        conversationId: widget.conversationId,
        messageId: message.id,
        emoji: emoji,
      );
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    }
  }

  void _showReactionSheet(OjasMessage message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          _chatTheme.isDark ? const Color(0xFF111827) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final emoji in MessageBubble.quickReactions)
                      _ReactionEmojiButton(
                        emoji: emoji,
                        onTap: () {
                          Navigator.pop(context);
                          HapticFeedback.selectionClick();
                          unawaited(_reactToMessage(message, emoji));
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.reply_rounded, color: _chatTheme.accent),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _replyingTo = message);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _errorMessage(Object error) {
    if (error is MessagingException) return error.message;
    if (error is SafetyException) return error.message;
    if (error is ChatVideoMediaException) return error.message;
    if (error is FirebaseException) {
      return error.message ?? 'Message action failed.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _showError(String message) {
    _lastError = message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildImageBubble(OjasMessage message) {
    final url = message.mediaUrl;
    if (url == null || url.trim().isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: 250,
      height: 250,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 900,
        maxWidthDiskCache: 1200,
        placeholder: (_, __) => const Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }

  Widget _buildVideoBubble(OjasMessage message) {
    final url = message.mediaUrl;
    if (url == null || url.trim().isEmpty) return const SizedBox.shrink();
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
            const Icon(Icons.play_circle_fill_rounded,
                color: Colors.white, size: 58),
            Positioned(
              left: 12,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    final theme = _chatTheme;
    final fg = theme.isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.appBarTint,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: BackButton(color: fg),
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFF0F2F5),
              backgroundImage: _usableImage(widget.otherUser.photoUrl)
                  ? NetworkImage(widget.otherUser.photoUrl)
                  : null,
              child: _usableImage(widget.otherUser.photoUrl)
                  ? null
                  : const Icon(Icons.person_outline_rounded,
                      color: Color(0xFF6B7280), size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.displayName.isEmpty
                        ? 'OJAS User'
                        : widget.otherUser.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _otherUserOnline
                        ? 'Online'
                        : (widget.otherUser.ojasId.isEmpty
                            ? 'OJAS'
                            : '@${widget.otherUser.ojasId}'),
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
              tooltip: 'Audio call',
              onPressed: () => _startCall(isVideo: false),
              icon: Icon(Icons.call_outlined, color: fg, size: 22),
            ),
            IconButton(
              tooltip: 'Video call',
              onPressed: () => _startCall(isVideo: true),
              icon: Icon(Icons.videocam_outlined, color: fg, size: 24),
            ),
            IconButton(
              tooltip: 'Chat theme',
              onPressed: _showThemePicker,
              icon: Icon(Icons.palette_outlined, color: fg, size: 22),
            ),
            IconButton(
              tooltip: 'More',
              onPressed: _showSafetyMenu,
              icon: Icon(Icons.more_vert_rounded, color: fg, size: 22),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_otherUserTyping)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.theirsBubble,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'typing…',
                      style: TextStyle(
                        color: theme.theirsText.withValues(alpha: 0.7),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: StreamBuilder<List<OjasMessage>>(
                stream: _messagingService.watchMessages(widget.conversationId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text(_errorMessage(snapshot.error!)));
                  }

                  final messages = _mergeMessages(
                    snapshot.data ?? const <OjasMessage>[],
                  );
                  final currentUid = _messagingService.currentUid;

                  _markDelivered(messages, currentUid);

                  if (messages.any((m) => m.senderId != currentUid)) {
                    _markRead();
                  }

                  if (!_didInitialLoad &&
                      snapshot.connectionState == ConnectionState.waiting &&
                      messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'Say hi to ${widget.otherUser.displayName.isEmpty ? 'them' : widget.otherUser.displayName}',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 15,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                    itemCount: messages.length + (_isLoadingOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoadingOlder && index == messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final message = messages[index];
                      final isMine = message.senderId == currentUid;

                      return MessageBubble(
                        message: message,
                        isMine: isMine,
                        theme: _chatTheme,
                        currentUid: currentUid,
                        onReply: () => setState(() => _replyingTo = message),
                        onLongPress: message.isDeleted
                            ? null
                            : () => _showReactionSheet(message),
                        onReact: message.isDeleted
                            ? null
                            : (emoji) =>
                                unawaited(_reactToMessage(message, emoji)),
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
            if (_recording)
              Container(
                width: double.infinity,
                color: const Color(0xFFFEF2F2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.mic_rounded,
                        color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Recording… release to send',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => unawaited(_stopRecording(send: false)),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            if (_uploadingAudio) const LinearProgressIndicator(minHeight: 2),
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
      decoration: BoxDecoration(
        color: _chatTheme.composerFill,
        border: Border(
          top: BorderSide(
            color: _chatTheme.isDark
                ? const Color(0xFF374151)
                : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: _chatTheme.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.reply_rounded, size: 16, color: _chatTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reply.text.isEmpty
                  ? (reply.isImage
                      ? 'Photo'
                      : reply.isVideo
                          ? 'Video'
                          : reply.isAudio
                              ? 'Voice note'
                              : 'Message')
                  : reply.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _chatTheme.isDark
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFF374151),
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
    final canSend = _hasText && !_isSending && !_isUploadingMedia;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: _chatTheme.appBarTint,
          border: Border(
            top: BorderSide(
              color: _chatTheme.isDark
                  ? const Color(0xFF374151)
                  : const Color(0xFFEEEEEE),
              width: 0.6,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Attach',
              onPressed:
                  _isUploadingMedia || _isSending ? null : _showAttachSheet,
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: _chatTheme.accent,
                size: 28,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (canSend) _sendMessage();
                },
                style: TextStyle(
                  fontSize: 15.5,
                  color: _chatTheme.isDark
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFF111827),
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  hintText: _recording ? 'Recording…' : 'Message…',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 15.5,
                  ),
                  filled: true,
                  fillColor: _chatTheme.composerFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: _chatTheme.accent.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: canSend
                  ? Material(
                      color: _chatTheme.accent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _sendMessage,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: _isSending ||
                                    _isUploadingMedia ||
                                    _uploadingAudio
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onLongPressStart: (_) => unawaited(_startRecording()),
                      onLongPressEnd: (_) =>
                          unawaited(_stopRecording(send: true)),
                      onLongPressCancel: () =>
                          unawaited(_stopRecording(send: false)),
                      child: Material(
                        color: _recording
                            ? const Color(0xFFDC2626)
                            : (_chatTheme.isDark
                                ? const Color(0xFF374151)
                                : const Color(0xFFE5E7EB)),
                        shape: const CircleBorder(),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            _recording
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            size: 20,
                            color: _recording
                                ? Colors.white
                                : (_chatTheme.isDark
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFF6B7280)),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Photo library'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Camera'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: const Text('Video'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendVideo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showThemePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          _chatTheme.isDark ? const Color(0xFF111827) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text(
                  'Chat theme',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _chatTheme.isDark
                        ? Colors.white
                        : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mitra, family, partner — set the vibe for this chat',
                  style: TextStyle(
                    fontSize: 13,
                    color: _chatTheme.isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in ChatTheme.all)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          HapticFeedback.selectionClick();
                          unawaited(_saveChatTheme(item));
                        },
                        child: Container(
                          width: 96,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: item.theirsBubble,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _chatTheme.id == item.id
                                  ? item.accent
                                  : item.accent.withValues(alpha: 0.25),
                              width: _chatTheme.id == item.id ? 2.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(item.emoji,
                                  style: const TextStyle(fontSize: 22)),
                              const SizedBox(height: 6),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: item.theirsText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _usableImage(String value) {
    return value.trim().isNotEmpty &&
        (value.startsWith('http://') || value.startsWith('https://'));
  }
}

class _ReactionEmojiButton extends StatefulWidget {
  const _ReactionEmojiButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  State<_ReactionEmojiButton> createState() => _ReactionEmojiButtonState();
}

class _ReactionEmojiButtonState extends State<_ReactionEmojiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.85,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.reverse(),
      onTapUp: (_) {
        _c.forward();
        widget.onTap();
      },
      onTapCancel: () => _c.forward(),
      child: ScaleTransition(
        scale: _c,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 30)),
        ),
      ),
    );
  }
}
