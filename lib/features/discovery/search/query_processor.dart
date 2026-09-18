import 'dart:math' as math;

import 'domain/search_models.dart';

class SearchQueryProcessor {
  const SearchQueryProcessor();

  SearchQuery process(String raw) {
    final normalized = normalize(raw);
    final tokens = _tokenize(normalized);
    final aliases = <String>{...tokens};
    for (final token in tokens) {
      if (token.startsWith('#') || token.startsWith('@')) {
        final bare = token.substring(1).trim();
        if (bare.isNotEmpty) aliases.add(bare);
      }
    }

    for (final token in tokens) {
      final sourceToken =
          token.startsWith('#') || token.startsWith('@')
              ? token.substring(1)
              : token;
      final transliterated = _transliterate(sourceToken);
      if (transliterated.isNotEmpty) {
        aliases.add(transliterated);
      }
      aliases.addAll(_synonyms[token] ?? const <String>{});
      if (transliterated.isNotEmpty) {
        aliases.addAll(_synonyms[transliterated] ?? const <String>{});
      }
    }

    final language = _detectLanguage(normalized);
    final intent = _detectIntent(normalized, tokens);

    return SearchQuery(
      raw: raw,
      normalized: normalized,
      tokens: tokens,
      aliases: aliases.take(40).toList(growable: false),
      language: language,
      intent: intent,
    );
  }

  String normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _tokenize(String value) {
    final tokens = <String>[];
    for (final rawToken in value.split(RegExp(r'\s+'))) {
      var token = rawToken.trim();
      if (token.isEmpty) continue;
      token = token.replaceFirst(RegExp(r'^[.,!?;:()\[\]{}"\x27]+'), '');
      token = token.replaceFirst(RegExp(r'[.,!?;:()\[\]{}"\x27]+$'), '');
      if (token.length < 1) continue;
      tokens.add(token);
    }
    return tokens.take(12).toList(growable: false);
  }

  String _detectLanguage(String value) {
    if (value.isEmpty) return 'unknown';
    var devanagari = 0;
    var latin = 0;
    var otherIndian = 0;

    for (final rune in value.runes) {
      if (rune >= 0x0900 && rune <= 0x097F) {
        devanagari++;
      } else if ((rune >= 0x0041 && rune <= 0x007A) ||
          (rune >= 0x00C0 && rune <= 0x024F)) {
        latin++;
      } else if ((rune >= 0x0B80 && rune <= 0x0BFF) ||
          (rune >= 0x0C00 && rune <= 0x0C7F) ||
          (rune >= 0x0A80 && rune <= 0x0AFF) ||
          (rune >= 0x0980 && rune <= 0x09FF)) {
        otherIndian++;
      }
    }

    if (devanagari > 0 && latin > 0) return 'hi-Latn-mixed';
    if (devanagari > 0) return 'hi';
    if (otherIndian > 0) return 'regional';
    return 'en';
  }

  SearchEntityType _detectIntent(String normalized, List<String> tokens) {
    if (normalized.startsWith('#')) return SearchEntityType.hashtag;
    if (normalized.startsWith('@')) return SearchEntityType.person;

    const creatorWords = <String>{
      'creator',
      'creators',
      'user',
      'users',
      'profile',
      'profiles',
    };
    const soundWords = <String>{
      'sound',
      'sounds',
      'audio',
      'song',
      'songs',
      'music',
      'गाना',
      'गाने',
      'गीत',
    };
    const videoWords = <String>{
      'video',
      'videos',
      'show',
      'clip',
      'clips',
    };
    const topicWords = <String>{
      'topic',
      'topics',
      'क्यों',
      'कैसे',
      'how',
      'why',
    };

    final set = tokens.toSet();
    if (set.any(creatorWords.contains)) return SearchEntityType.person;
    if (set.any(soundWords.contains)) return SearchEntityType.sound;
    if (set.any(videoWords.contains)) return SearchEntityType.content;
    if (set.any(topicWords.contains)) return SearchEntityType.topic;
    return SearchEntityType.generic;
  }

