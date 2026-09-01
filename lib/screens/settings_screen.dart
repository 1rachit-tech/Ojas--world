import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'creator_wallet_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isPrivateAccount = false;

  void _showAnalyticsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Profile Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Last 30 Days Overview',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildAnalyticsCard('Total Views', '48.2K', '+14.8%', const Color(0xFF10B981)),
                const SizedBox(width: 12),
                _buildAnalyticsCard('Engagement', '8.4K', '+22.4%', const Color(0xFF10B981)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildAnalyticsCard('Profile Visits', '1.2K', '+5.1%', const Color(0xFF10B981)),
                const SizedBox(width: 12),
                _buildAnalyticsCard('Shares', '640', '+34.0%', const Color(0xFF10B981)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(String label, String value, String growth, Color growthColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(growth, style: TextStyle(color: growthColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Privacy Settings', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF111827),
                title: const Text('Private Account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                subtitle: const Text('Only approved followers can view your media', style: TextStyle(fontSize: 12)),
                value: _isPrivateAccount,
                onChanged: (val) {
                  setDialogState(() => _isPrivateAccount = val);
                  setState(() => _isPrivateAccount = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out of OJAS?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        content: const Text('You will need to sign in again to access your account.', style: TextStyle(color: Color(0xFF4B5563))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings and privacy',
          style: TextStyle(color: Color(0xFF111827), fontSize: 17, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          _buildSectionHeader('Creator Tools'),
          _buildSettingsTile(
            Icons.bar_chart_rounded,
            'Analytics',
            'View your profile performance',
            onTap: () => _showAnalyticsSheet(context),
          ),
          _buildSettingsTile(
            Icons.monetization_on_rounded,
            'Monetization & Wallet',
            'Creator rewards, Super Thanks earnings & payout',
            onTap: () => CreatorWalletScreen.open(context),
          ),
          _buildSettingsTile(
            Icons.campaign_rounded,
            'Ad Center',
            'Manage your promotions',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ad Center is ready for creator campaigns.'), behavior: SnackBarBehavior.floating),
              );
            },
          ),
          
          _buildSectionHeader('Account'),
          _buildSettingsTile(
            Icons.person_outline_rounded,
            'Account management',
            'Password, email, delete account',
            onTap: () {},
          ),
          _buildSettingsTile(
            Icons.lock_outline_rounded,
            'Privacy',
            _isPrivateAccount ? 'Private account (Active)' : 'Public account',
            onTap: () => _showPrivacyDialog(context),
          ),
          _buildSettingsTile(
            Icons.security_rounded,
            'Security & login',
            '2-step verification',
            onTap: () {},
          ),
          
          _buildSectionHeader('Content & Display'),
          _buildSettingsTile(
            Icons.dark_mode_outlined,
            'Display',
            'Theme and appearance preferences',
            onTap: () {},
          ),
          _buildSettingsTile(
            Icons.language_rounded,
            'Language',
            'English (India)',
            onTap: () {},
          ),
          
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF3F4F6), thickness: 8),
          
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 24),
            title: const Text('Log out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 15)),
            onTap: () => _handleLogout(context),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: const Color(0xFF111827), size: 24),
      title: Text(title, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600, fontSize: 14.5)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF9CA3AF), size: 14),
      onTap: onTap,
    );
  }
}
