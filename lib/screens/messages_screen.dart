import 'package:flutter/material.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  static const _contacts = <_MessageContact>[
    _MessageContact(
      'Maya Chen',
      'Your latest edit is beautiful.',
      '9:42 AM',
      3,
      Color(0xFFE8B4B8),
      Icons.wb_twilight_rounded,
    ),
    _MessageContact(
      'Rohan Mehta',
      'I sent over the new storyboard.',
      'Yesterday',
      0,
      Color(0xFFB8D8D8),
      Icons.auto_awesome_rounded,
    ),
    _MessageContact(
      'Nia Kapoor',
      'Voice note · 0:18',
      'Tue',
      1,
      Color(0xFFF5B942),
      Icons.graphic_eq_rounded,
    ),
    _MessageContact(
      'Studio Circle',
      'Arjun: Call time moved to 6 PM',
      'Mon',
      0,
      Color(0xFFC7D2FE),
      Icons.groups_rounded,
      isGroup: true,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _contacts.where((contact) {
      return contact.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        Row(
          children: [
            const Text(
              'Messages',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {},
              tooltip: 'New message',
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search conversations',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Clear search',
                  ),
            filled: true,
            fillColor: const Color(0xFFF4F5F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Active now',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _contacts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 20),
            itemBuilder: (_, index) => _ActiveAvatar(contact: _contacts[index]),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Text(
              'Recent chats',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '${contacts.length}',
              style: const TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...contacts.map((contact) => _ConversationTile(contact: contact)),
      ],
    );
  }
}

class _ActiveAvatar extends StatelessWidget {
  const _ActiveAvatar({required this.contact});
  final _MessageContact contact;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 58,
    child: Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: contact.color,
              child: Icon(contact.icon, color: const Color(0xFF111827)),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: const Color(0xFF49B675),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          contact.name.split(' ').first,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.contact});
  final _MessageContact contact;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 7),
    leading: CircleAvatar(
      radius: 27,
      backgroundColor: contact.color,
      child: Icon(contact.icon, color: const Color(0xFF111827)),
    ),
    title: Row(
      children: [
        Expanded(
          child: Text(
            contact.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          contact.time,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      ],
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              contact.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          if (contact.unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: const BoxDecoration(
                color: Color(0xFFF5B942),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${contact.unread}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    ),
    onTap: () {},
  );
}

class _MessageContact {
  const _MessageContact(
    this.name,
    this.preview,
    this.time,
    this.unread,
    this.color,
    this.icon, {
    this.isGroup = false,
  });
  final String name;
  final String preview;
  final String time;
  final int unread;
  final Color color;
  final IconData icon;
  final bool isGroup;
}
