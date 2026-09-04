import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/shop_item_model.dart';

class ReelShopProductsBottomSheet extends StatefulWidget {
  const ReelShopProductsBottomSheet({super.key, required this.shopItemIds});

  final List<String> shopItemIds;

  static Future<void> show(
    BuildContext context, {
    required List<String> shopItemIds,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReelShopProductsBottomSheet(shopItemIds: shopItemIds),
    );
  }

  @override
  State<ReelShopProductsBottomSheet> createState() =>
      _ReelShopProductsBottomSheetState();
}

class _ReelShopProductsBottomSheetState
    extends State<ReelShopProductsBottomSheet> {
  List<ShopItemModel> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final ids = widget.shopItemIds
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final items = <ShopItemModel>[];
    final collection = FirebaseFirestore.instance.collection('shopItems');
    for (var start = 0; start < ids.length; start += 30) {
      final chunk = ids.skip(start).take(30).toList(growable: false);
      final snapshot = await collection
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      items.addAll(
        snapshot.docs
            .map(ShopItemModel.fromFirestore)
            .where((item) => item.active),
      );
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openProduct(ShopItemModel item) async {
    final uri = Uri.tryParse(item.productUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _price(ShopItemModel item) =>
      '${item.currency} ${(item.priceMinor / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: Color(0xFF13171D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.shopping_bag_rounded,
                    color: Color(0xFFF5B942),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Shop Products',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFF5B942),
                      ),
                    )
                  : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'Products unavailable',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2028),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: item.imageUrl.isEmpty
                                      ? const ColoredBox(
                                          color: Color(0xFF222831),
                                          child: Icon(
                                            Icons.image_outlined,
                                            color: Colors.white30,
                                          ),
                                        )
                                      : Image.network(
                                          item.imageUrl,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _price(item),
                                      style: const TextStyle(
                                        color: Color(0xFFF5B942),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: () => _openProduct(item),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFF5B942),
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(
                                  Icons.arrow_outward_rounded,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
