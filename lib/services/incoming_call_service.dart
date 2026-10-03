import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Active incoming call payload shown while the app is in the foreground.
class IncomingCallInfo {
  const IncomingCallInfo({
    required this.conversationId,
    required this.callerId,
    required this.callId,
    required this.isVideo,
    this.callerName = 'OJAS User',
  });

  final String conversationId;
  final String callerId;
  final String callId;
  final bool isVideo;
  final String callerName;
}

/// Listens for FCM call invites while the app is open and exposes them for UI.
class IncomingCallService extends ChangeNotifier {
  IncomingCallService._();
  static final IncomingCallService instance = IncomingCallService._();

  StreamSubscription<RemoteMessage>? _sub;
  IncomingCallInfo? _active;
  bool _started = false;

  IncomingCallInfo? get activeCall => _active;

  void start() {
    if (_started) return;
    _started = true;
    _sub = NotificationService.instance.onNotificationReceived.listen(_onMessage);
  }

  void _onMessage(RemoteMessage message) {
    final data = message.data;
    if (data['type'] != 'call') return;

    final conversationId = data['conversationId']?.toString() ?? '';
    final callerId = data['senderId']?.toString() ?? '';
    final callId = data['callId']?.toString() ?? '';
    if (conversationId.isEmpty || callerId.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || callerId == uid) return;

    final title = message.notification?.title?.trim();
    _active = IncomingCallInfo(
      conversationId: conversationId,
      callerId: callerId,
      callId: callId.isEmpty ? 'unknown' : callId,
      isVideo: data['isVideo'] == 'true' || data['isVideo'] == true,
      callerName: (title != null && title.isNotEmpty) ? title : 'OJAS User',
    );
    notifyListeners();
  }

  void clear() {
    if (_active == null) return;
    _active = null;
    notifyListeners();
  }

  void disposeService() {
    unawaited(_sub?.cancel() ?? Future.value());
    _sub = null;
    _started = false;
    _active = null;
  }
}
