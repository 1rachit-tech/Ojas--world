import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class OjasShopSheet {
  static void show(BuildContext context, {required List<Map<String, dynamic>> products}) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ShopSheetContent(products: products),
    );
  }
}

class _ShopSheetContent extends StatelessWidget {
  final List<Map<String, dynamic>> products;

  const _ShopSheetContent({required this.products});

  Future<void> _launchAffiliateUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.shopping_bag_rounded, color: Color(0xFF111827), size: 24),
                SizedBox(width: 10),
                Text(
                  'Products in this video',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFF3F4F6), height: 1),
          
          // Products List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final product = products[index];
                return _buildProductCard(product);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Product Image Placeholder
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(
              child: Icon(Icons.image_outlined, color: Color(0xFF9CA3AF), size: 28),
            ),
          ),
          const SizedBox(width: 16),
          
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] as String,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${product['price']}',
                  style: const TextStyle(
                    color: Color(0xFF059669), // Success Green
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Buy Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              _launchAffiliateUrl(product['url'] as String);
            },
            child: const Text(
              'Buy',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
