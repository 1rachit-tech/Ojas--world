import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/features/discovery/search/safety/search_safety_service.dart';

void main() {
  test('allows only public eligible clean search documents', () {
    expect(
      SearchSafetyService.isEligible(<String, dynamic>{
        'eligible': true,
        'visibility': 'public',
        'safetyStatus': 'clean',
      }),
      isTrue,
    );
  });

  test('rejects deleted, banned and private documents', () {
    expect(
      SearchSafetyService.isEligible(<String, dynamic>{
        'eligible': true,
        'visibility': 'private',
        'safetyStatus': 'clean',
      }),
      isFalse,
    );
    expect(
      SearchSafetyService.isEligible(<String, dynamic>{
        'eligible': false,
        'visibility': 'public',
        'safetyStatus': 'clean',
      }),
      isFalse,
    );
    expect(
      SearchSafetyService.isEligible(<String, dynamic>{
        'eligible': true,
        'visibility': 'public',
        'safetyStatus': 'restricted',
      }),
      isFalse,
    );
    expect(
      SearchSafetyService.isEligible(<String, dynamic>{
        'eligible': true,
        'visibility': 'public',
        'safetyStatus': 'clean',
        'isDeleted': true,
      }),
      isFalse,
    );
  });
}
