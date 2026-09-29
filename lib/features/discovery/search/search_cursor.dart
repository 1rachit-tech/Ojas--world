import 'dart:convert';

class SearchCursorCodec {
  SearchCursorCodec._();

  static const String _prefix = 'local:v1:';

  static String encode(String stableId) {
    final value = stableId.trim();
    if (value.isEmpty || value.length > 512) {
      throw ArgumentError('Invalid local search cursor value.');
    }

    return base64Url.encode(
      utf8.encode(_prefix + value),
    );
  }

  static String? decode(String cursor) {
    final value = cursor.trim();
    if (value.isEmpty || value.length > 1024) return null;

    try {
      final decoded = utf8.decode(base64Url.decode(value));
      if (decoded.startsWith(_prefix)) {
        final stableId = decoded.substring(_prefix.length);
        return stableId.isEmpty ? null : stableId;
      }

      // Backward compatibility with local cursors issued before v1 prefixing.
      if (!decoded.contains('{') && decoded.length <= 512) {
        return decoded;
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
