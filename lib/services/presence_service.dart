import 'package:firebase_database/firebase_database.dart';

class PresenceService {
  PresenceService({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  DatabaseReference statusReference(String uid) =>
      _database.ref('status/$uid');

  DatabaseReference typingReference({
    required String conversationId,
    required String uid,
  }) => _database.ref('typing/$conversationId/$uid');

  /// Marks the user online and schedules an offline state if the RTDB
  /// connection disappears unexpectedly.
  Future<void> setOnline(String uid) async {
    final reference = statusReference(uid);

    await reference.onDisconnect().set({
      'state': 'offline',
      'lastChanged': ServerValue.timestamp,
    });

    await reference.set({
      'state': 'online',
      'lastChanged': ServerValue.timestamp,
    });
  }

  Future<void> setOffline(String uid) async {
    await statusReference(uid).set({
      'state': 'offline',
      'lastChanged': ServerValue.timestamp,
    });
  }

  /// Typing is kept in RTDB so keystrokes never create Firestore writes.
  Future<void> setTyping({
    required String conversationId,
    required String uid,
    required bool isTyping,
  }) async {
    final reference = typingReference(
      conversationId: conversationId,
      uid: uid,
    );

    if (isTyping) {
      await reference.set(true);
      await reference.onDisconnect().set(false);
    } else {
      await reference.set(false);
    }
  }

  Stream<bool> watchTyping({
    required String conversationId,
    required String uid,
  }) {
    return typingReference(
      conversationId: conversationId,
      uid: uid,
    ).onValue.map((event) => event.snapshot.value == true);
  }

  Stream<Map<String, dynamic>?> watchStatus(String uid) {
    return statusReference(uid).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return null;
      }

      return Map<String, dynamic>.from(value);
    });
  }
}
