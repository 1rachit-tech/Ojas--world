import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageDeliveryService {
  MessageDeliveryService._();

  static final MessageDeliveryService instance =
      MessageDeliveryService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _conversation(
    String conversationId,
  ) {
    return _firestore.collection('conversations').doc(conversationId);
  }

  Timestamp? deliveredAtFor(
    Map<String, dynamic> conversationData,
    String uid,
  ) {
    final raw = conversationData['deliveredAtBy'];
    if (raw is Map) {
      final value = raw[uid];
      if (value is Timestamp) {
        return value;
      }
    }
    return null;
  }

  Future<void> markDeliveredUntil({
    required String conversationId,
    required Timestamp messageCreatedAt,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || conversationId.trim().isEmpty) {
      return;
    }

    await _conversation(conversationId).set(
      {
        'deliveredAtBy.$uid': messageCreatedAt,
      },
      SetOptions(merge: true),
    );
  }
}
