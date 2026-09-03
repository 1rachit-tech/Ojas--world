import 'package:cloud_firestore/cloud_firestore.dart';

class OjasPresence {
  const OjasPresence({
    required this.userId,
    required this.online,
    this.lastActiveAt,
  });

  final String userId;
  final bool online;
  final Timestamp? lastActiveAt;

  factory OjasPresence.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return OjasPresence(
      userId: document.id,
      online: data['online'] == true,
      lastActiveAt: data['lastActiveAt'] is Timestamp
          ? data['lastActiveAt'] as Timestamp
          : null,
    );
  }
}
