import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import 'auth_service.dart';

Future<void> requireAuth(
  BuildContext context,
  VoidCallback onAuthenticated,
) async {
  if (AuthService.instance.currentUser != null) {
    onAuthenticated();
    return;
  }

  final authenticated = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => const LoginScreen()),
  );
  if (authenticated == true && context.mounted) {
    onAuthenticated();
  }
}