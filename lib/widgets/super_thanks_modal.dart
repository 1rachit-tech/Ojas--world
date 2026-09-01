import 'package:flutter/material.dart';

class SuperThanksModal extends StatelessWidget {
  final String creatorName;

  const SuperThanksModal({super.key, required this.creatorName});

  static void show(BuildContext context, {required String creatorName}) {
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
        color: Colors.white,
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
                color: Colors.grey.shade300,
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
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Send Super Thanks to appreciate their creative work!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: amounts.map((amt) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9FAFB),
                  foregroundColor: const Color(0xFF111827),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sent $amt Super Thanks to $creatorName! ⭐'),
                      backgroundColor: const Color(0xFF111827),
                      behavior: SnackBarBehavior.floating,
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