  String _transliterate(String input) {
    if (input.isEmpty) return '';

    const consonants = <String, String>{
      'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ng',
      'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'ny',
      'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n',
      'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
      'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm',
      'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'श': 'sh',
      'ष': 'sh', 'स': 's', 'ह': 'h', 'ळ': 'l',
      'क़': 'q', 'ख़': 'kh', 'ग़': 'gh', 'ज़': 'z', 'फ़': 'f',
    };
    const matras = <String, String>{
      'ा': 'aa', 'ि': 'i', 'ी': 'ee', 'ु': 'u', 'ू': 'oo',
      'ृ': 'ri', 'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au',
      'ं': 'n', 'ँ': 'n', 'ः': 'h', '्': '',
    };
    const vowels = <String, String>{
      'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u',
      'ऊ': 'oo', 'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai', 'ओ': 'o',
      'औ': 'au', 'अं': 'an', 'अः': 'ah',
    };

    final out = StringBuffer();
    final chars = input.split('');
    for (var i = 0; i < chars.length; i++) {
      final char = chars[i];
      if (consonants.containsKey(char)) {
        var value = consonants[char]!;
        final hasFollowingMatra =
            i + 1 < chars.length && matras.containsKey(chars[i + 1]);
        if (!hasFollowingMatra) value += 'a';
        out.write(value);
        continue;
      }
      if (matras.containsKey(char)) {
        out.write(matras[char]);
        continue;
      }
      if (vowels.containsKey(char)) {
        out.write(vowels[char]);
        continue;
      }
      out.write(char);
    }

    final result = out.toString();
    return result
        .replaceAll('aaai', 'ai')
        .replaceAll('aau', 'au')
        .replaceAll('aaa', 'aa')
        .replaceAll('vv', 'v')
        .replaceAll('aah', 'ah')
        .replaceAll(RegExp(r'[^a-z0-9_#@]+'), '');
  }

  static const Map<String, Set<String>> _synonyms =
      <String, Set<String>>{
    'गाना': <String>{'song', 'music', 'audio'},
    'गाने': <String>{'song', 'songs', 'music', 'audio'},
    'गीत': <String>{'song', 'songs', 'music'},
    'संगीत': <String>{'music', 'song', 'songs'},
    'बारिश': <String>{'barish', 'baarish', 'rain'},
    'बारिस': <String>{'barish', 'baarish', 'rain'},
    'क्रिकेट': <String>{'cricket', 'kriket'},
    'कपड़े': <String>{'clothes', 'fashion'},
    'कपड़ा': <String>{'clothes', 'fashion'},
    'प्यार': <String>{'love', 'romance'},
    'प्रेम': <String>{'love', 'romance'},
    'खाना': <String>{'food'},
    'यात्रा': <String>{'travel', 'trip'},
    'नृत्य': <String>{'dance'},
    'डांस': <String>{'dance'},
    'song': <String>{'गाना', 'music'},
    'songs': <String>{'गाने', 'music'},
    'rain': <String>{'बारिश', 'barish', 'baarish'},
    'cricket': <String>{'क्रिकेट'},
    'music': <String>{'संगीत', 'गाना'},
  };

  static double textSimilarity(String query, String candidate) {
    final q = query.trim().toLowerCase();
    final c = candidate.trim().toLowerCase();
    if (q.isEmpty || c.isEmpty) return 0;

    if (q == c) return 1.0;
    if (c.startsWith(q)) return 0.88;
    if (c.contains(q)) return 0.72;

    final qTokens = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final cTokens = c.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (qTokens.isEmpty || cTokens.isEmpty) return 0;

    var matched = 0;
    for (final token in qTokens) {
      if (cTokens.any((candidateToken) =>
          candidateToken.startsWith(token) || token.startsWith(candidateToken))) {
        matched++;
      }
    }
    return (matched / math.max(1, qTokens.length)) * 0.62;
  }

  static String? didYouMean(String query, Iterable<String> candidates) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 3) return null;

    String? best;
    var bestDistance = 999;

    for (final candidate in candidates) {
      final value = candidate.trim().toLowerCase();
      if (value.length < 3) continue;
      if ((value.length - normalized.length).abs() > 2) continue;
      final distance = _levenshtein(normalized, value);
      if (distance < bestDistance && distance <= 2) {
        bestDistance = distance;
        best = candidate;
      }
    }
    return best;
  }

  static int _levenshtein(String a, String b) {
    final previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      var diagonal = previous[0];
      previous[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final above = previous[j + 1];
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        previous[j + 1] = math.min(
          math.min(previous[j + 1] + 1, previous[j] + 1),
          diagonal + cost,
        );
        diagonal = above;
      }
    }
    return previous[b.length];
  }
}
