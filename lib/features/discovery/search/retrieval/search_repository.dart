import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/search_models.dart';
import '../query_processor.dart';

class SearchRepository {
  SearchRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final SearchQueryProcessor _processor = const SearchQueryProcessor();

  Future<List<SearchIndexRow>> retrieve(
    SearchQuery query, {
    SearchEntityType? entityFilter,
    int limit = 100,
  }) async {
    if (query.normalized.isEmpty) return const <SearchIndexRow>[];

    final rawRows = <SearchIndexRow>[];
    final seen = <String>{};

    try {
      final prefixes = query.prefixes;
      if (prefixes.isNotEmpty) {
        final snapshot = await _firestore
            .collection('searchIndex')
            .where('prefixes', arrayContainsAny: prefixes)
            .limit(limit.clamp(20, 100))
            .get();

        for (final document in snapshot.docs) {
          final row = SearchIndexRow.fromFirestore(document);
          if (!row.eligible) continue;

          final key = row.entityType.name + ':' + row.id;
          if (seen.add(key)) rawRows.add(row);
        }
      }
    } catch (_) {
      // The denormalized index is an optimization. Legacy retrieval keeps
      // Search functional while the index is warming or unavailable.
    }

    final derived = _deriveEntityRows(
      rawRows,
      query,
      entityFilter: entityFilter,
    );

    final output = <SearchIndexRow>[];
    final outputSeen = <String>{};

    void add(SearchIndexRow row) {
      final key = row.entityType.name + ':' + row.id;
      if (outputSeen.add(key) && row.eligible) {
        output.add(row);
      }
    }

    for (final row in rawRows) {
      if (entityFilter == null ||
          entityFilter == SearchEntityType.person ||
          entityFilter == SearchEntityType.content) {
        if (entityFilter == null || row.entityType == entityFilter) {
          add(row);
        }
      }
    }

    for (final row in derived) {
      if (entityFilter == null || row.entityType == entityFilter) {
        add(row);
      }
    }

    if (output.length < 12) {
      final legacy = await _legacyRetrieve(
        query,
        entityFilter: entityFilter,
        limit: (limit - output.length).clamp(1, limit),
      );

      for (final row in legacy) {
        add(row);
      }
    }

    return output.take(limit).toList(growable: false);
  }

  Future<List<SearchSuggestion>> suggest(
    String rawQuery, {
    int limit = 8,
  }) async {
    final query = _processor.process(rawQuery);
    final suggestions = <SearchSuggestion>[];
    final seen = <String>{};

    try {
      final prefixes = query.prefixes;
      if (prefixes.isNotEmpty) {
        final snapshot = await _firestore
            .collection('searchIndex')
            .where('prefixes', arrayContainsAny: prefixes)
            .limit(40)
            .get();

        for (final document in snapshot.docs) {
          final row = SearchIndexRow.fromFirestore(document);
          if (!row.eligible) continue;

          final label = _suggestLabel(row);
          if (label.trim().isEmpty) continue;

          final key = row.entityType.name + ':' + label.toLowerCase();
          if (!seen.add(key)) continue;

          suggestions.add(
            SearchSuggestion(
              text: label,
              subtitle: row.subtitle,
              entityType: row.entityType,
              id: row.id,
              imageUrl: row.imageUrl,
            ),
          );
          if (suggestions.length >= limit) return suggestions;
        }
      }
    } catch (_) {}

    if (suggestions.length < limit) {
      try {
        final profiles = await _firestore
            .collection('publicProfiles')
            .orderBy('ojasId')
            .startAt([query.normalized])
            .endAt([query.normalized + '\uf8ff'])
            .limit(12)
            .get();

        for (final document in profiles.docs) {
          final data = document.data();
          if (!_isEligible(data)) continue;

          final ojasId = (data['ojasId'] as String? ?? '').trim();
          final displayName = (data['displayName'] as String? ?? '').trim();
          if (ojasId.isEmpty && displayName.isEmpty) continue;

          final key = 'person:' + document.id;
          if (!seen.add(key)) continue;

          suggestions.add(
            SearchSuggestion(
              text: displayName.isEmpty ? '@' + ojasId : displayName,
              subtitle: ojasId.isEmpty ? 'OJAS creator' : '@' + ojasId,
              entityType: SearchEntityType.person,
              id: document.id,
              imageUrl: data['photoUrl'] as String? ?? '',
            ),
          );
          if (suggestions.length >= limit) break;
        }
      } catch (_) {}
    }

    return suggestions;
  }

