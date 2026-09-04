import 'package:cloud_firestore/cloud_firestore.dart';

class UserInteractionModel {
  const UserInteractionModel({
    required this.userId,
    required this.reelId,
    required this.liked,
    required this.saved,
    required this.updatedAt,
  });

  final String userId;
  final String reelId;
  final bool liked;
  final bool saved;
  final DateTime updatedAt;

  factory UserInteractionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required String userId,
  }) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return UserInteractionModel(
      userId: userId,
      reelId: snapshot.id,
      liked: data['liked'] as bool? ?? false,
      saved: data['saved'] as bool? ?? false,
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  static DateTime _readDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'liked': liked,
        'saved': saved,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}
