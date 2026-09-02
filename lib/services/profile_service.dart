import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ojas_profile.dart';

class ProfileService {
  ProfileService._();

  static final ProfileService instance =
      ProfileService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>
      get _users =>
          _firestore.collection('users');

  CollectionReference<Map<String, dynamic>>
      get _publicProfiles =>
          _firestore.collection('publicProfiles');

  CollectionReference<Map<String, dynamic>>
      get _ojasIds =>
          _firestore.collection('ojasIds');

  User? get currentUser => _auth.currentUser;

  String? get currentUid => _auth.currentUser?.uid;

  Stream<OjasProfile?> watchCurrentProfile() {
    final uid = currentUid;

    if (uid == null) {
      return Stream<OjasProfile?>.value(null);
    }

    return _publicProfiles
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();

      if (data == null) {
        return null;
      }

      return OjasProfile.fromMap(
        data,
        uid: uid,
      );
    });
  }

  Stream<OjasProfile?> watchProfile(String uid) {
    return _publicProfiles
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();

      if (data == null) {
        return null;
      }

      return OjasProfile.fromMap(
        data,
        uid: uid,
      );
    });
  }

  Future<OjasProfile?> getCurrentProfile() async {
    final uid = currentUid;

    if (uid == null) {
      return null;
    }

    return getProfile(uid);
  }

  Future<OjasProfile?> getProfile(String uid) async {
    final snapshot =
        await _publicProfiles.doc(uid).get();

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return OjasProfile.fromMap(
      data,
      uid: uid,
    );
  }

  Future<bool> hasCompletedProfile() async {
    final user = currentUser;

    if (user == null) {
      return false;
    }

    final snapshot =
        await _users.doc(user.uid).get();

    return snapshot.data()?['profileComplete'] == true;
  }

  Future<bool> isOjasIdAvailable(String ojasId) async {
    final normalizedId =
        normalizeOjasId(ojasId);

    if (!isValidOjasId(normalizedId)) {
      return false;
    }

    final snapshot =
        await _ojasIds.doc(normalizedId).get();

    final user = currentUser;

    if (!snapshot.exists) {
      return true;
    }

    return snapshot.data()?['uid'] == user?.uid;
  }

  Future<void> createOrUpdateProfile({
    required String ojasId,
    required String photoUrl,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message:
            'Please sign in before setting up your profile.',
      );
    }

    final normalizedId =
        normalizeOjasId(ojasId);

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

    final userReference =
        _users.doc(user.uid);

    final publicReference =
        _publicProfiles.doc(user.uid);

    final idReference =
        _ojasIds.doc(normalizedId);

    await _firestore.runTransaction(
      (transaction) async {
        final existingId =
            await transaction.get(idReference);

        final existingOwner =
            existingId.data()?['uid'];

        if (existingId.exists &&
            existingOwner != user.uid) {
          throw const ProfileException(
            'That OJAS ID is already taken. Choose another one.',
          );
        }

        final existingPublic =
            await transaction.get(publicReference);

        final existingData =
            existingPublic.data();

        final displayName =
            _safeString(
          existingData?['displayName'],
          fallback:
              user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!.trim()
                  : normalizedId,
        );

        final now =
            FieldValue.serverTimestamp();

        transaction.set(
          userReference,
          {
            'uid': user.uid,
            'email': email,
            'ojasId': normalizedId,
            'profileComplete': true,
            'createdAt':
                existingData?['createdAt'] ?? now,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );

        transaction.set(
          publicReference,
          {
            'uid': user.uid,
            'ojasId': normalizedId,
            'displayName': displayName,
            'photoUrl': photoUrl,
            'bio':
                _safeString(existingData?['bio']),
            'website':
                _safeString(existingData?['website']),
            'isCreator':
                existingData?['isCreator'] == true,
            'creatorCategory':
                _safeString(
              existingData?['creatorCategory'],
            ),
            'isVerified':
                existingData?['isVerified'] == true,
            'followersCount':
                _safeInteger(
              existingData?['followersCount'],
            ),
            'followingCount':
                _safeInteger(
              existingData?['followingCount'],
            ),
            'likesCount':
                _safeInteger(
              existingData?['likesCount'],
            ),
            'postsCount':
                _safeInteger(
              existingData?['postsCount'],
            ),
            'createdAt':
                existingData?['createdAt'] ?? now,
            'updatedAt': now,
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
      },
    );
  }

  Future<void> updateCurrentProfile({
    required String displayName,
    required String bio,
    required String website,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Please sign in again.',
      );
    }

    final normalizedName =
        displayName.trim();

    if (normalizedName.isEmpty) {
      throw const ProfileException(
        'Display name cannot be empty.',
      );
    }

    if (normalizedName.length > 50) {
      throw const ProfileException(
        'Display name can contain up to 50 characters.',
      );
    }

    if (bio.trim().length > 160) {
      throw const ProfileException(
        'Bio can contain up to 160 characters.',
      );
    }

    if (website.trim().length > 200) {
      throw const ProfileException(
        'Website address is too long.',
      );
    }

    await _publicProfiles.doc(user.uid).set(
      {
        'uid': user.uid,
        'displayName': normalizedName,
        'bio': bio.trim(),
        'website': website.trim(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await user.updateDisplayName(
      normalizedName,
    );
  }

  Future<void> updateProfilePhoto(
    String photoUrl,
  ) async {
    final user = currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Please sign in again.',
      );
    }

    final normalizedPhoto =
        photoUrl.trim();

    if (normalizedPhoto.isEmpty) {
      throw const ProfileException(
        'Please choose a profile picture.',
      );
    }

    await _publicProfiles.doc(user.uid).set(
      {
        'uid': user.uid,
        'photoUrl': normalizedPhoto,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> enableCreatorProfile({
    required String category,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Please sign in again.',
      );
    }

    final normalizedCategory =
        category.trim();

    if (normalizedCategory.isEmpty) {
      throw const ProfileException(
        'Please select a creator category.',
      );
    }

    await _publicProfiles.doc(user.uid).set(
      {
        'uid': user.uid,
        'isCreator': true,
        'creatorCategory': normalizedCategory,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> disableCreatorProfile() async {
    final user = currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Please sign in again.',
      );
    }

    await _publicProfiles.doc(user.uid).set(
      {
        'uid': user.uid,
        'isCreator': false,
        'creatorCategory': '',
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> incrementPostCount() async {
    final user = currentUser;

    if (user == null) {
      return;
    }

    await _publicProfiles.doc(user.uid).set(
      {
        'postsCount': FieldValue.increment(1),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> emailForOjasIdCheck(
    String ojasId,
  ) async {
    final normalizedId =
        normalizeOjasId(ojasId);

    if (!isValidOjasId(normalizedId)) {
      throw const ProfileException(
        'Enter a valid OJAS ID.',
      );
    }

    final snapshot =
        await _ojasIds.doc(normalizedId).get();

    if (!snapshot.exists) {
      throw const ProfileException(
        'OJAS ID not found.',
      );
    }
  }

  Future<String?> emailForOjasId(
    String ojasId,
  ) async {
    final normalizedId =
        normalizeOjasId(ojasId);

    if (!isValidOjasId(normalizedId)) {
      return null;
    }

    final snapshot =
        await _ojasIds.doc(normalizedId).get();

    final email =
        snapshot.data()?['email'];

    if (email is! String ||
        email.trim().isEmpty) {
      return null;
    }

    return email.trim();
  }

  static String normalizeOjasId(
    String value,
  ) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(
          RegExp(r'\s+'),
          '',
        );
  }

  static bool isValidOjasId(
    String value,
  ) {
    return RegExp(
      r'^[a-zA-Z0-9_]{3,20}$',
    ).hasMatch(value);
  }

  static String _safeString(
    dynamic value, {
    String fallback = '',
  }) {
    if (value is String &&
        value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  static int _safeInteger(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }
}

class ProfileException implements Exception {
  const ProfileException(
    this.message,
  );

  final String message;

  @override
  String toString() => message;
}