  List<SearchIndexRow> _deriveEntityRows(
    Iterable<SearchIndexRow> source,
    SearchQuery query, {
    SearchEntityType? entityFilter,
  }) {
    final hashtags = <String, SearchIndexRow>{};
    final sounds = <String, SearchIndexRow>{};

    for (final row in source) {
      if (row.entityType != SearchEntityType.content) continue;

      for (final tag in row.tags) {
        final normalized = tag.trim().toLowerCase();
        if (normalized.isEmpty) continue;

        final score =
            SearchQueryProcessor.textSimilarity(query.normalized, normalized);
        if (score <= 0) continue;

        hashtags.putIfAbsent(
          normalized,
          () => SearchIndexRow(
            id: normalized,
            entityType: SearchEntityType.hashtag,
            title: normalized.startsWith('#')
                ? normalized
                : '#' + normalized,
            subtitle: 'OJAS hashtag',
            text: normalized,
            tags: <String>[normalized],
            posts: 1,
          ),
        );
        final current = hashtags[normalized]!;
        hashtags[normalized] = SearchIndexRow(
          id: current.id,
          entityType: current.entityType,
          title: current.title,
          subtitle: current.subtitle,
          text: current.text,
          tags: current.tags,
          posts: current.posts + 1,
          trendScore: current.trendScore + score,
        );
      }

      final sound = row.audioTrackId.trim();
      if (sound.isNotEmpty) {
        final score =
            SearchQueryProcessor.textSimilarity(query.normalized, sound);
        if (score > 0) {
          final existing = sounds[sound];
          if (existing == null) {
            sounds[sound] = SearchIndexRow(
              id: sound,
              entityType: SearchEntityType.sound,
              title: sound,
              subtitle: row.creatorId,
              text: sound,
              audioTrackId: sound,
              posts: 1,
              trendScore: score,
            );
          } else {
            sounds[sound] = SearchIndexRow(
              id: existing.id,
              entityType: existing.entityType,
              title: existing.title,
              subtitle: existing.subtitle,
              text: existing.text,
              audioTrackId: existing.audioTrackId,
              posts: existing.posts + 1,
              trendScore: existing.trendScore + score,
            );
          }
        }
      }
    }

    if (entityFilter == SearchEntityType.hashtag) {
      return hashtags.values.toList(growable: false);
    }
    if (entityFilter == SearchEntityType.sound) {
      return sounds.values.toList(growable: false);
    }

    if (entityFilter == null) {
      return <SearchIndexRow>[
        ...hashtags.values,
        ...sounds.values,
      ];
    }

    return const <SearchIndexRow>[];
  }

