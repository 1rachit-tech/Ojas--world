import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Writes call invites under conversations/{id}/callInvites/{callId}.
/// Cloud Function sends FCM type=call; callee opens LiveKitCallScreen.
class CallSignalingService {
  CallSignalingService._();
  static final CallSignalingService instance = CallSignalingService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _invites(String conversationId) =>
      _db.collection('conversations').doc(conversationId).collection('callInvites');

  /// Caller creates invite. Returns callId.
  Future<String> startCall({
    required String conversationId,
    required String calleeId,
    required bool isVideo,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw const CallSignalingException('Please sign in to call.');
    }
    if (conversationId.isEmpty || calleeId.isEmpty || calleeId == uid) {
      throw const CallSignalingException('Invalid call target.');
    }

    final ref = _invites(conversationId).doc();
    await ref.set({
      'callId': ref.id,
      'conversationId': conversationId,
      'callerId': uid,
      'calleeId': calleeId,
      'isVideo': isVideo,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().toUtc().add(const Duration(minutes: 2)),
      ),
    });
    return ref.id;
  }

  Future<void> endCall({
    required String conversationId,
    required String callId,
    String status = 'ended',
  }) async {
    final uid = _uid;
    if (uid == null || conversationId.isEmpty || callId.isEmpty) return;
    final ref = _invites(conversationId).doc(callId);
    try {
      await ref.set({
        'status': status,
        'endedBy': uid,
        'endedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncoming(String uid) {
    // Limited client query — full routing also via FCM.
    return _db
        .collectionGroup('callInvites')
        .where('calleeId', isEqualTo: uid)
        .where('status', isEqualTo: 'ringing')
        .limit(5)
        .snapshots();
  }
}

class CallSignalingException implements Exception {
  const CallSignalingException(this.message);
  final String message;
  @override
  String toString() => message;
}
