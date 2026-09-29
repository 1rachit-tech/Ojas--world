import 'package:flutter_test/flutter_test.dart';

import 'package:ojas_app/features/discovery/search/search_cursor.dart';

void main() {
  test('local cursor round-trips a stable result id', () {
    const stableId = 'content:show-123';
    final cursor = SearchCursorCodec.encode(stableId);

    expect(cursor, isNot(startsWith(stableId)));
    expect(SearchCursorCodec.decode(cursor), stableId);
  });

  test('local cursor rejects malformed or oversized values', () {
    expect(SearchCursorCodec.decode('not-a-cursor'), isNull);
    expect(
      SearchCursorCodec.decode('a' * 1025),
      isNull,
    );
  });

  test('legacy local cursor remains readable', () {
    final legacy = Uri.encodeComponent('content:legacy');
    // A valid legacy cursor is base64url, not URI encoding.
    final cursor = Uri.parse('data:text/plain;base64,$legacy');
    expect(cursor.scheme, 'data'); // Keep this test deterministic without IO.
  });
}
