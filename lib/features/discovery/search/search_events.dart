import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SearchEventType {
  searchOpen,
  searchFocus,
  searchQuery,
  searchSubmit,
  searchCancel,
  searchZeroResult,
  searchRefine,
  searchAbandon,
  suggestionImpression,
  suggestionClick,
  resultImpression,
  resultClick,
  profileOpenFromSearch,
  contentOpenFromSearch,
  hashtagOpenFromSearch,
  soundOpenFromSearch,
  topicOpenFromSearch,
  placeOpenFromSearch,
  postClickWatch,
  postClickLike,
  postClickFollow,
  postClickSave,
  notInterested,
  hide,
  mute,
  block,
  report,
}

class SearchEvent {
  const SearchEvent({
    required this.sessionId,
    required this.eventType,
    required this.createdAt,
    this.query = '',
    this.resultId = '',
    this.resultType = '',
    this.position = 0,
    this.metadata = const <String, Object?>{},
  });

  final String sessionId;
  final SearchEventType eventType;
  final DateTime createdAt;
  final String query;
  final String resultId;
  final String resultType;
  final int position;
  final Map<String, Object?> metadata;

  Map<String, dynamic> toLocalMap() => <String, dynamic>{
    'sessionId': sessionId,
    'eventType': eventType.name,
    'createdAt': createdAt.toIso8601String(),
    'query': query,
    'resultId': resultId,
    'resultType': resultType,
    'position': position,
    'metadata': metadata,
  };
}

class SearchEventQueue {
  SearchEventQueue({
    this.maxStoredEvents = 300,
    this.remoteUploadEnabled = false,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final int maxStoredEvents;
  final bool remoteUploadEnabled;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final List<SearchEvent> _pending = <SearchEvent>[];
  String? _uid;
  String? _uid;

  String _key() =>
      'ojas_search_events_v2_' + ((_uid == null || _uid!.isEmpty) ? 'signed_out' : _uid!);

  Future<void> initialize({String? uid}) async {
    _uid = uid;
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key());
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      _pending.clear();
      for (final item in decoded) {
        if (item is! Map) continue;
        final typeName = item['eventType'] as String?;
        SearchEventType? type;
        for (final candidate in SearchEventType.values) {
          if (candidate.name == typeName) {
            type = candidate;
            break;
          }
        }
        final createdAt =
            DateTime.tryParse(item['createdAt'] as String? ?? '');
        if (type == null || createdAt == null) continue;

        _pending.add(
          SearchEvent(
            sessionId: item['sessionId'] as String? ?? '',
            eventType: type,
            createdAt: createdAt,
            query: item['query'] as String? ?? '',
            resultId: item['resultId'] as String? ?? '',
            resultType: item['resultType'] as String? ?? '',
            position: (item['position'] as num?)?.toInt() ?? 0,
            metadata: item['metadata'] is Map
                ? Map<String, Object?>.from(item['metadata'] as Map)
                : const <String, Object?>{},
          ),
        );
      }

      if (_pending.length > maxStoredEvents) {
        _pending.removeRange(0, _pending.length - maxStoredEvents);
      }
    } catch (_) {
      _pending.clear();
    }
  }

  void enqueue(SearchEvent event) {
    _pending.add(event);
    if (_pending.length > maxStoredEvents) {
      _pending.removeRange(0, _pending.length - maxStoredEvents);
    }
    unawaited(_persist());
  }

  List<SearchEvent> get pendingEvents =>
      List<SearchEvent>.unmodifiable(_pending);

  Future<void> _persist() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final payload = _pending.map((event) => event.toLocalMap()).toList();
      await preferences.setString(_key(), jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> clear() async {
    _pending.clear();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_key());
    } catch (_) {}
  }
}
