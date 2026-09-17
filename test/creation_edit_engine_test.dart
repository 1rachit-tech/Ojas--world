import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/creation/models/creation_project.dart';
import 'package:ojas_app/creation/services/creation_edit_command_service.dart';
import 'package:ojas_app/creation/services/creation_validation_service.dart';

void main() {
  late Directory tempDir;
  late File sourceFile;
  late CreationProject project;
  const engine = CreationEditCommandService();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ojas-edit-test-');
    sourceFile = File('${tempDir.path}/clip.mp4');
    await sourceFile.writeAsBytes(List<int>.filled(32, 7));
    project = CreationProject.createForAsset(
      ownerId: 'user-1',
      localUri: sourceFile.path,
      isVideo: true,
      sizeBytes: 32,
      width: 1080,
      height: 1920,
      durationMs: 10000,
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('trim clamps to source duration without mutating the original project', () {
    final clipId = project.timeline.single.clipId;
    final next = engine.trimClip(project, clipId: clipId, trimInMs: 9000, trimOutMs: 20000);

    expect(project.timeline.single.trimInMs, 0);
    expect(project.timeline.single.trimOutMs, isNull);
    expect(next.timeline.single.trimInMs, 9000);
    expect(next.timeline.single.trimOutMs, 10000);
    expect(next.version, project.version + 1);
    expect(next.operations.single['type'], 'trim');
  });

  test('crop keeps a valid rectangle even when both sides are oversized', () {
    final clipId = project.timeline.single.clipId;
    final next = engine.setCrop(project, clipId: clipId, left: 0.9, right: 0.9, top: 0.7, bottom: 0.7);
    final clip = next.timeline.single;

    expect(clip.cropLeft + clip.cropRight, lessThan(1.0));
    expect(clip.cropTop + clip.cropBottom, lessThan(1.0));
  });

  test('split creates two independent clips with unique ids', () {
    final clipId = project.timeline.single.clipId;
    final next = engine.splitClip(project, clipId: clipId, splitAtMs: 4000);

    expect(next.timeline, hasLength(2));
    expect(next.timeline[0].clipId, isNot(next.timeline[1].clipId));
    expect(next.timeline[0].trimInMs, 0);
    expect(next.timeline[0].trimOutMs, 4000);
    expect(next.timeline[1].trimInMs, 4000);
    expect(next.timeline[1].trimOutMs, 10000);
  });

  test('validation rejects an invalid crop rectangle and oversized operation history', () async {
    final clipId = project.timeline.single.clipId;
    final invalid = engine.setCrop(project, clipId: clipId, left: 0.4, right: 0.4);
    final oversized = invalid.copyWith(
      operations: List<Map<String, dynamic>>.generate(257, (index) => <String, dynamic>{'version': index}),
    );

    final result = await CreationValidationService.validateProject(oversized);

    expect(result.isValid, isTrue);
  });

  test('validation rejects invalid timeline transforms created outside the edit engine', () async {
    final clip = project.timeline.single;
    final invalidClip = CreationTimelineClip(
      clipId: clip.clipId,
      sourceId: clip.sourceId,
      startMs: 0,
      endMs: 10000,
      cropLeft: 0.6,
      cropRight: 0.6,
      rotation: 45,
    );
    final invalidProject = project.copyWith(timeline: <CreationTimelineClip>[invalidClip]);

    final result = await CreationValidationService.validateProject(invalidProject);

    expect(result.isValid, isFalse);
    expect(result.errors.join('\n'), contains('crop'));
    expect(result.errors.join('\n'), contains('rotation'));
  });
}
