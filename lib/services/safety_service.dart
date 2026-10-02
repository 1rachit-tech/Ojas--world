import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Block / report — uses firestore.rules paths:
/// - userBlocks/{uid}/blocked/{targetUid}
/// - reports/{reportId}
class SafetyService {
  SafetyService._();
  static final SafetyService instance = SafetyService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _blockedCol(String uid) =>
      _db.collection('userBlocks').doc(uid).collection('blocked');

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
    // Must match rules: blockedUserId == doc id
    await _blockedCol(uid).doc(targetUid).set({
      'blockedUserId': targetUid,
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim().substring(
          0,
          displayName.trim().length > 80 ? 80 : displayName.trim().length,
        ),
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

  /// One-shot load for inbox filter (max 200 blocks).
  Future<Set<String>> loadBlockedIds() async {
    final uid = _uid;
    if (uid == null) return const <String>{};
    final snap = await _blockedCol(uid).limit(200).get();
    return snap.docs.map((d) => d.id).toSet();
  }

  Stream<Set<String>> watchBlockedIds() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <String>{});
    return _blockedCol(uid).limit(200).snapshots().map((snap) {
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
    if (clean.isEmpty || clean.length > 500) {
      throw const SafetyException('Please choose a valid reason.');
    }
    if (targetUid == uid) {
      throw const SafetyException('Cannot report yourself.');
    }
    await _reports.add({
      'reporterId': uid,
      'targetUid': targetUid,
      'reason': clean,
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim().substring(
          0,
          details.trim().length > 1000 ? 1000 : details.trim().length,
        ),
      if (conversationId != null && conversationId.isNotEmpty)
        'conversationId': conversationId,
      if (messageId != null && messageId.isNotEmpty) 'messageId': messageId,
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
