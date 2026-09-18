import 'dart:math' as math;

import '../domain/search_models.dart';
import '../query_processor.dart';

class SearchRanker {
  const SearchRanker();

  List<SearchResult> rank({
    required SearchQuery query,
    required Iterable<SearchIndexRow> candidates,
    required SearchUserContext userContext,
    SearchEntityType? entityFilter,
    int limit = 20,
  }) {
    final ranked = <SearchResult>[];
    final candidateList = candidates.toList(growable: false);
    final documentFrequency = <String, int>{};
    var totalDocumentLength = 0;

    for (final candidate in candidateList) {
      final terms = _candidateTerms(candidate).toSet();
      totalDocumentLength += terms.length;
      for (final term in terms) {
        documentFrequency[term] = (documentFrequency[term] ?? 0) + 1;
      }
    }

    final averageDocumentLength = candidateList.isEmpty
        ? 1.0
        : totalDocumentLength / candidateList.length;

    for (final candidate in candidateList) {
      if (!candidate.eligible) continue;
      if (entityFilter != null && candidate.entityType != entityFilter) {
        continue;
      }
      if (userContext.blockedCreatorIds.contains(candidate.creatorId) ||
          userContext.blockedCreatorIds.contains(candidate.id)) {
        continue;
      }

      final queryScore = _queryScore(
        query,
        candidate,
        documentFrequency,
        candidateList.length,
        averageDocumentLength,
      );
      if (queryScore <= 0) continue;

      final popularity = _popularity(candidate);
      final freshness = _freshness(candidate.createdAt);
      final quality = _quality(candidate);
      final trend = candidate.trendScore.clamp(0.0, 1.0);
      final personal = _personal(candidate, userContext);

      // Query relevance intentionally dominates. Personalization is a bounded
      // additive signal and can never turn an unrelated candidate into a hit.
      final score =
          (queryScore * 0.55) +
          (personal * 0.14) +
          (quality * 0.10) +
          (popularity * 0.10) +
          (freshness * 0.06) +
          (trend * 0.05);

      ranked.add(
        SearchResult(
          id: candidate.id,
          entityType: candidate.entityType,
          title: candidate.title,
          subtitle: candidate.subtitle,
          score: score,
          queryScore: queryScore,
          personalScore: personal,
          qualityScore: quality,
          popularityScore: popularity,
          freshnessScore: freshness,
          trendScore: trend,
          imageUrl: candidate.imageUrl,
          creatorId: candidate.creatorId,
          contentUrl: candidate.contentUrl,
          audioTrackId: candidate.audioTrackId,
          createdAt: candidate.createdAt,
          tags: candidate.tags,
          extra: <String, dynamic>{
            'views': candidate.views,
            'likes': candidate.likes,
            'saves': candidate.saves,
            'followers': candidate.followers,
            'posts': candidate.posts,
            'algorithmScore': candidate.algorithmScore,
            'region': candidate.region,
            'language': candidate.language,
          },
        ),
      );
    }

    ranked.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      final timeCompare =
          (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      if (timeCompare != 0) return timeCompare;
      return a.stableId.compareTo(b.stableId);
    });

