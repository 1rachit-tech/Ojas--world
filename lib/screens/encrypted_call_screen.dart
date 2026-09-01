import 'dart:async';
import 'package:flutter/material.dart';

class EncryptedCallScreen extends StatefulWidget {
  final String peerName;
  final String peerHandle;
  final bool isVideoCall;
  final String sessionKey;

  const EncryptedCallScreen({
    super.key,
    required this.peerName,
    required this.peerHandle,
    this.isVideoCall = true,
    required this.sessionKey,
  });

  static void startCall(
    BuildContext context, {
    required String peerName,
    required String peerHandle,
    bool isVideoCall = true,
    required String sessionKey,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EncryptedCallScreen(
          peerName: peerName,
          peerHandle: peerHandle,
          isVideoCall: isVideoCall,
          sessionKey: sessionKey,
        ),
      ),
    );
  }

  @override
  State<EncryptedCallScreen> createState() => _EncryptedCallScreenState();
}

class _EncryptedCallScreenState extends State<EncryptedCallScreen> {
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  int _callSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSecs) {
    final mins = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSecs % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final shortKey = widget.sessionKey.substring(0, 8).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Center Avatar / Video Area
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: const Color(0xFF1E293B),
                    child: Text(
                      widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 42, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.peerName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDuration(_callSeconds),
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            // 2. End-to-End Encryption Security Badge (Top Bar)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_rounded, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'End-to-End Encrypted ($shortKey)',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Call Action Controls (Bottom Bar)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  _buildCallBtn(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    isActive: _isMuted,
                    onTap: () => setState(() => _isMuted = !_isMuted),
                  ),
                  // Video Toggle (if Video Call)
                  if (widget.isVideoCall)
                    _buildCallBtn(
                      icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      isActive: _isCameraOff,
                      onTap: () => setState(() => _isCameraOff = !_isCameraOff),
                    ),
                  // Speaker
                  _buildCallBtn(
                    icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    isActive: _isSpeakerOn,
                    onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                  ),
                  // End Call Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallBtn({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : const Color(0xFF1E293B),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? const Color(0xFF0F172A) : Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
