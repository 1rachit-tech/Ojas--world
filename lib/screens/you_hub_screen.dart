import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_room_screen.dart'; // नया चैट रूम पेज इम्पोर्ट किया गया है

class YouHubScreen extends StatefulWidget {
  final VoidCallback onLoggedOut;
  const YouHubScreen({super.key, required this.onLoggedOut});

  @override
  State<YouHubScreen> createState() => _YouHubScreenState();
}

class _YouHubScreenState extends State<YouHubScreen> {
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
            child: _buildDynamicUserAvatar(radius: 20),
          ),
          title: const TabBar(
            dividerColor: Colors.transparent,
            indicatorColor: Color(0xFFF5B942),
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Color(0xFF111827),
            unselectedLabelColor: Color(0xFF9CA3AF),
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'Arial',
            ),
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
        body: TabBarView(
          children: [
            _buildMessagesView(),
            _buildProfileView(),
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
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFF5B942),
            child: Text(
              'AK',
              style: TextStyle(color: const Color(0xFF111827), fontSize: radius * 0.8, fontWeight: FontWeight.bold),
            ),
          );
        }
        
        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFFF5B942),
            backgroundImage: NetworkImage(user.photoURL!),
          );
        }
        
        String initial = 'U';
        if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          initial = user.displayName!.trim()[0].toUpperCase();
        } else if (user.email != null && user.email!.trim().isNotEmpty) {
          initial = user.email!.trim()[0].toUpperCase();
        }
        
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFF5B942),
          child: Text(
            initial,
            style: TextStyle(color: const Color(0xFF111827), fontSize: radius * 0.8, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _buildMessagesView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Messages',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.black87),
              onPressed: () {},
            ),
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Active now',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
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
            Text(
              'Recent chats',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              '4',
              style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildChatItem('Maya Chen', 'Your latest edit is beautiful.', '9:42 AM', 3, const Color(0xFFF4C2C2), Icons.wb_twilight_rounded),
        _buildChatItem('Rohan Mehta', 'I sent over the new storyboard.', 'Yesterday', 0, const Color(0xFFC1D9D9), Icons.auto_awesome_rounded),
        _buildChatItem('Nia Kapoor', 'Voice note · 0:18', 'Tue', 1, const Color(0xFFF5B942), Icons.graphic_eq_rounded),
        _buildChatItem('Studio Circle', 'Arjun: Call time moved to 6 PM', 'Mon', 0, const Color(0xFFC5C6E9), Icons.people_alt_rounded),
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
              CircleAvatar(
                radius: 28,
                backgroundColor: color,
                child: Icon(icon, color: Colors.black87),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // इस फंक्शन में बदलाव किया गया है (InkWell और Navigator जोड़ा गया है)
  Widget _buildChatItem(String name, String msg, String time, int unread, Color color, IconData icon) {
    return InkWell(
      onTap: () {
        // चैट रूम पेज खोलें
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              userName: name,
              userColor: color,
              userIcon: icon,
            ),
          ),
        );
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: color,
          child: Icon(icon, color: Colors.black87),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          msg,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: TextStyle(
                color: unread > 0 ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                fontSize: 12,
                fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(height: 6),
              CircleAvatar(
                radius: 10,
                backgroundColor: const Color(0xFFF5B942),
                child: Text(
                  unread.toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDynamicUserAvatar(radius: 40),
          const SizedBox(height: 16),
          const Text('Profile View', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: widget.onLoggedOut,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5B942)),
            child: const Text('Logout', style: TextStyle(color: Colors.black)),
          )
        ],
      ),
    );
  }
}