    return ranked.take(limit).toList(growable: false);
  }

  List<SearchResult> blend({
    required SearchTab tab,
    required List<SearchResult> results,
    int limit = 20,
  }) {
    if (tab != SearchTab.all) {
      return results.take(limit).toList(growable: false);
    }

    final people = results
        .where((item) => item.entityType == SearchEntityType.person)
        .toList();
    final content = results
        .where((item) => item.entityType == SearchEntityType.content)
        .toList();
    final hashtags = results
        .where((item) => item.entityType == SearchEntityType.hashtag)
        .toList();
    final sounds = results
        .where((item) => item.entityType == SearchEntityType.sound)
        .toList();

    final output = <SearchResult>[];
    var peopleCursor = 0;
    var contentCursor = 0;
    var hashtagCursor = 0;
    var soundCursor = 0;

    // Keep the first results query-relevant while ensuring multiple entity
    // types can surface when the query supports them.
    while (output.length < limit &&
        (peopleCursor < people.length ||
            contentCursor < content.length ||
            hashtagCursor < hashtags.length ||
            soundCursor < sounds.length)) {
      if (peopleCursor < people.length) {
        output.add(people[peopleCursor++]);
        if (output.length >= limit) break;
      }
      for (var i = 0; i < 3 && contentCursor < content.length; i++) {
        output.add(content[contentCursor++]);
        if (output.length >= limit) break;
      }
      if (output.length >= limit) break;
      if (hashtagCursor < hashtags.length) {
        output.add(hashtags[hashtagCursor++]);
      }
      if (output.length >= limit) break;
      if (soundCursor < sounds.length) {
        output.add(sounds[soundCursor++]);
      }
    }

    return output.take(limit).toList(growable: false);
  }

  double _queryScore(
    SearchQuery query,
    SearchIndexRow candidate,
    Map<String, int> documentFrequency,
    int documentCount,
    double averageDocumentLength,
  ) {
    final terms = _candidateTerms(candidate);
    if (terms.isEmpty || documentCount == 0) return 0;

    final frequencies = <String, int>{};
    for (final term in terms) {
      frequencies[term] = (frequencies[term] ?? 0) + 1;
    }

    final queryTerms = <String>{};
    for (final alias in query.aliases) {
      final normalized = alias.trim().toLowerCase();
      if (normalized.isNotEmpty) queryTerms.add(normalized);
    }
    if (queryTerms.isEmpty) {
      queryTerms.addAll(
        query.tokens.map((token) => token.toLowerCase()),
      );
    }

    const k1 = 1.2;
    const b = 0.75;
    final documentLength = terms.length;
    var score = 0.0;

    for (final term in queryTerms) {
      final tf = frequencies[term] ?? 0;
      if (tf == 0) continue;

      final df = documentFrequency[term] ?? 0;
      final idf = ((documentCount - df + 0.5) /
              (df + 0.5) +
          1)
          math.log(((documentCount - df + 0.5) / (df + 0.5) + 1));

      final denominator =
          tf + k1 * (1 - b + b * documentLength / averageDocumentLength);
      score += idf * ((tf * (k1 + 1)) / denominator);
    }

    final exactTitle = SearchQueryProcessor.textSimilarity(
      query.normalized,
      candidate.title,
    );

    final normalizedScore = (score / 8.0).clamp(0.0, 1.0);
    final combined = normalizedScore * 0.78 + exactTitle * 0.22;

    if (combined == 0 && query.intent == candidate.entityType) {
      return 0.08;
    }
    return combined.clamp(0.0, 1.0);
  }

  List<String> _candidateTerms(SearchIndexRow candidate) {
    final source = <String>[
      candidate.title,
      candidate.subtitle,
      candidate.text,
      ...candidate.tokens,
      ...candidate.tags,
    ];

    return source
        .expand(
          (value) => value
              .toLowerCase()
              .split(RegExp(r'\s+'))
              .where((token) => token.trim().isNotEmpty),
        )
        .map((token) => token.replaceAll(RegExp(r'^[#@]'), ''))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  double _personal(
    SearchIndexRow candidate,
    SearchUserContext context,
  ) {
    final keyCandidates = <String>[
      candidate.creatorId,
      candidate.id,
      ...candidate.tags,
      candidate.audioTrackId,
      candidate.entityType.name,
    ];

    var positive = 0.0;
    var negative = 0.0;

    for (final key in keyCandidates) {
      final candidatePositive = <double>[
        context.creatorAffinity[key] ?? 0,
        context.topicAffinity[key] ?? 0,
        context.hashtagAffinity[key] ?? 0,
        context.soundAffinity[key] ?? 0,
        context.contentTypeAffinity[key] ?? 0,
      ].fold<double>(
        0,
        (best, value) => value > best ? value : best,
      );
      if (candidatePositive > positive) {
        positive = candidatePositive;
      }

      final candidateNegative = context.negativeAffinity[key] ?? 0;
      if (candidateNegative > negative) {
        negative = candidateNegative;
      }
    }

    return ((positive - negative + 5) / 10).clamp(0.0, 1.0);
  }

  double _popularity(SearchIndexRow candidate) {
    final weighted =
        candidate.views +
        (candidate.likes * 8) +
        (candidate.saves * 12) +
        (candidate.followers * 2) +
        (candidate.posts * 1.5);
    return (weighted / 1000000).clamp(0.0, 1.0).toDouble();
  }

  double _quality(SearchIndexRow candidate) {
    final score = candidate.algorithmScore;
    if (score <= 0) {
      if (candidate.views <= 0) return 0.35;
      final engagement =
          (candidate.likes + candidate.saves * 1.5) / candidate.views;
      return (engagement * 8).clamp(0.0, 1.0).toDouble();
    }
    return score.clamp(0.0, 1.0);
  }

  double _freshness(DateTime? createdAt) {
    if (createdAt == null) return 0.35;
    final hours = DateTime.now().difference(createdAt).inHours.abs();
    return (1.0 / (1.0 + (hours / 168.0))).clamp(0.0, 1.0);
  }
}
