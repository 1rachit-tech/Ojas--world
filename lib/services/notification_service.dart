import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final StreamController<RemoteMessage> _notificationStream =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onNotificationReceived => _notificationStream.stream;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> initialize() async {
    try {
      if (!kIsWeb) {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: true,
        );
      }

      await _registerCurrentToken();

      _foregroundSubscription ??=
          FirebaseMessaging.onMessage.listen(_notificationStream.add);

      _tokenSubscription ??= _messaging.onTokenRefresh.listen(
        _saveToken,
      );
    } catch (error) {
      debugPrint('FCM initialization failed: $error');
    }
  }

  Future<void> _registerCurrentToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;

    await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || token.trim().isEmpty) return;

    await _firestore.collection('users').doc(uid).set(
      {
        'uid': uid,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  void simulateIncomingNotification({
    required String title,
    required String body,
    required String type,
  }) {
    debugPrint('Simulation only: $title / $body / $type');
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _notificationStream.close();
  }
}
