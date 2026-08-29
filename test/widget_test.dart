// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/main.dart';
import 'package:ojas_app/screens/create_screen.dart';
import 'package:ojas_app/services/auth_guard.dart';

void main() {
  testWidgets('OJAS feed and navigation render', (WidgetTester tester) async {
    await tester.pumpWidget(const OjasApp());

    expect(find.text('OJAS'), findsOneWidget);
    expect(find.text('Your creative space'), findsOneWidget);
    expect(find.text('Maya Chen'), findsOneWidget);

    await tester.tap(find.byTooltip('OJS'));
    await tester.pump();

    expect(find.text('For You'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);

    await tester.tap(find.byTooltip('World'));
    await tester.pump();

    expect(find.text('World'), findsAtLeastNWidgets(1));
    expect(find.text('Create something'), findsNothing);
  });

  testWidgets('Create tabs switch and camera fallback is visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateScreen()));

    expect(find.byType(CreateScreen), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.text('Tap record to activate your camera.'), findsOneWidget);
  });

  testWidgets('profile verification timeout becomes a retryable error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    final pendingCheck = Completer<bool>();
    final verification = ensureProfile(
      tester.element(find.byType(SizedBox)),
      profileCheck: () => pendingCheck.future,
      timeout: const Duration(milliseconds: 1),
    );
    final expectedError = expectLater(
      verification,
      throwsA(isA<AuthGuardException>()),
    );
    await tester.pump(const Duration(milliseconds: 2));

    await expectedError;
  });
}
