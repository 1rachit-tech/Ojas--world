import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/creation/models/creation_project.dart';

void main() {
  test('CreationProject round trips through encoded local state', () {
    final project = CreationProject.createForAsset(
      ownerId: 'user-1',
      localUri: '/tmp/video.mp4',
      isVideo: true,
      sizeBytes: 1024,
      durationMs: 12000,
    ).copyWith(
      caption: 'Hello OJAS',
      privacy: 'Followers',
      status: CreationProjectStatus.autosaved,
    );

    final restored = CreationProject.fromEncoded(project.encode());

    expect(restored.projectId, project.projectId);
    expect(restored.ownerId, 'user-1');
    expect(restored.caption, 'Hello OJAS');
    expect(restored.privacy, 'Followers');
    expect(restored.status, CreationProjectStatus.autosaved);
    expect(restored.mediaAssets.single.type, 'video');
    expect(restored.timeline.single.sourceId, restored.mediaAssets.single.assetId);
  });

  test('CreationProject keeps original source reference', () {
    const path = '/tmp/source.mp4';
    final project = CreationProject.createForAsset(
      ownerId: 'user-1',
      localUri: path,
      isVideo: true,
    );

    expect(project.mediaAssets.single.localUri, path);
    expect(File(path).path, path);
  });

  test('CreationMediaAsset can point to a normalized export without replacing source', () {
    final project = CreationProject.createForAsset(
      ownerId: 'user-1',
      localUri: '/tmp/source.mp4',
      isVideo: true,
      sizeBytes: 2048,
      durationMs: 12000,
    );

    final asset = project.mediaAssets.single.copyWith(
      normalizedUri: '/tmp/normalized.mp4',
      sizeBytes: 1024,
      durationMs: 7000,
    );

    expect(asset.localUri, '/tmp/source.mp4');
    expect(asset.normalizedUri, '/tmp/normalized.mp4');
    expect(asset.sizeBytes, 1024);
    expect(asset.durationMs, 7000);
  });

  test('CreationTimelineClip keeps trim boundaries independently from timeline bounds', () {
    const clip = CreationTimelineClip(
      clipId: 'clip',
      sourceId: 'asset',
      startMs: 0,
      endMs: 12000,
    );

    final trimmed = clip.copyWith(
      trimInMs: 2500,
      trimOutMs: 9000,
    );

    expect(trimmed.startMs, 0);
    expect(trimmed.endMs, 12000);
    expect(trimmed.trimInMs, 2500);
    expect(trimmed.trimOutMs, 9000);
  });

  test('CreationProject persists renderedUri and clip audio volume', () {
    final project = CreationProject.createForAsset(
      ownerId: 'user-1',
      localUri: '/tmp/source.mp4',
      isVideo: true,
      durationMs: 12000,
    ).copyWith(
      renderedUri: '/tmp/final.mp4',
      timeline: <CreationTimelineClip>[
        const CreationTimelineClip(
          clipId: 'clip-1',
          sourceId: 'asset-1',
          startMs: 0,
          endMs: 12000,
          originalVolume: 0.35,
        ),
      ],
    );

    final restored = CreationProject.fromEncoded(project.encode());

    expect(restored.renderedUri, '/tmp/final.mp4');
    expect(restored.timeline.single.originalVolume, 0.35);
  });

  test('CreationProject can explicitly clear renderedUri after an edit', () {
    final project = CreationProject.createForAsset(
      ownerId: 'user-1',
      localUri: '/tmp/source.mp4',
      isVideo: true,
    ).copyWith(renderedUri: '/tmp/final.mp4');

    final edited = project.copyWith(renderedUri: null);

    expect(project.renderedUri, '/tmp/final.mp4');
    expect(edited.renderedUri, isNull);
  });

}