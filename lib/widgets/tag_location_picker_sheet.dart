import 'package:flutter/material.dart';

class TagLocationPickerSheet extends StatefulWidget {
  final bool isLocationMode; // true = location, false = tag people
  final Function(String result) onSelected;

  const TagLocationPickerSheet({
    super.key,
    required this.isLocationMode,
    required this.onSelected,
  });

  static void show(
    BuildContext context, {
    required bool isLocationMode,
    required Function(String result) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagLocationPickerSheet(
        isLocationMode: isLocationMode,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<TagLocationPickerSheet> createState() => _TagLocationPickerSheetState();
}

class _TagLocationPickerSheetState extends State<TagLocationPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _locations = ['Satna, Madhya Pradesh', 'Rewa, Madhya Pradesh', 'Nemua, Satna', 'Bhopal, MP', 'Indore, MP', 'Mumbai, Maharashtra', 'Delhi, India'];
  final List<String> _creators = ['@mayamakes (Maya Chen)', '@rohanbuilds (Rohan Mehta)', '@sneha_09 (Sneha)', '@nikhil_art (Nikhil)', '@ayush_01 (Ayush)'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoc = widget.isLocationMode;
    final list = isLoc ? _locations : _creators;
    final query = _searchCtrl.text.toLowerCase().trim();
    final filtered = list.where((item) => item.toLowerCase().contains(query)).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          Text(
            isLoc ? 'Add Location' : 'Tag Creators / Collaborators',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),

          // Search Box
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: const Color(0xFF21262D), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(isLoc ? Icons.location_on_rounded : Icons.person_search_rounded, color: Colors.white54, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: isLoc ? 'Search city or landmark...' : 'Search creator username...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final val = filtered[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(isLoc ? Icons.place_rounded : Icons.account_circle_rounded, color: const Color(0xFFF5B942)),
                  title: Text(val, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () {
                    widget.onSelected(val);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
