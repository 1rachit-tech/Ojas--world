import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reel_model.dart';
import 'azure_media_playback_service.dart';

class ReelFeedService {
  ReelFeedService({
    FirebaseFirestore? firestore,
    AzureMediaPlaybackService? playback,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _playback = playback ?? AzureMediaPlaybackService();

  static const int pageSize = 5;

  final FirebaseFirestore _firestore;
  final AzureMediaPlaybackService _playback;

  CollectionReference<Map<String, dynamic>> get _reels =>
      _firestore.collection('reels');

  Future<ReelFeedPage> fetchPage({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    Query<Map<String, dynamic>> query = _reels
        .orderBy('algorithmScore', descending: true)
        .limit(pageSize);

    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;

    final candidateReels = <ReelModel>[];
    for (final doc in docs) {
      final data = doc.data();
      final visibility = (data['visibility'] as String? ?? 'public').toLowerCase();
      if (visibility != 'public') continue;

      final mediaProvider = (data['mediaProvider'] as String? ?? '').toLowerCase();
      final processingStatus =
          (data['mediaProcessingStatus'] as String? ?? '').toLowerCase();
      if (mediaProvider == 'azure' &&
          processingStatus != 'ready' &&
          processingStatus != 'published') {
        continue;
      }

      final reel = ReelModel.fromFirestore(doc);
      if (reel.hlsUrl.trim().isEmpty) continue;
      candidateReels.add(reel);
    }

    final azureIds = candidateReels
        .where((reel) => reel.mediaProvider.toLowerCase() == 'azure')
        .map((reel) => reel.id)
        .take(10)
        .toList(growable: false);
    final signedUrls = await _playback.resolvePlaybackUrls(azureIds);

    final resolved = <ReelModel>[];
    for (final reel in candidateReels) {
      if (reel.mediaProvider.toLowerCase() != 'azure') {
        resolved.add(reel);
        continue;
      }

      final signedUrl = signedUrls[reel.id];
      if (signedUrl == null || signedUrl.isEmpty) {
        // Never expose a private Azure source URL directly to the player.
        continue;
      }
      resolved.add(reel.copyWith(hlsUrl: signedUrl));
    }

    return ReelFeedPage(
      reels: List<ReelModel>.unmodifiable(resolved),
      cursor: docs.isEmpty ? cursor : docs.last,
      hasMore: docs.length == pageSize,
    );
  }
}

class ReelFeedPage {
  const ReelFeedPage({
    required this.reels,
    required this.cursor,
    required this.hasMore,
  });

  final List<ReelModel> reels;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}
