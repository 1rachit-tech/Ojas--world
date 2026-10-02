import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Block / report helpers — minimal writes, cost-safe.
class SafetyService {
  SafetyService._();
  static final SafetyService instance = SafetyService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _blockedCol(String uid) =>
      _db.collection('users').doc(uid).collection('blocked');

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  Future<void> blockUser({
    required String targetUid,
    String? displayName,
  }) async {
    final uid = _uid;
    if (uid == null || targetUid.isEmpty || targetUid == uid) {
      throw const SafetyException('Cannot block this user.');
    }
    await _blockedCol(uid).doc(targetUid).set({
      'uid': targetUid,
      if (displayName != null && displayName.isNotEmpty)
        'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String targetUid) async {
    final uid = _uid;
    if (uid == null || targetUid.isEmpty) return;
    await _blockedCol(uid).doc(targetUid).delete();
  }

  Future<bool> isBlocked(String targetUid) async {
    final uid = _uid;
    if (uid == null || targetUid.isEmpty) return false;
    final snap = await _blockedCol(uid).doc(targetUid).get();
    return snap.exists;
  }

  Stream<Set<String>> watchBlockedIds() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <String>{});
    return _blockedCol(uid).snapshots().map((snap) {
      return snap.docs.map((d) => d.id).toSet();
    });
  }

  Future<void> reportUser({
    required String targetUid,
    required String reason,
    String? conversationId,
    String? messageId,
    String? details,
  }) async {
    final uid = _uid;
    if (uid == null || targetUid.isEmpty) {
      throw const SafetyException('Please sign in to report.');
    }
    final clean = reason.trim();
    if (clean.isEmpty) {
      throw const SafetyException('Please choose a reason.');
    }
    await _reports.add({
      'reporterId': uid,
      'targetUid': targetUid,
      'reason': clean,
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
      if (conversationId != null) 'conversationId': conversationId,
      if (messageId != null) 'messageId': messageId,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class SafetyException implements Exception {
  const SafetyException(this.message);
  final String message;
  @override
  String toString() => message;
}
