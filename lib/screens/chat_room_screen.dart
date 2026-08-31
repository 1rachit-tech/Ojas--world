import 'package:flutter/material.dart';

// मैसेज का स्ट्रक्चर (डेटा मॉडल)
class ChatMessage {
  final String text;
  final bool isMe;
  final String time;

  ChatMessage({required this.text, required this.isMe, required this.time});
}

class ChatRoomScreen extends StatefulWidget {
  final String userName;
  final Color userColor;
  final IconData userIcon;

  const ChatRoomScreen({
    super.key,
    required this.userName,
    required this.userColor,
    required this.userIcon,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isTyping = false;

  // डमी मैसेज लिस्ट (ताकि स्क्रीन खाली न दिखे)
  final List<ChatMessage> _messages = [
    ChatMessage(text: 'I sent over the new storyboard.', isMe: false, time: '9:40 AM'),
    ChatMessage(text: 'Looks great! I will review it today.', isMe: true, time: '9:42 AM'),
  ];

  @override
  void initState() {
    super.initState();
    // जैसे ही यूज़र टाइप करेगा, सेंड/माइक बटन बदलेगा
    _messageController.addListener(() {
      setState(() {
        _isTyping = _messageController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // मैसेज भेजने का रियल फंक्शन
  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final now = DateTime.now();
    final timeString = "${now.hour > 12 ? now.hour - 12 : now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

    setState(() {
      // नया मैसेज लिस्ट में सबसे ऊपर (0 index) जोड़ें, क्योंकि लिस्ट रिवर्स है
      _messages.insert(
        0,
        ChatMessage(
          text: _messageController.text.trim(),
          isMe: true,
          time: timeString,
        ),
      );
    });

    _messageController.clear();
  }

  // एक्शन्स दिखाने के लिए फंक्शन
  void _showAction(String actionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$actionName action triggered!'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // बहुत हल्का ग्रे बैकग्राउंड
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // चैट लिस्ट
          Expanded(
            child: ListView.builder(
              reverse: true, // नए मैसेज नीचे से आएंगे
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          // टाइपिंग एरिया
          _buildMessageInput(),
        ],
      ),
    );
  }

  // टॉप बार (AppBar)
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      leadingWidth: 40,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: widget.userColor,
            child: Icon(widget.userIcon, color: Colors.black87, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(color: Color(0xFF111827), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Online',
                  style: TextStyle(color: Color(0xFF4ADE80), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_outlined, color: Color(0xFF111827)),
          onPressed: () => _showAction('Video Call'),
        ),
        IconButton(
          icon: const Icon(Icons.call_outlined, color: Color(0xFF111827)),
          onPressed: () => _showAction('Voice Call'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // मैसेज बबल्स (Chat UI)
  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 12,
              backgroundColor: widget.userColor.withValues(alpha: 0.5),
              child: Icon(widget.userIcon, size: 12, color: Colors.black87),
            ),
          if (!isMe) const SizedBox(width: 8),
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFF5B942) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? const Color(0xFF111827) : const Color(0xFF111827),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.time,
                    style: TextStyle(
                      color: isMe ? Colors.black54 : const Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFFF5B942)),
        ],
      ),
    );
  }

  // सबसे नीचे का टाइपिंग एरिया (Input Field)
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), // सुरक्षित एरिया के लिए पैडिंग
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // अटैचमेंट बटन
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6B7280), size: 28),
            onPressed: () => _showAction('Attachment'),
          ),
          
          // मैसेज बॉक्स
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF6B7280), size: 22),
                    onPressed: () => _showAction('Camera'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // सेंड / माइक बटन (डायनामिक)
          GestureDetector(
            onTap: _isTyping ? _sendMessage : () => _showAction('Voice Record'),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFF5B942), // OJAS Yellow
              child: Icon(
                _isTyping ? Icons.send_rounded : Icons.mic_none_rounded,
                color: const Color(0xFF111827),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

