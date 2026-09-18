import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/creation/models/creation_project.dart';
import 'package:ojas_app/creation/services/creation_metadata_pipeline_service.dart';

void main() {
  test('metadata pipeline derives bounded hashtags and mentions', () {
    final project = CreationProject.createForAsset(
      ownerId: 'user-1',
      localUri: '/tmp/video.mp4',
      isVideo: true,
      sizeBytes: 1024,
      durationMs: 1000,
    ).copyWith(
      caption: 'Hello #OJAS #Bagheli @Rachit this is a Show',
      publishState: <String, dynamic>{
        'composer': <String, dynamic>{
          'hashtags': <Map<String, dynamic>>[
            <String, dynamic>{'tag': 'vindhya'},
            <String, dynamic>{'tag': '#OJAS'},
          ],
          'mentions': <Map<String, dynamic>>[
            <String, dynamic>{'handle': 'Creator.One'},
          ],
          'audioMetadata': <String, dynamic>{
            'trackId': 'track-123',
            'title': 'Original audio',
          },
          'location': <String, dynamic>{
            'city': 'Satna',
            'region': 'Madhya Pradesh',
          },
        },
        'shopItemIds': <String>['item-1', 'item-2', 'item-1'],
      },
    );

    final result = CreationMetadataPipelineService.build(project);

    expect(result.hashtags, containsAll(<String>['vindhya', 'ojas', 'bagheli']));
    expect(result.mentions, containsAll(<String>['creator.one', 'rachit']));
    expect(result.audioTrackId, 'track-123');
    expect(result.audioMetadata['title'], 'Original audio');
    expect(result.location['city'], 'Satna');
    expect(result.shopItemIds, <String>['item-1', 'item-2']);
    expect(result.searchTokens, containsAll(<String>['hello', 'ojas', 'bagheli', 'rachit']));
  });

  test('metadata pipeline bounds duplicate commerce ids and search tokens', () {
    final ids = List<String>.generate(40, (index) => 'item-$index');
    final project = CreationProject.createForAsset(
      ownerId: 'user-1',
      localUri: '/tmp/video.mp4',
      isVideo: true,
      sizeBytes: 1024,
      durationMs: 1000,
    ).copyWith(
      caption: List<String>.filled(150, 'keyword').join(' '),
      publishState: <String, dynamic>{
        'shopItemIds': ids,
      },
    );

    final result = CreationMetadataPipelineService.build(project);

    expect(result.shopItemIds, hasLength(32));
    expect(result.searchTokens.length, lessThanOrEqualTo(100));
    expect(result.searchTokens, contains('keyword'));
  });
}
