import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/creation/models/creation_project.dart';
import 'package:ojas_app/creation/services/creation_edit_command_service.dart';

void main() {
  const engine = CreationEditCommandService();

  CreationProject project() {
    return CreationProject.createForAsset(
      ownerId: 'u1',
      localUri: '/tmp/video.mp4',
      isVideo: true,
      sizeBytes: 100,
      durationMs: 10000,
    );
  }

  test('trim changes timeline without changing source asset', () {
    final source = project();
    final clip = source.timeline.single;
    final updated = engine.trimClip(
      source,
      clipId: clip.clipId,
      trimInMs: 1000,
      trimOutMs: 7000,
    );

    expect(updated.mediaAssets.single.localUri, source.mediaAssets.single.localUri);
    expect(updated.timeline.single.trimInMs, 1000);
    expect(updated.timeline.single.trimOutMs, 7000);
    expect(updated.timeline.single.trimmedDurationMs, 6000);
    expect(updated.version, greaterThan(source.version));
    expect(updated.operations.last['type'], 'trim');
  });

  test('split creates two timeline clips sharing the same source', () {
    final source = project();
    final clip = source.timeline.single;
    final updated = engine.splitClip(source, clipId: clip.clipId, splitAtMs: 5000);

    expect(updated.timeline, hasLength(2));
    expect(updated.timeline[0].sourceId, clip.sourceId);
    expect(updated.timeline[1].sourceId, clip.sourceId);
    expect(updated.operations.last['type'], 'split');
  });

  test('delete does not allow the project to become timeline-less', () {
    final source = project();
    final clip = source.timeline.single;
    final unchanged = engine.deleteClip(source, clipId: clip.clipId);
    expect(unchanged.timeline, hasLength(1));
    expect(unchanged.version, source.version);

    final split = engine.splitClip(source, clipId: clip.clipId, splitAtMs: 5000);
    final deleted = engine.deleteClip(split, clipId: split.timeline.first.clipId);
    expect(deleted.timeline, hasLength(1));
    expect(deleted.operations.last['type'], 'delete_clip');
  });

  test('reorder moves timeline clips without touching their source ids', () {
    final source = project();
    final split = engine.splitClip(source, clipId: source.timeline.single.clipId, splitAtMs: 5000);
    final first = split.timeline[0];
    final second = split.timeline[1];
    final reordered = engine.reorderClip(split, clipId: first.clipId, toIndex: 1);

    expect(reordered.timeline[0].clipId, second.clipId);
    expect(reordered.timeline[1].clipId, first.clipId);
    expect(reordered.timeline[0].sourceId, second.sourceId);
    expect(reordered.operations.last['type'], 'reorder_clip');
  });

  test('crop and opacity stay non-destructive on the timeline clip', () {
    var updated = project();
    final clip = updated.timeline.single;
    updated = engine.setCrop(
      updated,
      clipId: clip.clipId,
      left: 0.1,
      top: 0.2,
      right: 0.15,
      bottom: 0.05,
    );
    updated = engine.setTransform(updated, clipId: clip.clipId, opacity: 0.5);

    expect(updated.mediaAssets.single.localUri, '/tmp/video.mp4');
    expect(updated.timeline.single.cropLeft, 0.1);
    expect(updated.timeline.single.cropTop, 0.2);
    expect(updated.timeline.single.cropRight, 0.15);
    expect(updated.timeline.single.cropBottom, 0.05);
    expect(updated.timeline.single.opacity, 0.5);
    expect(updated.operations.map((e) => e['type']), containsAll(<String>['crop', 'transform']));
  });

  test('timed captions and audio layers remain editable instructions', () {
    var updated = project();
    updated = engine.addCaption(updated, text: 'Hello OJAS', startMs: 1000, endMs: 2500);
    updated = engine.addAudio(
      updated,
      uri: '/tmp/music.m4a',
      title: 'Music',
      startMs: 500,
      endMs: 8000,
      volume: 0.7,
    );
    updated = engine.setAutoCaptions(updated, enabled: true);

    expect(updated.textLayers.single['layerType'], 'caption');
    expect(updated.textLayers.single['startMs'], 1000);
    expect(updated.textLayers.single['endMs'], 2500);
    expect(updated.audio.single['volume'], 0.7);
    expect(updated.audio.single['startMs'], 500);
    expect(updated.accessibility['autoCaptions'], isTrue);
    expect(updated.operations.map((e) => e['type']), containsAll(<String>['caption_add', 'audio_add', 'accessibility_update']));
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
    expect(updated.renderedDurationMs, 5000);
    expect(updated.textLayers, hasLength(1));
    expect(updated.effectLayers, hasLength(1));
    expect(updated.operations.length, greaterThanOrEqualTo(4));
  });
}
