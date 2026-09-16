import 'package:cloud_firestore/cloud_firestore.dart';

class HomeStoryItem {
  const HomeStoryItem({
    required this.id,
    required this.creatorId,
    required this.mediaUrl,
    required this.createdAt,
    required this.expiresAt,
    this.thumbnailUrl,
    this.caption = '',
    this.viewed = false,
    this.mediaType = 'image',
  });

  final String id;
  final String creatorId;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool viewed;
  final String mediaType;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  factory HomeStoryItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return HomeStoryItem(
      id: snapshot.id,
      creatorId: data['creatorId'] as String? ?? '',
      mediaUrl: data['mediaUrl'] as String? ?? data['url'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String?,
      caption: data['caption'] as String? ?? '',
      createdAt: _date(data['createdAt']),
      expiresAt: _date(data['expiresAt']),
      viewed: data['viewed'] as bool? ?? false,
      mediaType: data['mediaType'] as String? ?? 'image',
    );
  }

  static DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}

class HomeStoryUser {
  const HomeStoryUser({
    required this.creatorId,
    required this.displayName,
    this.avatarUrl,
    required this.stories,
    this.hasUnread = true,
  });

  final String creatorId;
  final String displayName;
  final String? avatarUrl;
  final List<HomeStoryItem> stories;
  final bool hasUnread;
}
