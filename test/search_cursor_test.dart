import 'dart:convert';

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
    final cursor = base64Url.encode(
      utf8.encode('content:legacy'),
    );

    expect(SearchCursorCodec.decode(cursor), 'content:legacy');
  });
}
