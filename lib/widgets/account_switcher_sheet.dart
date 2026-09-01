import 'package:flutter/material.dart';

class AccountSwitcherSheet extends StatelessWidget {
  const AccountSwitcherSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AccountSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Switch Account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 16),
          
          // Current Account
          ListTile(
            leading: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF111827), width: 2),
              ),
              child: const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFF3F4F6),
                child: Text('R', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
            title: const Text('Rachit Kushwaha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: const Text('@rachit_k', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF111827)),
            onTap: () => Navigator.pop(context),
          ),
          
          // Add Account Option
          ListTile(
            leading: const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFF3F4F6),
              child: Icon(Icons.add_rounded, color: Color(0xFF111827)),
            ),
            title: const Text('Add account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login screen opening...')));
            },
          ),
          
          const Divider(color: Color(0xFFF3F4F6)),
          
          // Logout Option
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Log out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logging out...')));
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
