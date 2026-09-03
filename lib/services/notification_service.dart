import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

class NotificationOpenData {
  const NotificationOpenData({
    required this.conversationId,
    required this.messageId,
    required this.senderId,
  });

  final String conversationId;
  final String messageId;
  final String senderId;
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final StreamController<RemoteMessage> _notificationStream =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<NotificationOpenData> _openStream =
      StreamController<NotificationOpenData>.broadcast();

  Stream<RemoteMessage> get onNotificationReceived =>
      _notificationStream.stream;

  Stream<NotificationOpenData> get onNotificationOpened => _openStream.stream;

  NotificationOpenData? _pendingOpen;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<User?>? _authSubscription;

  String? _registeredUid;
  String? _currentToken;
  bool _initialized = false;

  NotificationOpenData? consumePendingOpen() {
    final pending = _pendingOpen;
    _pendingOpen = null;
    return pending;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      if (!kIsWeb) {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: true,
        );
      }

      _authSubscription ??= _auth.authStateChanges().listen(_handleAuthChanged);
      _foregroundSubscription ??=
          FirebaseMessaging.onMessage.listen(_notificationStream.add);
      _openedSubscription ??=
          FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      _tokenSubscription ??= _messaging.onTokenRefresh.listen(_saveToken);

      await _registerCurrentToken();

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }
    } catch (error) {
      debugPrint('FCM initialization failed: $error');
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final data = message.data;
    final conversationId = data['conversationId'];
    final messageId = data['messageId'];
    final senderId = data['senderId'];
    final type = data['type'];

    if (type != 'message' ||
        conversationId is! String ||
        messageId is! String ||
        senderId is! String ||
        conversationId.isEmpty ||
        messageId.isEmpty ||
        senderId.isEmpty) {
      return;
    }

    final openData = NotificationOpenData(
      conversationId: conversationId,
      messageId: messageId,
      senderId: senderId,
    );
    _pendingOpen = openData;
    _openStream.add(openData);
  }

  Future<void> _handleAuthChanged(User? user) async {
    final previousUid = _registeredUid;
    final nextUid = user?.uid;

    if (previousUid != null &&
        previousUid != nextUid &&
        _currentToken != null) {
      try {
        await _removeToken(previousUid, _currentToken!);
      } catch (error) {
        debugPrint('Unable to remove old FCM token: $error');
      }
    }

    _registeredUid = nextUid;
    if (user != null) {
      await _registerCurrentToken();
    }
  }

  Future<void> _registerCurrentToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }

    _currentToken = token.trim();
    _registeredUid = user.uid;
    await _saveToken(_currentToken!);
  }

  Future<void> _saveToken(String token) async {
    final uid = _auth.currentUser?.uid;
    final cleanToken = token.trim();
    if (uid == null || cleanToken.isEmpty) {
      return;
    }

    _currentToken = cleanToken;
    _registeredUid = uid;
    final userRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      final tokenMap = <String, dynamic>{};
      final rawTokens = data['fcmTokens'];

      if (rawTokens is Map) {
        rawTokens.forEach((key, value) {
          if (key is String && key.trim().isNotEmpty) {
            tokenMap[key] = value == true;
          }
        });
      } else if (rawTokens is List) {
        for (final value in rawTokens) {
          if (value is String && value.trim().isNotEmpty) {
            tokenMap[value.trim()] = true;
          }
        }
      }

      tokenMap[cleanToken] = true;
      while (tokenMap.length > 10) {
        tokenMap.remove(tokenMap.keys.first);
      }

      transaction.set(
        userRef,
        {
          'uid': uid,
          'fcmTokens': tokenMap,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> _removeToken(String uid, String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      return;
    }

    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data();
      if (data == null) {
        return;
      }

      final cleaned = <String, dynamic>{};
      final rawTokens = data['fcmTokens'];
      if (rawTokens is Map) {
        rawTokens.forEach((key, value) {
          if (key is String && key.trim().isNotEmpty && key != cleanToken) {
            cleaned[key] = value == true;
          }
        });
      } else if (rawTokens is List) {
        for (final value in rawTokens) {
          if (value is String && value.trim().isNotEmpty && value != cleanToken) {
            cleaned[value.trim()] = true;
          }
        }
      }

      transaction.set(
        userRef,
        {'fcmTokens': cleaned},
        SetOptions(merge: true),
      );
    });
  }

  void simulateIncomingNotification({
    required String title,
    required String body,
    required String type,
  }) {
    debugPrint('Simulation only: $title / $body / $type');
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _notificationStream.close();
    await _openStream.close();
    _pendingOpen = null;
    _initialized = false;
  }
}
