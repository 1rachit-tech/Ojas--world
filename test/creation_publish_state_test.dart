import 'package:flutter_test/flutter_test.dart';
import 'package:ojas_app/creation/models/creation_publish_state.dart';
import 'package:ojas_app/creation/models/creation_post_composer.dart';
import 'package:ojas_app/services/video_compression_service.dart';

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

  test('device delivery tier maps source short-side to 360p, 480p and 720p', () {
    expect(
      VideoCompressionService.selectTier(width: 360, height: 640),
      VideoDeliveryTier.tier360,
    );
    expect(
      VideoCompressionService.selectTier(width: 480, height: 854),
      VideoDeliveryTier.tier480,
    );
    expect(
      VideoCompressionService.selectTier(width: 1080, height: 1920),
      VideoDeliveryTier.tier720,
    );
    expect(
      VideoCompressionService.selectTier(width: 3840, height: 2160),
      VideoDeliveryTier.tier720,
    );
  });
}
