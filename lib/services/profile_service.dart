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

    if (user == null) {
      return null;
    }

    final snapshot = await _users.doc(user.uid).get();

    return snapshot.data();
  }

  Future<bool> hasCompletedProfile() async {
    final profile = await getCurrentProfile();

    return profile?['profileComplete'] == true;
  }

  Future<bool> isOjasIdAvailable(String ojasId) async {
    final normalizedId = normalizeOjasId(ojasId);

    if (!isValidOjasId(normalizedId)) {
      return false;
    }

    final snapshot = await _ojasIds.doc(normalizedId).get();

    final user = FirebaseAuth.instance.currentUser;

    if (!snapshot.exists) {
      return true;
    }

    return snapshot.data()?['uid'] == user?.uid;
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

    if (!isValidOjasId(normalizedId)) {
      throw const ProfileException(
        'Use 3–20 letters, numbers, or underscores.',
      );
    }

    final email = user.email?.trim();

    if (email == null || email.isEmpty) {
      throw const ProfileException(
        'A verified email is required to create your OJAS account.',
      );
    }

    final userReference = _users.doc(user.uid);
    final idReference = _ojasIds.doc(normalizedId);

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
          'email': email,
          'ojasId': normalizedId,
          'photoUrl': photoUrl,
          'profileComplete': true,
          'updatedAt': now,
          'createdAt': now,
        },
        SetOptions(merge: true),
      );

      transaction.set(
        idReference,
        {
          'uid': user.uid,
          'email': email,
          'createdAt':
              existingId.data()?['createdAt'] ?? now,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<String?> emailForOjasId(String ojasId) async {
    final normalizedId = normalizeOjasId(ojasId);

    if (!isValidOjasId(normalizedId)) {
      return null;
    }

    final snapshot = await _ojasIds.doc(normalizedId).get();

    final email = snapshot.data()?['email'];

    if (email is! String || email.trim().isEmpty) {
      return null;
    }

    return email.trim();
  }

  static String normalizeOjasId(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');
  }

  static bool isValidOjasId(String value) {
    return RegExp(
      r'^[a-zA-Z0-9_]{3,20}$',
    ).hasMatch(value);
  }
}

class ProfileException implements Exception {
  const ProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}
