import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _ojasIds =>
      _firestore.collection('ojasIds');

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final snapshot = await _users.doc(user.uid).get();
    return snapshot.data();
  }

  Future<bool> hasCompletedProfile() async {
    final profile = await getCurrentProfile();
    return profile?['profileComplete'] == true;
  }

  Future<void> createOrUpdateProfile({
    required String ojasId,
    required String photoUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Please sign in before setting up your profile.',
      );
    }

    final normalizedId = normalizeOjasId(ojasId);
    if (normalizedId.isEmpty) {
      throw const ProfileException('Enter an OJAS ID.');
    }

    final userReference = _users.doc(user.uid);
    final idReference = _ojasIds.doc(normalizedId);
    final loginEmail = credentialEmailFor(normalizedId);
    await _firestore.runTransaction((transaction) async {
      final existingId = await transaction.get(idReference);
      final existingOwner = existingId.data()?['uid'];
      if (existingId.exists && existingOwner != user.uid) {
        throw const ProfileException(
          'That OJAS ID is already taken. Choose another one.',
        );
      }

      final now = FieldValue.serverTimestamp();
      transaction.set(
        userReference,
        {
          'uid': user.uid,
          'email': user.email,
          'ojasId': normalizedId,
          'photoUrl': photoUrl,
          'loginEmail': loginEmail,
          'profileComplete': true,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
      transaction.set(idReference, {
        'uid': user.uid,
        'email': loginEmail,
        'createdAt': existingId.data()?['createdAt'] ?? now,
      });
    });
  }

  Future<String?> emailForOjasId(String ojasId) async {
    final normalizedId = normalizeOjasId(ojasId);
    final snapshot = await _ojasIds.doc(normalizedId).get();
    return snapshot.data()?['email'] as String?;
  }

  static String normalizeOjasId(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static String credentialEmailFor(String ojasId) =>
      '${normalizeOjasId(ojasId)}@ojas.local';
}

class ProfileException implements Exception {
  const ProfileException(this.message);
  final String message;

  @override
  String toString() => message;
}