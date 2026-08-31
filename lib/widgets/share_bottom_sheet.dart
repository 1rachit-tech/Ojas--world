import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareFriendItem {
  final String id;
  final String name;
  final String username;
  final Color avatarColor;
  final bool isOnline;

  ShareFriendItem({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarColor,
    this.isOnline = false,
  });
}

class ShareBottomSheet extends StatefulWidget {
  final String videoUrl;
  final String creatorName;

  const ShareBottomSheet({
    super.key,
    required this.videoUrl,
    required this.creatorName,
  });

  static void show(BuildContext context, {required String videoUrl, required String creatorName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareBottomSheet(
        videoUrl: videoUrl,
        creatorName: creatorName,
      ),
    );
  }

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedFriends = <String>{};
  bool _linkCopied = false;

  final List<ShareFriendItem> _allFriends = [
    ShareFriendItem(id: '1', name: 'Ayush', username: 'ayush_01', avatarColor: const Color(0xFFF4C2C2), isOnline: true),
    ShareFriendItem(id: '2', name: 'Sachit', username: 'sachit_k', avatarColor: const Color(0xFFC1D9D9), isOnline: true),
    ShareFriendItem(id: '3', name: 'Rachit Ram', username: 'rachit_ram', avatarColor: const Color(0xFFF5B942)),
    ShareFriendItem(id: '4', name: 'Golu', username: 'mr_golu_42', avatarColor: const Color(0xFFC5C6E9)),
    ShareFriendItem(id: '5', name: 'Nikhil', username: 'nikhil_art', avatarColor: const Color(0xFFFFD36B), isOnline: true),
    ShareFriendItem(id: '6', name: 'Vaibhav', username: 'vaibhav_v', avatarColor: const Color(0xFFA7F3D0)),
  ];

  List<ShareFriendItem> _filteredFriends = [];

  @override
  void initState() {
    super.initState();
    _filteredFriends = _allFriends;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _allFriends;
      } else {
        _filteredFriends = _allFriends.where((f) {
          return f.name.toLowerCase().contains(query) || f.username.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _copyVideoLink() {
    Clipboard.setData(ClipboardData(text: widget.videoUrl));
    setState(() {
      _linkCopied = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video link copied to clipboard! 🔗'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _linkCopied = false);
    });
  }

  Future<void> _openSystemShare() async {
    Navigator.pop(context);
    final textToShare = 'Check out this video by ${widget.creatorName} on OJAS: ${widget.videoUrl}';
    await Share.share(
      textToShare,
      subject: 'Watch video on OJAS',
    );
  }

  void _sendDirectMessage() {
    if (_selectedFriends.isEmpty) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sent to ${_selectedFriends.length} friend(s) on OJAS! ✈️'),
        backgroundColor: const Color(0xFFF5B942),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.68,
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Search Box & Create Group
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Search friends on OJAS...',
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.group_add_outlined, color: Colors.white70, size: 20),
                    tooltip: 'Create Group',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Create Group feature coming soon!')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Friends Grid
          Expanded(
            child: _filteredFriends.isEmpty
                ? const Center(
                    child: Text('No friends found', style: TextStyle(color: Colors.white38)),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.88,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _filteredFriends.length,
                    itemBuilder: (context, index) {
                      final friend = _filteredFriends[index];
                      final isSelected = _selectedFriends.contains(friend.id);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedFriends.remove(friend.id);
                            } else {
                              _selectedFriends.add(friend.id);
                            }
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: friend.avatarColor,
                                  child: Text(
                                    friend.name.isNotEmpty ? friend.name[0] : 'U',
                                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF5B942),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded, size: 14, color: Colors.black),
                                  )
                                else if (friend.isOnline)
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4ADE80),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF161B22), width: 2.5),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              friend.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFFF5B942) : Colors.white,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            Text(
                              '@${friend.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Send to Friends Button
          if (_selectedFriends.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5B942),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _sendDirectMessage,
                  child: Text(
                    'Send to ${_selectedFriends.length} friend${_selectedFriends.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),

          const Divider(height: 1, color: Colors.white10),

          // Action Bar (Copy link, Share to all apps, Story, Download)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            height: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  label: _linkCopied ? 'Copied!' : 'Copy Link',
                  icon: _linkCopied ? Icons.check_rounded : Icons.link_rounded,
                  iconColor: _linkCopied ? const Color(0xFF4ADE80) : Colors.white,
                  onTap: _copyVideoLink,
                ),
                _buildActionButton(
                  label: 'Share to...',
                  icon: Icons.share_rounded,
                  onTap: _openSystemShare,
                ),
                _buildActionButton(
                  label: 'Add to Story',
                  icon: Icons.add_circle_outline_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Adding to OJAS Story...')),
                    );
                  },
                ),
                _buildActionButton(
                  label: 'Download',
                  icon: Icons.download_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Downloading video to gallery...')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF21262D),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

