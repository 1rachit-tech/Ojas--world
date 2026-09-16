import 'package:flutter_test/flutter_test.dart';
import 'package:ojas/creation/models/creation_publish_state.dart';
import 'package:ojas/creation/models/creation_post_composer.dart';

void main() {
  test('publish state clamps upload progress and round-trips', () {
    final state = CreationPublishState(
      projectId: 'project-1',
      stage: CreationPublishStage.uploading,
      requestId: 'request-1',
      bytesUploaded: 120,
      totalBytes: 100,
    );

    expect(state.progress, 1.0);
    expect(state.isTerminal, isFalse);

    final restored = CreationPublishState.fromMap(state.toMap());
    expect(restored.projectId, 'project-1');
    expect(restored.stage, CreationPublishStage.uploading);
    expect(restored.requestId, 'request-1');
  });

  test('composer preserves structured mentions and hashtags', () {
    const composer = CreationPostComposer(
      caption: 'Hello @rachit #ojas',
      mentions: <CreationMentionEntity>[
        CreationMentionEntity(userId: 'u1', handle: 'rachit', start: 6, end: 12),
      ],
      hashtags: <CreationHashtagEntity>[
        CreationHashtagEntity(tag: 'ojas', start: 13, end: 18),
      ],
      aiGeneratedDisclosure: true,
    );

    final restored = CreationPostComposer.fromMap(composer.toMap());
    expect(restored.mentions.single.userId, 'u1');
    expect(restored.hashtags.single.tag, 'ojas');
    expect(restored.aiGeneratedDisclosure, isTrue);
  });
}
