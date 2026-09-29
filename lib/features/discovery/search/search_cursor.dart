import 'dart:convert';

class SearchCursorCodec {
  SearchCursorCodec._();

  static const String _prefix = 'local:v1:';
  static const int _maxPayloadBytes = 768;
  static const int _maxEncodedBytes = 1024;

  static String encode(String stableId) {
    final value = stableId.trim();
    if (value.isEmpty) {
      throw ArgumentError('Invalid local search cursor value.');
    }

    final payload = utf8.encode(_prefix + value);
    if (payload.length > _maxPayloadBytes) {
      throw ArgumentError('Local search cursor value is too large.');
    }

    final encoded = base64Url.encode(payload);
    if (encoded.length > _maxEncodedBytes) {
      throw ArgumentError('Local search cursor is too large.');
    }

    return encoded;
  }

  static bool isLocal(String cursor) {
    final value = cursor.trim();
    if (value.isEmpty || value.length > _maxEncodedBytes) return false;

    try {
      final decoded = utf8.decode(base64Url.decode(value));
      if (decoded.startsWith(_prefix)) return true;

      // Legacy local cursors contained the result stable id directly.
      return RegExp(r'^(?:person|content|hashtag|sound|topic|place|live|generic):[^:]+
    } catch (_) {
      return false;
    }
  }

  static String? decode(String cursor) {
    final value = cursor.trim();
    if (value.isEmpty || value.length > _maxEncodedBytes) return null;

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
)
          .hasMatch(decoded);
    } catch (_) {
      return false;
    }
  }

  static String? decode(String cursor) {
    final value = cursor.trim();
    if (value.isEmpty || value.length > _maxEncodedBytes) return null;

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
