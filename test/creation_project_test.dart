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
}
