class MessageMemoryWindow {
  const MessageMemoryWindow._();

  static List<T> takeNewest<T>(
    Iterable<T> messages,
    int maxItems,
  ) {
    if (maxItems <= 0) {
      return const <Never>[] as List<T>;
    }

    final list = messages.toList(growable: false);
    if (list.length <= maxItems) {
      return List<T>.unmodifiable(list);
    }

    return List<T>.unmodifiable(
      list.take(maxItems),
    );
  }
}
