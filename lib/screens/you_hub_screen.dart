import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_room_screen.dart';

class YouHubScreen extends StatefulWidget {
  final VoidCallback onLoggedOut;
  const YouHubScreen({super.key, required this.onLoggedOut});

  @override
  State<YouHubScreen> createState() => _YouHubScreenState();
}

class _YouHubScreenState extends State<YouHubScreen> {
  
  // ऐप बार की प्रोफाइल पिक्चर पर क्लिक करने पर खुलने वाला अकाउंट मेनू
  void _showAccountMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // हैंडल बार
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF111827)),
                title: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add new account feature coming soon!')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onLoggedOut(); // असली लॉगआउट कॉल
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 60,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
            child: GestureDetector(
              onTap: () => _showAccountMenu(context), // प्रोफाइल पिक्चर पर क्लिक
              child: _buildDynamicUserAvatar(radius: 20),
            ),
          ),
          title: const TabBar(
            dividerColor: Colors.transparent,
            indicatorColor: Color(0xFFF5B942),
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Color(0xFF111827),
            unselectedLabelColor: Color(0xFF9CA3AF),
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Arial'),
            tabs: [
              Tab(text: 'Messages'),
              Tab(text: 'Profile'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {},
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined, color: Color(0xFF111827)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: const TabBarView(
          children: [
            _MessagesView(), // Messages View को अलग क्लास में रखा ताकि कोड साफ रहे
            _UserProfileTab(), // नया शानदार प्रोफाइल व्यू
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicUserAvatar({required double radius}) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return CircleAvatar(radius: radius, backgroundColor: const Color(0xFFF5B942), child: Text('AK', style: TextStyle(color: const Color(0xFF111827), fontSize: radius * 0.8, fontWeight: FontWeight.bold)));
        }
        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          return CircleAvatar(radius: radius, backgroundColor: const Color(0xFFF5B942), backgroundImage: NetworkImage(user.photoURL!));
        }
        String initial = 'U';
        if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          initial = user.displayName!.trim()[0].toUpperCase();
        } else if (user.email != null && user.email!.trim().isNotEmpty) {
          initial = user.email!.trim()[0].toUpperCase();
        }
        return CircleAvatar(radius: radius, backgroundColor: const Color(0xFFF5B942), child: Text(initial, style: TextStyle(color: const Color(0xFF111827), fontSize: radius * 0.8, fontWeight: FontWeight.bold)));
      },
    );
  }
}

