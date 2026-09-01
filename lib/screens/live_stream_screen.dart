import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/coin_store_modal.dart';
import '../widgets/live_gift_animation_overlay.dart';

class LiveStreamScreen extends StatefulWidget {
  final String streamerName;
  final String streamerHandle;

  const LiveStreamScreen({
    super.key,
    required this.streamerName,
    required this.streamerHandle,
  });

  static void open(BuildContext context, {required String streamerName, required String streamerHandle}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveStreamScreen(
          streamerName: streamerName,
          streamerHandle: streamerHandle,
        ),
      ),
    );
  }

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  int _userCoins = 450;
  bool _isFollowing = false;

  Map<String, String>? _activeGift;

  final List<Map<String, String>> _messages = [
    {'user': 'Sneha', 'text': 'Super excited for the live! 🔥'},
    {'user': 'Rohan', 'text': 'Vindhya vibes in the stream 🎧'},
    {'user': 'Maya', 'text': 'Audio clarity is 10/10 ✨'},
  ];

  final List<Map<String, String>> _gifts = [
    {'name': 'Heart', 'emoji': '❤️', 'coins': '10'},
    {'name': 'Fire', 'emoji': '🔥', 'coins': '50'},
    {'name': 'Crown', 'emoji': '👑', 'coins': '200'},
    {'name': 'Rocket', 'emoji': '🚀', 'coins': '500'},
  ];

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'user': 'You', 'text': text});
    });
    _chatCtrl.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openGiftSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Send Live Gift',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    CoinStoreModal.show(
                      context,
                      currentBalance: _userCoins,
                      onPurchaseSuccess: (added) => setState(() => _userCoins += added),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 15),
                        const SizedBox(width: 4),
                        Text(
                          '$_userCoins Coins +',
                          style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _gifts.map((g) {
                final cost = int.parse(g['coins']!);
                return GestureDetector(
                  onTap: () {
                    if (_userCoins >= cost) {
                      setState(() {
                        _userCoins -= cost;
                        _activeGift = {
                          'sender': 'You',
                          'name': g['name']!,
                          'emoji': g['emoji']!,
                        };
                      });
                      Navigator.pop(ctx);
                    } else {
                      Navigator.pop(ctx);
                      CoinStoreModal.show(
                        context,
                        currentBalance: _userCoins,
                        onPurchaseSuccess: (added) => setState(() => _userCoins += added),
                      );
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(g['emoji']!, style: const TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(height: 6),
                      Text(g['name']!, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 12),
                          const SizedBox(width: 2),
                          Text('${g['coins']}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Background Video Stream Simulation
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
            child: const Center(
              child: Icon(Icons.live_tv_rounded, size: 72, color: Colors.white12),
            ),
          ),

          // 2. Gift Flying Animation
          if (_activeGift != null)
            Positioned(
              left: 20,
              top: MediaQuery.of(context).size.height * 0.40,
              child: LiveGiftAnimationOverlay(
                senderName: _activeGift!['sender']!,
                giftName: _activeGift!['name']!,
                giftEmoji: _activeGift!['emoji']!,
                onDismiss: () => setState(() => _activeGift = null),
              ),
            ),

          // 3. Top Info Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  // Streamer Capsule
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF111827),
                          child: Text(
                            widget.streamerName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.streamerName,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'LIVE',
                              style: TextStyle(color: Color(0xFFEF4444), fontSize: 9.5, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        if (!_isFollowing)
                          GestureDetector(
                            onTap: () => setState(() => _isFollowing = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('Follow', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Viewer Counter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(14)),
                    child: const Row(
                      children: [
                        Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 14),
                        SizedBox(width: 4),
                        Text('1.8K', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // 4. Live Chat Stream
          Positioned(
            left: 14,
            bottom: 84,
            right: 80,
            child: SizedBox(
              height: 220,
              child: ListView.builder(
                controller: _scrollCtrl,
                itemCount: _messages.length,
                itemBuilder: (context, idx) {
                  final msg = _messages[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${msg['user']}: ',
                            style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          TextSpan(
                            text: msg['text'],
                            style: const TextStyle(color: Colors.white, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 5. Bottom Live Action Controls
          Positioned(
            left: 14,
            right: 14,
            bottom: 20,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: TextField(
                      controller: _chatCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Say something in live...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 12.5),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendChat(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  onPressed: _sendChat,
                ),
                GestureDetector(
                  onTap: _openGiftSheet,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                    child: const Icon(Icons.card_giftcard_rounded, color: Colors.black, size: 20),
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
