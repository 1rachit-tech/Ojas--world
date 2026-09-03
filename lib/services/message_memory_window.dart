class MessageMemoryWindow {
  const MessageMemoryWindow._();

  static List<T> takeNewest<T>(
    Iterable<T> messages,
    int maxItems,
  ) {
    if (maxItems <= 0) {
      return List<T>.empty(growable: false);
    }

    final list = messages.toList(growable: false);
    if (list.length <= maxItems) {
      return List<T>.unmodifiable(list);
    }

    return List<T>.unmodifiable(list.take(maxItems));
  }
}