// ============================================================================
// Messages View (पुराना वाला)
// ============================================================================
class _MessagesView extends StatelessWidget {
  const _MessagesView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Messages', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.black87), onPressed: () {}),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            hintText: 'Search conversations',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Active now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildActiveAvatar('Maya', const Color(0xFFF4C2C2), Icons.wb_twilight_rounded),
              _buildActiveAvatar('Rohan', const Color(0xFFC1D9D9), Icons.auto_awesome_rounded),
              _buildActiveAvatar('Nia', const Color(0xFFF5B942), Icons.graphic_eq_rounded),
              _buildActiveAvatar('Studio', const Color(0xFFC5C6E9), Icons.people_alt_rounded),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Recent chats', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('4', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        _buildChatItem(context, 'Maya Chen', 'Your latest edit is beautiful.', '9:42 AM', 3, const Color(0xFFF4C2C2), Icons.wb_twilight_rounded),
        _buildChatItem(context, 'Rohan Mehta', 'I sent over the new storyboard.', 'Yesterday', 0, const Color(0xFFC1D9D9), Icons.auto_awesome_rounded),
        _buildChatItem(context, 'Nia Kapoor', 'Voice note · 0:18', 'Tue', 1, const Color(0xFFF5B942), Icons.graphic_eq_rounded),
        _buildChatItem(context, 'Studio Circle', 'Arjun: Call time moved to 6 PM', 'Mon', 0, const Color(0xFFC5C6E9), Icons.people_alt_rounded),
      ],
    );
  }

  Widget _buildActiveAvatar(String name, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(radius: 28, backgroundColor: color, child: Icon(icon, color: Colors.black87)),
              Positioned(
                right: 0, bottom: 0,
                child: Container(width: 14, height: 14, decoration: BoxDecoration(color: const Color(0xFF4ADE80), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildChatItem(BuildContext context, String name, String msg, String time, int unread, Color color, IconData icon) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatRoomScreen(userName: name, userColor: color, userIcon: icon)));
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: CircleAvatar(radius: 26, backgroundColor: color, child: Icon(icon, color: Colors.black87)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280))),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(time, style: TextStyle(color: unread > 0 ? const Color(0xFF111827) : const Color(0xFF9CA3AF), fontSize: 12, fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
            if (unread > 0) ...[
              const SizedBox(height: 6),
              CircleAvatar(radius: 10, backgroundColor: const Color(0xFFF5B942), child: Text(unread.toString(), style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold))),
            ]
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// नया कॉम्पैक्ट प्रोफाइल पेज (Instagram Style)
// ============================================================================
class _UserProfileTab extends StatefulWidget {
  const _UserProfileTab();

  @override
  State<_UserProfileTab> createState() => _UserProfileTabState();
}

class _UserProfileTabState extends State<_UserProfileTab> {
  String _displayName = "Rachit Kushwaha";
  String _username = "@akash_ojas";
  String _bio = "Digital Creator | Music & Tech 🚀\nWelcome to my creative space.";
  String _link = "youtube.com/ojas";
  int _selectedGridTab = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
        _displayName = user.displayName!;
      } else {
        _displayName = prefs.getString('profile_name') ?? "Rachit Kushwaha";
      }
      _username = prefs.getString('profile_username') ?? "@akash_ojas";
      _bio = prefs.getString('profile_bio') ?? "Digital Creator | Music & Tech 🚀\nWelcome to my creative space.";
      _link = prefs.getString('profile_link') ?? "youtube.com/ojas";
    });
  }

  Future<void> _saveProfileData(String name, String username, String bio, String link) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', name);
    await prefs.setString('profile_username', username);
    await prefs.setString('profile_bio', bio);
    await prefs.setString('profile_link', link);
    setState(() {
      _displayName = name;
      _username = username;
      _bio = bio;
      _link = link;
    });
  }

  void _showEditProfileModal() {
    final nameCtrl = TextEditingController(text: _displayName);
    final usernameCtrl = TextEditingController(text: _username);
    final bioCtrl = TextEditingController(text: _bio);
    final linkCtrl = TextEditingController(text: _link);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      _buildTextField('Name', nameCtrl),
                      const SizedBox(height: 16),
                      _buildTextField('Username', usernameCtrl),
                      const SizedBox(height: 16),
                      _buildTextField('Bio', bioCtrl, maxLines: 3),
                      const SizedBox(height: 16),
                      _buildTextField('Link', linkCtrl),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5B942),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      _saveProfileData(nameCtrl.text, usernameCtrl.text, bioCtrl.text, linkCtrl.text);
                      Navigator.pop(context);
                    },
                    child: const Text('Save Changes', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF5B942), width: 2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFFF5B942),
      onRefresh: () async {
        await _loadProfileData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // पूरा कंटेंट लेफ्ट अलाइन
          children: [
            const SizedBox(height: 16),
            
            // 1. Top Section: Avatar (Left) + Stats (Right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Profile Avatar
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Gallery...')));
                    },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _buildLargeAvatar(),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5B942),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                          child: const Icon(Icons.add, size: 16, color: Colors.black), // प्लस आइकॉन
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // Stats Area (Expanded to fill right side)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('145', 'Following'),
                        _buildStatColumn('12.4K', 'Followers'),
                        _buildStatColumn('2.1M', 'Likes'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 2. Name & Bio Section (Left Aligned)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text(_bio, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.3)),
                  const SizedBox(height: 4),
                  if (_link.isNotEmpty)
                    GestureDetector(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening $_link...'))),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, size: 16, color: Color(0xFF00376B)),
                          const SizedBox(width: 4),
                          Text(_link, style: const TextStyle(fontSize: 14, color: Color(0xFF00376B), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 3. Action Buttons (Edit Profile & Share)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildActionButton('Edit Profile', isPrimary: true, onTap: _showEditProfileModal)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildActionButton('Share Profile', isPrimary: true, onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile link copied!')));
                  })),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 4. Tabs
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
              child: Row(
                children: [
                  _buildGridTab(Icons.grid_view_rounded, 0),
                  _buildGridTab(Icons.favorite_border_rounded, 1),
                  _buildGridTab(Icons.lock_outline_rounded, 2),
                ],
              ),
            ),
            
            // 5. Posts Grid
            _buildPostsGrid(),
            
            // नीचे से लॉगआउट बटन हटा दिया गया है
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeAvatar() {
    return CircleAvatar(
      radius: 40,
      backgroundColor: const Color(0xFFF3F4F6),
      backgroundImage: const NetworkImage('https://via.placeholder.com/150'), // डमी इमेज
      child: _displayName.isNotEmpty ? null : Text('U', style: const TextStyle(color: Color(0xFF111827), fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
      ],
    );
  }

  Widget _buildActionButton(String text, {required bool isPrimary, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFF111827), fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildGridTab(IconData icon, int index) {
    final isSelected = _selectedGridTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGridTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isSelected ? const Color(0xFF111827) : Colors.transparent, width: 2)),
          ),
          child: Icon(icon, color: isSelected ? const Color(0xFF111827) : const Color(0xFF9CA3AF), size: 26),
        ),
      ),
    );
  }

  Widget _buildPostsGrid() {
    if (_selectedGridTab == 1 || _selectedGridTab == 2) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: Text("No posts here yet.", style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16))),
      );
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.8,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return Container(
          color: const Color(0xFFE5E7EB),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Icon(Icons.image_rounded, color: Colors.grey.withValues(alpha: 0.3), size: 40),
              Positioned(
                bottom: 8, left: 8,
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text('${(index + 1) * 12}K', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
