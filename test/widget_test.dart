// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/main.dart';

void main() {
  testWidgets('OJAS feed and navigation render', (WidgetTester tester) async {
    await tester.pumpWidget(const OjasApp());

    expect(find.text('OJAS'), findsOneWidget);
    expect(find.text('Your creative space'), findsOneWidget);
    expect(find.text('Maya Chen'), findsOneWidget);

    await tester.tap(find.text('Discover'));
    await tester.pump();

    expect(find.text('Discover'), findsAtLeastNWidgets(1));
    expect(find.text('Create something'), findsNothing);
  });
}
