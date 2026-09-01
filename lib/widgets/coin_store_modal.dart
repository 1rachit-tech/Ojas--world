import 'package:flutter/material.dart';

class CoinStoreModal extends StatelessWidget {
  final int currentBalance;
  final Function(int addedCoins) onPurchaseSuccess;

  const CoinStoreModal({
    super.key,
    required this.currentBalance,
    required this.onPurchaseSuccess,
  });

  static void show(
    BuildContext context, {
    required int currentBalance,
    required Function(int addedCoins) onPurchaseSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CoinStoreModal(
        currentBalance: currentBalance,
        onPurchaseSuccess: onPurchaseSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coinPackages = [
      {'coins': 100, 'price': '₹29', 'badge': ''},
      {'coins': 500, 'price': '₹129', 'badge': 'Popular'},
      {'coins': 1200, 'price': '₹299', 'badge': '+20% Extra'},
      {'coins': 3000, 'price': '₹699', 'badge': 'Best Value'},
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'OJAS Coin Vault',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$currentBalance Coins',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Recharge coins to send 3D gifts and support live creators.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Packages Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: coinPackages.length,
            itemBuilder: (context, idx) {
              final pkg = coinPackages[idx];
              final badge = pkg['badge'] as String;

              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  final added = pkg['coins'] as int;
                  onPurchaseSuccess(added);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Recharged $added OJAS Coins successfully! 🪙'),
                      backgroundColor: const Color(0xFF111827),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 20),
                              const SizedBox(width: 6),
                              Text(
                                '${pkg['coins']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            pkg['price'] as String,
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (badge.isNotEmpty)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