  Future<List<SearchIndexRow>> _legacyRetrieve(
    SearchQuery query, {
    SearchEntityType? entityFilter,
    required int limit,
  }) async {
    if (limit <= 0) return const <SearchIndexRow>[];

    final rows = <SearchIndexRow>[];

    final shouldReadProfiles =
        entityFilter == null || entityFilter == SearchEntityType.person;
    final shouldReadContent = entityFilter == null ||
        entityFilter == SearchEntityType.content ||
        entityFilter == SearchEntityType.hashtag ||
        entityFilter == SearchEntityType.sound;

    if (shouldReadProfiles) {
      try {
        final profiles =
            await _firestore.collection('publicProfiles').limit(60).get();

        for (final document in profiles.docs) {
          final data = document.data();
          if (!_isEligible(data)) continue;

          final displayName = data['displayName'] as String? ?? '';
          final ojasId = data['ojasId'] as String? ?? '';
          final bio = data['bio'] as String? ?? '';
          final text = displayName + ' ' + ojasId + ' ' + bio;

          if (_processorSimilarity(query, text) <= 0) continue;

          rows.add(
            SearchIndexRow(
              id: document.id,
              entityType: SearchEntityType.person,
              title: displayName.isEmpty ? '@' + ojasId : displayName,
              subtitle: ojasId.isEmpty ? '' : '@' + ojasId,
              text: text.trim(),
              imageUrl: data['photoUrl'] as String? ?? '',
              creatorId: document.id,
              followers: (data['followersCount'] as num?)?.toInt() ?? 0,
              posts: (data['postsCount'] as num?)?.toInt() ?? 0,
              createdAt: _readDateTime(data['updatedAt']) ??
                  _readDateTime(data['createdAt']),
            ),
          );
        }
      } catch (_) {}
    }

    final contentRows = <SearchIndexRow>[];

    if (shouldReadContent) {
      try {
        final reels = await _firestore
            .collection('reels')
            .orderBy('createdAt', descending: true)
            .limit(60)
            .get();

        for (final document in reels.docs) {
          final data = document.data();
          if (!_isEligible(data)) continue;

          final caption = data['caption'] as String? ?? '';
          final audio = data['audioTrackId'] as String? ?? '';
          final text = caption + ' ' + audio;

          final matchesQuery =
              _processorSimilarity(query, text) > 0 ||
              _extractHashtags(caption).any(
                (tag) => _processorSimilarity(query, tag) > 0,
              );
          if (!matchesQuery) continue;

          contentRows.add(
            SearchIndexRow(
              id: document.id,
              entityType: SearchEntityType.content,
              title: caption.trim().isEmpty ? 'OJAS Show' : caption.trim(),
              subtitle: data['creatorId'] as String? ?? '',
              text: text.trim(),
              imageUrl: data['thumbnailUrl'] as String? ?? '',
              creatorId: data['creatorId'] as String? ?? '',
              contentUrl: data['hlsUrl'] as String? ??
                  data['videoUrl'] as String? ??
                  '',
              audioTrackId: audio,
              tags: _extractHashtags(caption),
              createdAt: _readDateTime(data['createdAt']),
              views: (data['views'] as num?)?.toInt() ?? 0,
              likes: (data['likes'] as num?)?.toInt() ?? 0,
              saves: (data['saves'] as num?)?.toInt() ?? 0,
              algorithmScore:
                  (data['algorithmScore'] as num?)?.toDouble() ?? 0,
            ),
          );
        }
      } catch (_) {}
    }

    if (entityFilter == null || entityFilter == SearchEntityType.content) {
      rows.addAll(contentRows);
    } else if (entityFilter == SearchEntityType.hashtag ||
        entityFilter == SearchEntityType.sound) {
      rows.addAll(
        _deriveEntityRows(
          contentRows,
          query,
          entityFilter: entityFilter,
        ),
      );
    }

    return rows.take(limit).toList(growable: false);
  }

  bool _isEligible(Map<String, dynamic> data) {
    if (data['isDeleted'] == true) return false;
    if (data['isBanned'] == true) return false;
    if (data['searchEligible'] == false) return false;
    if (data['isPrivate'] == true) return false;

    final visibility = data['visibility'] as String?;
    if (visibility != null && visibility != 'public') return false;

    return true;
  }

  double _processorSimilarity(
    SearchQuery query,
    String candidate,
  ) {
    var best = SearchQueryProcessor.textSimilarity(
      query.normalized,
      candidate,
    );

    for (final alias in query.aliases) {
      final score = SearchQueryProcessor.textSimilarity(
        alias,
        candidate,
      );
      if (score > best) best = score;
    }
    return best;
  }

  static List<String> _extractHashtags(String caption) {
    final result = <String>[];
    for (final match
        in RegExp(r'#[A-Za-z0-9_\u0900-\u097F]+').allMatches(caption)) {
      result.add(match.group(0)!);
    }
    return result;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _suggestLabel(SearchIndexRow row) {
    switch (row.entityType) {
      case SearchEntityType.person:
        return row.title.isEmpty ? row.subtitle : row.title;
      case SearchEntityType.hashtag:
        return row.title.startsWith('#') ? row.title : '#' + row.title;
      case SearchEntityType.sound:
      case SearchEntityType.content:
      case SearchEntityType.topic:
      case SearchEntityType.place:
      case SearchEntityType.live:
      case SearchEntityType.generic:
        return row.title;
    }
  }
}
