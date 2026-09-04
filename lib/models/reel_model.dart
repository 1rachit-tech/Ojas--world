import 'package:cloud_firestore/cloud_firestore.dart';

class ReelModel {
  const ReelModel({
    required this.id,
    required this.creatorId,
    required this.caption,
    required this.thumbnailUrl,
    required this.hlsUrl,
    required this.mediaHash,
    required this.views,
    required this.watchTimeMs,
    required this.completions,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    required this.shopItemIds,
    required this.algorithmScore,
    required this.createdAt,
    this.audioTrackId = '',
  });

  final String id;
  final String creatorId;
  final String caption;
  final String thumbnailUrl;
  final String hlsUrl;
  final String mediaHash;
  final int views;
  final int watchTimeMs;
  final int completions;
  final int likes;
  final int comments;
  final int saves;
  final int shares;
  final List<String> shopItemIds;
  final double algorithmScore;
  final DateTime createdAt;
  final String audioTrackId;

  factory ReelModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return ReelModel(
      id: snapshot.id,
      creatorId: data['creatorId'] as String? ?? '',
      caption: data['caption'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      hlsUrl: data['hlsUrl'] as String? ?? '',
      mediaHash: data['mediaHash'] as String? ?? '',
      views: (data['views'] as num?)?.toInt() ?? 0,
      watchTimeMs: (data['watchTimeMs'] as num?)?.toInt() ?? 0,
      completions: (data['completions'] as num?)?.toInt() ?? 0,
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      comments: (data['comments'] as num?)?.toInt() ?? 0,
      saves: (data['saves'] as num?)?.toInt() ?? 0,
      shares: (data['shares'] as num?)?.toInt() ?? 0,
      shopItemIds: List<String>.from(
        data['shopItemIds'] as List? ?? const <String>[],
      ),
      algorithmScore: (data['algorithmScore'] as num?)?.toDouble() ?? 0.0,
      createdAt: _readDateTime(data['createdAt']),
      audioTrackId: data['audioTrackId'] as String? ?? '',
    );
  }

  static DateTime _readDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'creatorId': creatorId,
    'caption': caption,
    'thumbnailUrl': thumbnailUrl,
    'hlsUrl': hlsUrl,
    'mediaHash': mediaHash,
    'views': views,
    'watchTimeMs': watchTimeMs,
    'completions': completions,
    'likes': likes,
    'comments': comments,
    'saves': saves,
    'shares': shares,
    'shopItemIds': shopItemIds,
    'algorithmScore': algorithmScore,
    'createdAt': Timestamp.fromDate(createdAt),
    'audioTrackId': audioTrackId,
  };
}
