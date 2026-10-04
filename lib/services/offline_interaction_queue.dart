import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/social_interaction.dart';
import 'social_interaction_service.dart';

/// Queues social mutations while offline and flushes when network returns.
class OfflineInteractionQueue {
  OfflineInteractionQueue._();
  static final OfflineInteractionQueue instance = OfflineInteractionQueue._();

  static const _storageKey = 'ojas_offline_interaction_queue_v1';
  final List<Map<String, dynamic>> _queue = <Map<String, dynamic>>[];
  bool _loaded = false;
  bool _flushing = false;

  Future<void> initialize() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final item in list) {
            if (item is Map) {
              _queue.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Offline queue load failed: $e');
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_queue));
    } catch (_) {}
  }

  Future<void> enqueue({
    required String action,
    required Map<String, dynamic> payload,
    String? clientActionId,
  }) async {
    await initialize();
    final id = clientActionId ??
        SocialInteractionService.instance.newClientActionId();
    // Dedup by clientActionId
    _queue.removeWhere((e) => e['clientActionId'] == id);
    _queue.add({
      'clientActionId': id,
      'action': action,
      'payload': payload,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'retryCount': 0,
    });
    // Cap queue size for cost control
    while (_queue.length > 100) {
      _queue.removeAt(0);
    }
    await _persist();
  }

  int get pendingCount => _queue.length;

  Future<void> flush() async {
    await initialize();
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    final service = SocialInteractionService.instance;
    try {
      final copy = List<Map<String, dynamic>>.from(_queue);
      for (final item in copy) {
        final action = item['action'] as String? ?? '';
        final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
        final clientActionId = item['clientActionId'] as String?;
        try {
          switch (action) {
            case 'like':
              await service.setContentLike(
                contentId: payload['contentId'] as String? ?? '',
                liked: payload['liked'] == true,
                currentlySaved: payload['saved'] == true,
                clientActionId: clientActionId,
              );
              break;
            case 'save':
              await service.setContentSave(
                contentId: payload['contentId'] as String? ?? '',
                saved: payload['saved'] == true,
                currentlyLiked: payload['liked'] == true,
                clientActionId: clientActionId,
              );
              break;
            case 'follow':
              await service.setFollow(
                targetUserId: payload['targetUserId'] as String? ?? '',
                following: payload['following'] == true,
                clientActionId: clientActionId,
              );
              break;
            case 'comment':
              await service.postComment(
                contentId: payload['contentId'] as String? ?? '',
                text: payload['text'] as String? ?? '',
                parentCommentId: payload['parentCommentId'] as String?,
                clientActionId: clientActionId,
              );
              break;
            case 'share':
              await service.trackShare(ShareTrackEvent(
                contentId: payload['contentId'] as String? ?? '',
                channel: payload['channel'] as String? ?? 'unknown',
                intent: payload['intent'] as String? ?? 'opened',
                destination: payload['destination'] as String?,
                clientActionId: clientActionId,
              ));
              break;
            case 'comment_like':
              await service.setCommentLike(
                contentId: payload['contentId'] as String? ?? '',
                commentId: payload['commentId'] as String? ?? '',
                liked: payload['liked'] == true,
                clientActionId: clientActionId,
              );
              break;
            default:
              break;
          }
          _queue.removeWhere((e) => e['clientActionId'] == clientActionId);
        } catch (e) {
          final retries = (item['retryCount'] as int? ?? 0) + 1;
          if (retries >= 5) {
            _queue.removeWhere((e) => e['clientActionId'] == clientActionId);
          } else {
            final idx = _queue.indexWhere((e) => e['clientActionId'] == clientActionId);
            if (idx >= 0) {
              _queue[idx]['retryCount'] = retries;
            }
          }
          debugPrint('Offline flush item failed ($action): $e');
        }
      }
      await _persist();
    } finally {
      _flushing = false;
    }
  }
}
