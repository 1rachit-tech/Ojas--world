import 'package:flutter_test/flutter_test.dart';
import 'package:ojas_app/services/message_memory_window.dart';

void main() {
  test('keeps at most the configured number from a 10,000-message history', () {
    final messages = List<int>.generate(10000, (index) => index);

    final window = MessageMemoryWindow.takeNewest(messages, 400);

    expect(window, hasLength(400));
    expect(window.first, 0);
    expect(window.last, 399);
  });

  test('does not truncate smaller conversations', () {
    final messages = List<int>.generate(120, (index) => index);

    final window = MessageMemoryWindow.takeNewest(messages, 400);

    expect(window, hasLength(120));
    expect(window, orderedEquals(messages));
  });

  test('zero or negative limits return an empty window', () {
    final messages = <int>[1, 2, 3];

    expect(MessageMemoryWindow.takeNewest(messages, 0), isEmpty);
    expect(MessageMemoryWindow.takeNewest(messages, -1), isEmpty);
  });
}
