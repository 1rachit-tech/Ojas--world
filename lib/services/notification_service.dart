import 'dart:async';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final StreamController<Map<String, dynamic>> _notificationStream =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationReceived => _notificationStream.stream;

  Future<void> initialize() async {
    debugPrint('NOTIFICATION SERVICE INITIALIZED');
  }

  void simulateIncomingNotification({
    required String title,
    required String body,
    required String type, // 'like', 'comment', 'gift', 'follow'
  }) {
    _notificationStream.add({
      'title': title,
      'body': body,
      'type': type,
      'timestamp': DateTime.now(),
    });
  }

  void dispose() {
    _notificationStream.close();
  }
}
