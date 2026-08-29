import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/profile_setup_screen.dart';
import 'auth_service.dart';
import 'profile_service.dart';

const _profileVerificationTimeout = Duration(seconds: 10);

Future<bool> ensureProfile(
  BuildContext context, {
  Future<bool> Function()? profileCheck,
  Duration timeout = _profileVerificationTimeout,
}) async {
  try {
    final check = profileCheck ?? ProfileService.instance.hasCompletedProfile;
    if (await check().timeout(timeout)) {
      return true;
    }
    if (!context.mounted) return false;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ProfileSetupScreen()),
    );
    return completed == true;
  } on TimeoutException {
    throw const AuthGuardException(
      "Couldn't verify your profile. Check your connection and try again.",
    );
  } on FirebaseException {
    throw const AuthGuardException(
      "Couldn't verify your profile. Check your connection and try again.",
    );
  }
}

Future<void> requireAuth(
  BuildContext context,
  VoidCallback onAuthenticated, {
  ValueChanged<bool>? onLoadingChanged,
  ValueChanged<String>? onError,
  Future<bool> Function()? profileCheck,
  Duration profileTimeout = _profileVerificationTimeout,
}) async {
  onLoadingChanged?.call(true);
  try {
    if (AuthService.instance.currentUser != null) {
      if (await ensureProfile(
        context,
        profileCheck: profileCheck,
        timeout: profileTimeout,
      )) {
        onAuthenticated();
      }
      return;
    }

    final authenticated = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const LoginScreen()));
    if (authenticated == true &&
        context.mounted &&
        await ensureProfile(
          context,
          profileCheck: profileCheck,
          timeout: profileTimeout,
        )) {
      onAuthenticated();
    }
  } on AuthGuardException catch (exception) {
    onError?.call(exception.message);
  } finally {
    onLoadingChanged?.call(false);
  }
}

class AuthGuardException implements Exception {
  const AuthGuardException(this.message);

  final String message;
}
