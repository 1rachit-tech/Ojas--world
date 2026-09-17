import 'package:flutter_test/flutter_test.dart';

import 'package:ojas/creation/models/creation_project.dart';
import 'package:ojas/creation/services/creation_edit_command_service.dart';

void main() {
  final engine = const CreationEditCommandService();

  CreationProject project() {
    return CreationProject.createForAsset(
      ownerId: 'u1',
      localUri: '/tmp/video.mp4',
      isVideo: true,
      sizeBytes: 100,
      durationMs: 10_000,
    );
  }

  test('trim changes timeline without changing source asset', () {
    final source = project();
    final clip = source.timeline.single;
    final updated = engine.trimClip(
      source,
      clipId: clip.clipId,
      trimInMs: 1_000,
      trimOutMs: 7_000,
    );

    expect(updated.mediaAssets.single.localUri, source.mediaAssets.single.localUri);
    expect(updated.timeline.single.trimInMs, 1_000);
    expect(updated.timeline.single.trimOutMs, 7_000);
    expect(updated.version, greaterThan(source.version));
    expect(updated.operations.last['type'], 'trim');
  });

  test('split creates two timeline clips sharing the same source', () {
    final source = project();
    final clip = source.timeline.single;
    final updated = engine.splitClip(source, clipId: clip.clipId, splitAtMs: 5_000);

    expect(updated.timeline, hasLength(2));
    expect(updated.timeline[0].sourceId, clip.sourceId);
    expect(updated.timeline[1].sourceId, clip.sourceId);
    expect(updated.operations.last['type'], 'split');
  });

  test('speed, transform and layers are persisted as edit instructions', () {
    var updated = project();
    final clip = updated.timeline.single;
    updated = engine.setSpeed(updated, clipId: clip.clipId, speed: 2);
    updated = engine.setTransform(updated, clipId: clip.clipId, rotation: 90, scale: 1.25);
    updated = engine.addText(updated, text: 'OJAS');
    updated = engine.addEffect(updated, effectId: 'warm');

    expect(updated.timeline.single.speed, 2);
    expect(updated.timeline.single.rotation, 90);
    expect(updated.timeline.single.scale, 1.25);
    expect(updated.textLayers, hasLength(1));
    expect(updated.effectLayers, hasLength(1));
    expect(updated.operations.length, greaterThanOrEqualTo(4));
  });
}
