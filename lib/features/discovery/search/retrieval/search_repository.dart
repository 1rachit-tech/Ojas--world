import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/search_models.dart';
import '../query_processor.dart';

class SearchRepository {
  SearchRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SearchQueryProcessor _processor = const SearchQueryProcessor();

  Future<List<SearchIndexRow>> retrieve(
    SearchQuery query, {
    SearchEntityType? entityFilter,
    int limit = 100,
  }) async {
    if (query.normalized.isEmpty) return const <SearchIndexRow>[];

    final rows = <SearchIndexRow>[];
    final seen = <String>{};

    try {
      final prefixes = query.prefixes;
      if (prefixes.isNotEmpty) {
        final indexSnapshot = await _firestore
            .collection('searchIndex')
            .where('prefixes', arrayContainsAny: prefixes)
            .limit(limit)
            .get();

        for (final document in indexSnapshot.docs) {
          final row = SearchIndexRow.fromFirestore(document);
          if (!row.eligible) continue;
          if (entityFilter != null && row.entityType != entityFilter) continue;
          if (seen.add(row.entityType.name + ':' + row.id)) {
            rows.add(row);
          }
        }
      }
    } on FirebaseException {
      // The index is an optimization. Legacy retrieval keeps Search usable
      // while the index is warming or temporarily unavailable.
    } catch (_) {}

    if (rows.length < 12) {
      final legacy = await _legacyRetrieve(
        query,
        entityFilter: entityFilter,
        limit: limit - rows.length,
      );
      for (final row in legacy) {
        if (seen.add(row.entityType.name + ':' + row.id)) {
          rows.add(row);
        }
      }
    }

    return rows.take(limit).toList(growable: false);
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
          final text = row.title.trim();
          if (text.isEmpty) continue;

          final key = row.entityType.name + ':' + text.toLowerCase();
          if (!seen.add(key)) continue;

          suggestions.add(
            SearchSuggestion(
              text: _suggestLabel(row),
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

    if (suggestions.length >= limit) return suggestions;

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

    return suggestions;
  }

  Future<List<SearchIndexRow>> _legacyRetrieve(
    SearchQuery query, {
    SearchEntityType? entityFilter,
    required int limit,
  }) async {
    if (limit <= 0) return const <SearchIndexRow>[];

    final rows = <SearchIndexRow>[];

    if (entityFilter == null || entityFilter == SearchEntityType.person) {
      try {
        final profiles = await _firestore.collection('publicProfiles').limit(60).get();
        for (final document in profiles.docs) {
          final data = document.data();
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

    if (entityFilter == null || entityFilter == SearchEntityType.content) {
      try {
        final reels = await _firestore
            .collection('reels')
            .orderBy('createdAt', descending: true)
            .limit(60)
            .get();

        for (final document in reels.docs) {
          final data = document.data();
          final caption = data['caption'] as String? ?? '';
          final audio = data['audioTrackId'] as String? ?? '';
          final text = caption + ' ' + audio;

          if (_processorSimilarity(query, text) <= 0) continue;

          rows.add(
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

    if (entityFilter == null || entityFilter == SearchEntityType.hashtag) {
      final hashtags = <String>{};
      for (final row in rows) {
        hashtags.addAll(row.tags.map((tag) => tag.toLowerCase()));
      }
      for (final hashtag in hashtags) {
        if (SearchQueryProcessor.textSimilarity(
              query.normalized,
              hashtag,
            ) <=
            0) {
          continue;
        }
        rows.add(
          SearchIndexRow(
            id: hashtag,
            entityType: SearchEntityType.hashtag,
            title: hashtag.startsWith('#') ? hashtag : '#' + hashtag,
            subtitle: 'OJAS hashtag',
            text: hashtag,
            tags: <String>[hashtag],
          ),
        );
      }
    }

    return rows.take(limit).toList(growable: false);
  }

  double _processorSimilarity(SearchQuery query, String candidate) {
    var best = SearchQueryProcessor.textSimilarity(
      query.normalized,
      candidate,
    );

    for (final alias in query.aliases) {
      final score = SearchQueryProcessor.textSimilarity(alias, candidate);
      if (score > best) best = score;
    }
    return best;
  }

  static List<String> _extractHashtags(String caption) {
    final result = <String>[];
    for (final match in RegExp(r'#[A-Za-z0-9_\u0900-\u097F]+').allMatches(caption)) {
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
