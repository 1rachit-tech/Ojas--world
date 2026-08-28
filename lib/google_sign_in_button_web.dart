import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

Widget buildPlatformGoogleSignInButton() {
  return google_web.renderButton(
    configuration: google_web.GSIButtonConfiguration(
      type: google_web.GSIButtonType.standard,
      text: google_web.GSIButtonText.continueWith,
      size: google_web.GSIButtonSize.large,
      theme: google_web.GSIButtonTheme.outline,
      shape: google_web.GSIButtonShape.rectangular,
    ),
  );
}