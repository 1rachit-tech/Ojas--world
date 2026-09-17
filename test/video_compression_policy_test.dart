import 'package:flutter_test/flutter_test.dart';
import 'package:ojas_app/services/video_compression_service.dart';

void main() {
  group('video delivery tier policy', () {
    test('maps 360p portrait input to 360p', () {
      expect(
        VideoCompressionService.selectTier(width: 360, height: 640),
        VideoDeliveryTier.tier360,
      );
    });

    test('maps 480p portrait input to 480p', () {
      expect(
        VideoCompressionService.selectTier(width: 480, height: 854),
        VideoDeliveryTier.tier480,
      );
    });

    test('maps HD and higher source to 720p delivery tier', () {
      expect(
        VideoCompressionService.selectTier(width: 1080, height: 1920),
        VideoDeliveryTier.tier720,
      );
      expect(
        VideoCompressionService.selectTier(width: 2160, height: 3840),
        VideoDeliveryTier.tier720,
      );
    });

    test('uses the smaller dimension so landscape preserves aspect ratio', () {
      expect(
        VideoCompressionService.selectTier(width: 854, height: 480),
        VideoDeliveryTier.tier480,
      );
    });
  });
}
