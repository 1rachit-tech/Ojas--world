import 'package:cloud_firestore/cloud_firestore.dart';

class OjasProfile {
  const OjasProfile({
    required this.uid,
    required this.ojasId,
    required this.displayName,
    required this.photoUrl,
    required this.bio,
    required this.website,
    required this.isCreator,
    required this.creatorCategory,
    required this.isVerified,
    required this.followersCount,
    required this.followingCount,
    required this.likesCount,
    required this.postsCount,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String ojasId;
  final String displayName;
  final String photoUrl;
  final String bio;
  final String website;

  final bool isCreator;
  final String creatorCategory;
  final bool isVerified;

  final int followersCount;
  final int followingCount;
  final int likesCount;
  final int postsCount;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory OjasProfile.fromMap(
    Map<String, dynamic> data, {
    required String uid,
  }) {
    return OjasProfile(
      uid: uid,
      ojasId: _string(data['ojasId']),
      displayName: _string(
        data['displayName'],
        fallback: 'OJAS User',
      ),
      photoUrl: _string(
        data['photoUrl'],
        fallback: 'avatar_1',
      ),
      bio: _string(data['bio']),
      website: _string(data['website']),
      isCreator: data['isCreator'] == true,
      creatorCategory: _string(data['creatorCategory']),
      isVerified: data['isVerified'] == true,
      followersCount: _integer(data['followersCount']),
      followingCount: _integer(data['followingCount']),
      likesCount: _integer(data['likesCount']),
      postsCount: _integer(data['postsCount']),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  factory OjasProfile.empty({
    required String uid,
    String displayName = 'OJAS User',
    String photoUrl = 'avatar_1',
  }) {
    return OjasProfile(
      uid: uid,
      ojasId: '',
      displayName: displayName,
      photoUrl: photoUrl,
      bio: '',
      website: '',
      isCreator: false,
      creatorCategory: '',
      isVerified: false,
      followersCount: 0,
      followingCount: 0,
      likesCount: 0,
      postsCount: 0,
    );
  }

  OjasProfile copyWith({
    String? uid,
    String? ojasId,
    String? displayName,
    String? photoUrl,
    String? bio,
    String? website,
    bool? isCreator,
    String? creatorCategory,
    bool? isVerified,
    int? followersCount,
    int? followingCount,
    int? likesCount,
    int? postsCount,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return OjasProfile(
      uid: uid ?? this.uid,
      ojasId: ojasId ?? this.ojasId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      website: website ?? this.website,
      isCreator: isCreator ?? this.isCreator,
      creatorCategory:
          creatorCategory ?? this.creatorCategory,
      isVerified: isVerified ?? this.isVerified,
      followersCount:
          followersCount ?? this.followersCount,
      followingCount:
          followingCount ?? this.followingCount,
      likesCount: likesCount ?? this.likesCount,
      postsCount: postsCount ?? this.postsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toPublicMap() {
    return {
      'uid': uid,
      'ojasId': ojasId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'website': website,
      'isCreator': isCreator,
      'creatorCategory': creatorCategory,
      'isVerified': isVerified,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'likesCount': likesCount,
      'postsCount': postsCount,
    };
  }

  static String _string(
    dynamic value, {
    String fallback = '',
  }) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  static int _integer(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }
}
