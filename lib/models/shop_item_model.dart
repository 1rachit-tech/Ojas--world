import 'package:cloud_firestore/cloud_firestore.dart';

class ShopItemModel {
  const ShopItemModel({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.productUrl,
    required this.priceMinor,
    required this.currency,
    required this.commissionBps,
    required this.active,
    required this.createdAt,
  }) : assert(commissionBps >= 800 && commissionBps <= 3000);

  final String id;
  final String creatorId;
  final String title;
  final String description;
  final String imageUrl;
  final String productUrl;
  final int priceMinor;
  final String currency;
  final int commissionBps;
  final bool active;
  final DateTime createdAt;

  factory ShopItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return ShopItemModel(
      id: snapshot.id,
      creatorId: data['creatorId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      productUrl: data['productUrl'] as String? ?? '',
      priceMinor: (data['priceMinor'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'INR',
      commissionBps: (data['commissionBps'] as num?)?.toInt() ?? 800,
      active: data['active'] as bool? ?? true,
      createdAt: _readDateTime(data['createdAt']),
    );
  }

  static DateTime _readDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'creatorId': creatorId,
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'productUrl': productUrl,
        'priceMinor': priceMinor,
        'currency': currency,
        'commissionBps': commissionBps,
        'active': active,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
