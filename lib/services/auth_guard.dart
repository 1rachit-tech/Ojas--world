import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/profile_setup_screen.dart';
import 'auth_service.dart';
import 'profile_service.dart';

Future<bool> ensureProfile(BuildContext context) async {
  try {
    if (await ProfileService.instance.hasCompletedProfile()) return true;
    if (!context.mounted) return false;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ProfileSetupScreen()),
    );
    return completed == true;
  } on FirebaseException {
    return false;
  }
}

Future<void> requireAuth(
  BuildContext context,
  VoidCallback onAuthenticated,
) async {
  if (AuthService.instance.currentUser != null) {
    if (await ensureProfile(context)) onAuthenticated();
    return;
  }

  final authenticated = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => const LoginScreen()),
  );
  if (authenticated == true && context.mounted && await ensureProfile(context)) {
    onAuthenticated();
  }
}