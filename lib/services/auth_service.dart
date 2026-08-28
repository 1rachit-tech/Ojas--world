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

  Future<UserCredential> signUpWithEmail(String email, String password) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    _googleInitialization ??= _googleSignIn.initialize(
      clientId: kIsWeb
          ? '1076759095973-i3dpkctmihia89dcin2q0406p57is7mv.apps.googleusercontent.com'
          : null,
    );
    await _googleInitialization;

    final GoogleSignInAccount account = await _googleSignIn.authenticate();
    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-token',
        message: 'Google sign-in did not return a valid token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _firebaseAuth.signInWithCredential(credential);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }
}