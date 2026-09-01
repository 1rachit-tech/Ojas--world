import 'package:flutter/material.dart';
import '../services/encryption_service.dart';
import 'encrypted_call_screen.dart';

class ChatConversationScreen extends StatefulWidget {
  final String userName;
  final String userHandle;
  final Color avatarColor;

  const ChatConversationScreen({
    super.key,
    required this.userName,
    required this.userHandle,
    required this.avatarColor,
  });

  static void open(
    BuildContext context, {
    required String userName,
    required String userHandle,
    required Color avatarColor,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          userName: userName,
          userHandle: userHandle,
          avatarColor: avatarColor,
        ),
      ),
    );
  }

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isRecordingVoice = false;
  bool _isViewOnceSelected = false;
  late String _sessionKey;

  final List<Map<String, dynamic>> _messages = [
    {
      'isMe': false,
      'type': 'text',
      'cipherText': '',
      'plainText': 'Hey Akash! Loved your new folk fusion track ✨',
      'time': '10:30 AM',
      'isViewOnce': false,
      'isOpened': false,
    },
    {
      'isMe': true,
      'type': 'text',
      'cipherText': '',
      'plainText': 'Thanks Maya! Recording the next reel with 35mm lens.',
      'time': '10:32 AM',
      'isViewOnce': false,
      'isOpened': false,
    },
    {
      'isMe': false,
      'type': 'voice',
      'cipherText': '',
      'plainText': 'Voice Note',
      'duration': '0:18',
      'time': '10:35 AM',
      'isViewOnce': false,
      'isOpened': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _sessionKey = EncryptionService.instance.generateCallSessionKey('me', widget.userHandle);
    
    // Encrypt Initial Messages Demo
    for (final m in _messages) {
      m['cipherText'] = EncryptionService.instance.encryptPayload(
        plainText: m['plainText'] as String,
        secretKey: _sessionKey,
      );
    }
  }

  void _sendMessage({String type = 'text', String? extraContent}) {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && type == 'text') return;

    final rawContent = type == 'text' ? text : 'Voice Note ($extraContent)';
    final encrypted = EncryptionService.instance.encryptPayload(
      plainText: rawContent,
      secretKey: _sessionKey,
    );

    setState(() {
      _messages.add({
        'isMe': true,
        'type': type,
        'cipherText': encrypted,
        'plainText': rawContent,
        'duration': extraContent ?? '0:12',
        'time': 'Just now',
        'isViewOnce': _isViewOnceSelected,
        'isOpened': false,
      });
      _isViewOnceSelected = false;
    });

    _msgCtrl.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startEncryptedCall({required bool isVideo}) {
    EncryptedCallScreen.startCall(
      context,
      peerName: widget.userName,
      peerHandle: widget.userHandle,
      isVideoCall: isVideo,
      sessionKey: _sessionKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.avatarColor,
              child: Text(
                widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.userName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF111827), fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.lock_rounded, color: Color(0xFF10B981), size: 12),
                    ],
                  ),
                  const Text(
                    'End-to-End Encrypted',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Encrypted Audio Call',
            icon: const Icon(Icons.call_outlined, color: Color(0xFF111827), size: 23),
            onPressed: () => _startEncryptedCall(isVideo: false),
          ),
          IconButton(
            tooltip: 'Encrypted Video Call',
            icon: const Icon(Icons.videocam_outlined, color: Color(0xFF111827), size: 26),
            onPressed: () => _startEncryptedCall(isVideo: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. E2EE Info Security Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: const Color(0xFFF0FDF4),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 13),
                SizedBox(width: 6),
                Text(
                  'Messages and calls are end-to-end encrypted.',
                  style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // 2. Messages Stream
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final bool isMe = msg['isMe'] as bool;
                final String type = msg['type'] as String;
                final bool isViewOnce = msg['isViewOnce'] as bool? ?? false;
                final bool isOpened = msg['isOpened'] as bool? ?? false;

                // Decrypt for UI presentation
                final decryptedText = EncryptionService.instance.decryptPayload(
                  cipherText: msg['cipherText'] as String,
                  secretKey: _sessionKey,
                );

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                    ),
                    child: isViewOnce
                        ? GestureDetector(
                            onTap: () {
                              if (!isOpened) {
                                setState(() => msg['isOpened'] = true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Viewing 1-Time Encrypted Media 📸'), duration: Duration(seconds: 2)),
                                );
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOpened ? Icons.lock_open_rounded : Icons.lock_rounded,
                                  color: isMe ? Colors.white70 : const Color(0xFF111827),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isOpened ? 'Opened Photo' : '1-Time View Photo',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : const Color(0xFF111827),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : type == 'voice'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded, color: isMe ? Colors.white : const Color(0xFF111827), size: 24),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 80,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: isMe ? Colors.white38 : const Color(0xFFD1D5DB),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    msg['duration'] as String,
                                    style: TextStyle(
                                      color: isMe ? Colors.white70 : const Color(0xFF6B7280),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    decryptedText,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : const Color(0xFF111827),
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg['time'] as String,
                                    style: TextStyle(
                                      color: isMe ? Colors.white54 : const Color(0xFF9CA3AF),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                  ),
                );
              },
            ),
          ),

          // 3. Message Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isViewOnceSelected ? Icons.timer_rounded : Icons.timer_outlined,
                      color: _isViewOnceSelected ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() => _isViewOnceSelected = !_isViewOnceSelected);
                    },
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                        decoration: const InputDecoration(
                          hintText: 'Encrypted message...',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onLongPressStart: (_) => setState(() => _isRecordingVoice = true),
                    onLongPressEnd: (_) {
                      setState(() => _isRecordingVoice = false);
                      _sendMessage(type: 'voice', extraContent: '0:08');
                    },
                    child: IconButton(
                      icon: Icon(
                        _isRecordingVoice ? Icons.mic_rounded : Icons.send_rounded,
                        color: _isRecordingVoice ? const Color(0xFFEF4444) : const Color(0xFF111827),
                        size: 24,
                      ),
                      onPressed: () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
