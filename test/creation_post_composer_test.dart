import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/creation/models/creation_project.dart';
import 'package:ojas_app/creation/screens/creation_post_composer_screen.dart';

void main() {
  testWidgets('post composer renders publish controls for a video project', (tester) async {
    final project = CreationProject.createForAsset(
      ownerId: 'test-user',
      localUri: '/tmp/video.mp4',
      isVideo: true,
      sizeBytes: 1024,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CreationPostComposerScreen(project: project),
      ),
    );

    expect(find.text('Post'), findsOneWidget);
    expect(find.text('Caption'), findsOneWidget);
    expect(find.text('Audience'), findsOneWidget);
    expect(find.text('Engagement & recommendations'), findsOneWidget);
    expect(find.text('Publish to OJAS'), findsOneWidget);
  });
}
