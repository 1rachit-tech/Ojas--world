import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchSafetyService {
  SearchSafetyService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Set<String>? _cachedBlocks;
  DateTime? _cacheAt;

  Future<Set<String>?> blockedCreatorIds() async {
    final now = DateTime.now();
    if (_cachedBlocks != null &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < const Duration(minutes: 5)) {
      return _cachedBlocks!;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const <String>{};
    }

    try {
      final snapshot = await _firestore
          .collection('userBlocks')
          .doc(uid)
          .collection('blocked')
          .limit(300)
          .get();

      final values = <String>{};
      for (final document in snapshot.docs) {
        final data = document.data();
        final blockedId =
            data['blockedUserId'] as String? ?? document.id;
        if (blockedId.isNotEmpty) {
          values.add(blockedId);
        }
      }

      _cachedBlocks = values;
      _cacheAt = now;
      return values;
    } catch (_) {
      // Safety uncertainty is fail-closed at the orchestrator.
      return null;
    }
  }

  bool isEligible(Map<String, dynamic> data) {
    if (data['eligible'] == false) return false;
    if (data['isDeleted'] == true) return false;
    if (data['isBanned'] == true) return false;

    final visibility = data['visibility'];
    if (visibility is String && visibility != 'public') {
      return false;
    }

    final safetyStatus = data['safetyStatus'];
    if (safetyStatus is String &&
        safetyStatus.isNotEmpty &&
        safetyStatus != 'clean') {
      return false;
    }

    return true;
  }
}
