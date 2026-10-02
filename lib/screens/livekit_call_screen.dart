import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/livekit_call_service.dart';

/// Real audio/video call using LiveKit.
/// Credentials come only from [LiveKitCallService] (server-minted JWT).
class LiveKitCallScreen extends StatefulWidget {
  const LiveKitCallScreen({
    super.key,
    required this.conversationId,
    required this.peerName,
    required this.peerHandle,
    this.isVideoCall = true,
  });

  final String conversationId;
  final String peerName;
  final String peerHandle;
  final bool isVideoCall;

  static Future<void> startCall(
    BuildContext context, {
    required String conversationId,
    required String peerName,
    required String peerHandle,
    bool isVideoCall = true,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LiveKitCallScreen(
          conversationId: conversationId,
          peerName: peerName,
          peerHandle: peerHandle,
          isVideoCall: isVideoCall,
        ),
      ),
    );
  }

  @override
  State<LiveKitCallScreen> createState() => _LiveKitCallScreenState();
}

class _LiveKitCallScreenState extends State<LiveKitCallScreen> {
  final Room _room = Room();
  EventsListener<RoomEvent>? _listener;

  bool _connecting = true;
  bool _connected = false;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  String? _error;
  int _callSeconds = 0;
  Timer? _timer;

  VideoTrack? _remoteVideo;
  VideoTrack? _localVideo;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final ok = await _ensurePermissions();
      if (!ok) {
        if (mounted) {
          setState(() {
            _connecting = false;
            _error = 'Microphone${widget.isVideoCall ? ' and camera' : ''} permission required.';
          });
        }
        return;
      }

      final session = await LiveKitCallService.instance.createSession(
        conversationId: widget.conversationId,
        isVideo: widget.isVideoCall,
      );

      _listener = _room.createListener();
      _listener!
        ..on<RoomConnectedEvent>((_) {
          if (mounted) {
            setState(() {
              _connecting = false;
              _connected = true;
            });
            _startTimer();
          }
        })
        ..on<RoomDisconnectedEvent>((_) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).maybePop();
          }
        })
        ..on<ParticipantConnectedEvent>((_) => _refreshTracks())
        ..on<ParticipantDisconnectedEvent>((_) => _refreshTracks())
        ..on<TrackSubscribedEvent>((_) => _refreshTracks())
        ..on<TrackUnsubscribedEvent>((_) => _refreshTracks())
        ..on<LocalTrackPublishedEvent>((_) => _refreshTracks())
        ..on<LocalTrackUnpublishedEvent>((_) => _refreshTracks());

      await _room.connect(
        session.url,
        session.token,
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: const AudioPublishOptions(
            name: 'microphone',
          ),
          defaultCameraCaptureOptions: const CameraCaptureOptions(
            maxFrameRate: 24,
            params: VideoParametersPresets.h540_169,
          ),
        ),
      );

      await _room.localParticipant?.setMicrophoneEnabled(true);
      if (widget.isVideoCall) {
        await _room.localParticipant?.setCameraEnabled(true);
      }

      _refreshTracks();
      if (mounted) {
        setState(() {
          _connecting = false;
          _connected = true;
        });
        _startTimer();
      }
    } on LiveKitCallException catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = 'Unable to connect the call.';
        });
      }
    }
  }

  Future<bool> _ensurePermissions() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;
    if (widget.isVideoCall) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) return false;
    }
    return true;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  void _refreshTracks() {
    if (!mounted) return;

    VideoTrack? remote;
    for (final participant in _room.remoteParticipants.values) {
      for (final pub in participant.videoTrackPublications) {
        if (pub.track != null && pub.subscribed) {
          remote = pub.track;
          break;
        }
      }
      if (remote != null) break;
    }

    VideoTrack? local;
    final localParticipant = _room.localParticipant;
    if (localParticipant != null) {
      for (final pub in localParticipant.videoTrackPublications) {
        if (pub.track != null) {
          local = pub.track;
          break;
        }
      }
    }

    setState(() {
      _remoteVideo = remote;
      _localVideo = local;
    });
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _room.localParticipant?.setMicrophoneEnabled(!next);
    if (mounted) setState(() => _muted = next);
    HapticFeedback.selectionClick();
  }

  Future<void> _toggleCamera() async {
    if (!widget.isVideoCall) return;
    final next = !_cameraOff;
    await _room.localParticipant?.setCameraEnabled(!next);
    if (mounted) setState(() => _cameraOff = next);
    _refreshTracks();
    HapticFeedback.selectionClick();
  }

  Future<void> _toggleSpeaker() async {
    // Prefer earpiece / speaker via Hardware API when available.
    try {
      await Hardware.instance.setSpeakerphoneOn(!_speakerOn);
    } catch (_) {}
    if (mounted) setState(() => _speakerOn = !_speakerOn);
    HapticFeedback.selectionClick();
  }

  Future<void> _hangUp() async {
    HapticFeedback.mediumImpact();
    try {
      await _room.disconnect();
    } catch (_) {}
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(int totalSecs) {
    final mins = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSecs % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_listener?.dispose() ?? Future.value());
    unawaited(_room.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.peerName.isEmpty ? 'OJAS User' : widget.peerName;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Remote / placeholder
            if (_remoteVideo != null && widget.isVideoCall)
              VideoTrackRenderer(_remoteVideo!)
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: const Color(0xFF1E293B),
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 42,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _connecting
                          ? 'Connecting…'
                          : (_error != null
                              ? ''
                              : (_connected
                                  ? _formatDuration(_callSeconds)
                                  : '')),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Local PiP
            if (widget.isVideoCall &&
                _localVideo != null &&
                !_cameraOff &&
                _connected)
              Positioned(
                top: 72,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 110,
                    height: 160,
                    child: VideoTrackRenderer(
                      _localVideo!,
                      mirrorMode: VideoViewMirrorMode.mirror,
                    ),
                  ),
                ),
              ),

            // Status chip
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _connected
                          ? Icons.lock_rounded
                          : Icons.hourglass_top_rounded,
                      size: 14,
                      color: _connected
                          ? const Color(0xFF4ADE80)
                          : Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _connecting
                            ? 'Securing call…'
                            : (_error != null
                                ? 'Call unavailable'
                                : (widget.isVideoCall
                                    ? 'Encrypted video · $_formatDuration(_callSeconds)'
                                    : 'Encrypted audio · $_formatDuration(_callSeconds)')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: 140,
                child: Material(
                  color: const Color(0xFF7F1D1D),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundControl(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _muted ? 'Unmute' : 'Mute',
                    active: _muted,
                    onTap: _connected ? _toggleMute : null,
                  ),
                  if (widget.isVideoCall)
                    _RoundControl(
                      icon: _cameraOff
                          ? Icons.videocam_off_rounded
                          : Icons.videocam_rounded,
                      label: _cameraOff ? 'Camera' : 'Camera',
                      active: _cameraOff,
                      onTap: _connected ? _toggleCamera : null,
                    ),
                  _RoundControl(
                    icon: _speakerOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                    label: 'Speaker',
                    active: !_speakerOn,
                    onTap: _connected ? _toggleSpeaker : null,
                  ),
                  _RoundControl(
                    icon: Icons.call_end_rounded,
                    label: 'End',
                    danger: true,
                    onTap: _hangUp,
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

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFDC2626)
        : (active ? Colors.white : const Color(0xFF1E293B));
    final fg = danger
        ? Colors.white
        : (active ? const Color(0xFF0F172A) : Colors.white);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, color: fg, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
