import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          _buildSettingsTile(Icons.bar_chart_rounded, 'Analytics', 'View your profile performance'),
          _buildSettingsTile(Icons.monetization_on_rounded, 'Monetization', 'Creator fund, Super Thanks & gifts'),
          _buildSettingsTile(Icons.campaign_rounded, 'Ad Center', 'Manage your promotions'),
          
          _buildSectionHeader('Account'),
          _buildSettingsTile(Icons.person_outline_rounded, 'Account management', 'Password, email, delete account'),
          _buildSettingsTile(Icons.lock_outline_rounded, 'Privacy', 'Private account, interaction limits'),
          _buildSettingsTile(Icons.security_rounded, 'Security & login', '2-step verification'),
          
          _buildSectionHeader('Content & Display'),
          _buildSettingsTile(Icons.dark_mode_outlined, 'Display', 'Dark mode & appearance'),
          _buildSettingsTile(Icons.language_rounded, 'Language', 'English (India)'),
          
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF3F4F6), thickness: 8),
          
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: const Text('Log out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logging out...')));
            },
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

  Widget _buildSettingsTile(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: const Color(0xFF111827), size: 26),
      title: Text(title, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF9CA3AF), size: 16),
      onTap: () {},
    );
  }
}
