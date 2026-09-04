import 'package:cloud_firestore/cloud_firestore.dart';

class MediaDeduplicationService {
  MediaDeduplicationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _mediaIndex =>
      _firestore.collection('mediaIndex');

  /// Looks up an already registered media asset by its canonical SHA-256.
  /// Returns the trusted CDN/HLS URL when the indexed media type matches.
  Future<String?> findExistingMedia({
    required String mediaHash,
    required String mediaType,
  }) async {
    final normalizedHash = mediaHash.trim().toLowerCase();
    final normalizedType = mediaType.trim().toLowerCase();

    if (normalizedHash.isEmpty || normalizedType.isEmpty) {
      return null;
    }

    final snapshot = await _mediaIndex.doc(normalizedHash).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();
    final storedType = data?['mediaType'];
    final cdnUrl = data?['cdnUrl'];

    if (storedType is! String ||
        storedType.trim().toLowerCase() != normalizedType ||
        cdnUrl is! String ||
        cdnUrl.trim().isEmpty) {
      return null;
    }

    return cdnUrl.trim();
  }
}
