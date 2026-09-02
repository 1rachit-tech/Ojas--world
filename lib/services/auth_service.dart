import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void>? _googleInitialization;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
  ) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithEmail(
    String email,
    String password,
  ) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> initializeGoogleSignIn() async {
    _googleInitialization ??= _googleSignIn.initialize(
      clientId: kIsWeb
          ? '1076759095973-i3dpkctmihia89dcin2q0406p57is7mv.apps.googleusercontent.com'
          : null,
    );

    await _googleInitialization;
  }

  Stream<GoogleSignInAuthenticationEvent> get googleAuthenticationEvents =>
      _googleSignIn.authenticationEvents;

  Future<UserCredential> signInWithGoogle() async {
    await initializeGoogleSignIn();

    final GoogleSignInAccount account =
        await _googleSignIn.authenticate();

    return signInWithGoogleAccount(account);
  }

  Future<UserCredential> signInWithGoogleAccount(
    GoogleSignInAccount account,
  ) async {
    final String? idToken = account.authentication.idToken;

    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-token',
        message: 'Google sign-in did not return a valid token.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    return _firebaseAuth.signInWithCredential(credential);
  }

  bool get hasPasswordProvider {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      return false;
    }

    return user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
  }

  bool get hasGoogleProvider {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      return false;
    }

    return user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
  }

  Future<void> linkEmailPasswordToCurrentUser({
    required String email,
    required String password,
  }) async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Please sign in before adding a login password.',
      );
    }

    if (hasPasswordProvider) {
      return;
    }

    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'A valid email address is required.',
      );
    }

    if (password.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Password must contain at least 6 characters.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: normalizedEmail,
      password: password,
    );

    await user.linkWithCredential(credential);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  Future<void> updatePassword(String password) async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Please sign in again.',
      );
    }

    await user.updatePassword(password);
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Firebase sign-out should still complete even if
      // the Google SDK has no active local session.
    }

    await _firebaseAuth.signOut();
  }
}
