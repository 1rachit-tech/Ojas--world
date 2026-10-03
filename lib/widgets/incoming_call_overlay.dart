import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/livekit_call_screen.dart';
import '../services/call_signaling_service.dart';
import '../services/incoming_call_service.dart';

/// Full-screen ring UI when a call invite arrives while the app is open.
class IncomingCallOverlay extends StatelessWidget {
  const IncomingCallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final service = IncomingCallService.instance;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final call = service.activeCall;
        if (call == null) return const SizedBox.shrink();
        return _IncomingCallPanel(call: call);
      },
    );
  }
}

class _IncomingCallPanel extends StatelessWidget {
  const _IncomingCallPanel({required this.call});

  final IncomingCallInfo call;

  Future<void> _decline(BuildContext context) async {
    HapticFeedback.mediumImpact();
    if (call.callId.isNotEmpty && call.callId != 'unknown') {
      await CallSignalingService.instance.endCall(
        conversationId: call.conversationId,
        callId: call.callId,
        status: 'declined',
      );
    }
    IncomingCallService.instance.clear();
  }

  Future<void> _accept(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final info = call;
    IncomingCallService.instance.clear();
    if (info.callId.isNotEmpty && info.callId != 'unknown') {
      await CallSignalingService.instance.endCall(
        conversationId: info.conversationId,
        callId: info.callId,
        status: 'accepted',
      );
    }
    if (!context.mounted) return;
    await LiveKitCallScreen.startCall(
      context,
      conversationId: info.conversationId,
      peerName: info.callerName,
      peerHandle: 'ojas',
      isVideoCall: info.isVideo,
      isIncoming: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = call.callerName.isEmpty ? 'OJAS User' : call.callerName;

    return Material(
      color: const Color(0xF20F172A),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    call.isVideo
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    call.isVideo ? 'Incoming video call' : 'Incoming audio call',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            CircleAvatar(
              radius: 56,
              backgroundColor: const Color(0xFF1E293B),
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 44,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ringing…',
              style: TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    color: const Color(0xFFDC2626),
                    icon: Icons.call_end_rounded,
                    label: 'Decline',
                    onTap: () => _decline(context),
                  ),
                  _ActionButton(
                    color: const Color(0xFF16A34A),
                    icon: call.isVideo
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    label: 'Accept',
                    onTap: () => _accept(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 68,
              height: 68,
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
