import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reel_model.dart';
import 'azure_media_playback_service.dart';

class ReelFeedService {
  ReelFeedService({FirebaseFirestore? firestore, AzureMediaPlaybackService? playback})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _playback = playback ?? AzureMediaPlaybackService();

  static const int pageSize = 5;
  final FirebaseFirestore _firestore;
  final AzureMediaPlaybackService _playback;

  CollectionReference<Map<String, dynamic>> get _reels =>
      _firestore.collection('reels');

  Future<ReelFeedPage> fetchPage({DocumentSnapshot<Map<String, dynamic>>? cursor}) async {
    Query<Map<String, dynamic>> query = _reels
        .where('visibility', isEqualTo: 'public')
        .orderBy('algorithmScore', descending: true)
        .limit(pageSize);
    if (cursor != null) query = query.startAfterDocument(cursor);

    final snapshot = await query.get();
    final candidateReels = <ReelModel>[];
    final mediaProviderById = <String, String>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final moderationStatus = (data['moderationStatus'] as String? ?? '').toLowerCase();
      if (moderationStatus != 'approved') continue;
      if (data['deletedAt'] != null) continue;

      final mediaProvider = (data['mediaProvider'] as String? ?? '').toLowerCase();
      final processingStatus = (data['mediaProcessingStatus'] as String? ?? '').toLowerCase();
      if (mediaProvider == 'azure' && processingStatus != 'ready' && processingStatus != 'published') continue;

      final reel = ReelModel.fromFirestore(doc);
      if (reel.hlsUrl.trim().isEmpty) continue;
      candidateReels.add(reel);
      mediaProviderById[reel.id] = mediaProvider;
    }

    final azureIds = candidateReels
        .where((reel) => mediaProviderById[reel.id] == 'azure')
        .map((reel) => reel.id)
        .take(10)
        .toList(growable: false);
    final secureAssets = await _playback.resolvePlaybackAssets(azureIds);
    final resolved = <ReelModel>[];

    for (final reel in candidateReels) {
      if (mediaProviderById[reel.id] != 'azure') {
        resolved.add(reel);
        continue;
      }
      final asset = secureAssets[reel.id];
      if (asset == null || asset.playbackUrl.isEmpty) continue;
      resolved.add(reel.copyWith(
        hlsUrl: asset.playbackUrl,
        thumbnailUrl: asset.thumbnailUrl ?? reel.thumbnailUrl,
      ));
    }

    return ReelFeedPage(
      reels: List<ReelModel>.unmodifiable(resolved),
      cursor: snapshot.docs.isEmpty ? cursor : snapshot.docs.last,
      hasMore: snapshot.docs.length == pageSize,
    );
  }
}

class ReelFeedPage {
  const ReelFeedPage({required this.reels, required this.cursor, required this.hasMore});
  final List<ReelModel> reels;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}
