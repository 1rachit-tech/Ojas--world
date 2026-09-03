import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SuperThanksModal extends StatelessWidget {
  final String creatorName;

  const SuperThanksModal({super.key, required this.creatorName});

  static void show(BuildContext context, {required String creatorName}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SuperThanksModal(creatorName: creatorName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amounts = ['₹20', '₹50', '₹100', '₹500'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF13171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 44),
          const SizedBox(height: 8),
          Text(
            'Support $creatorName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Send Super Thanks to appreciate their creative work!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: amounts.map((amt) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C222B),
                  foregroundColor: const Color(0xFFF59E0B),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sent $amt Super Thanks to $creatorName! ⭐'),
                      backgroundColor: const Color(0xFF1F2937),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(
                  amt,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
