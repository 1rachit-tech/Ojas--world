import 'package:flutter/material.dart';

class WorldRadarHubSheet extends StatefulWidget {
  final String activeRegion;
  final Function(String region) onRegionChanged;

  const WorldRadarHubSheet({super.key, required this.activeRegion, required this.onRegionChanged});

  static void show(BuildContext context, {required String activeRegion, required Function(String region) onRegionChanged}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => WorldRadarHubSheet(activeRegion: activeRegion, onRegionChanged: onRegionChanged),
    );
  }

  @override
  State<WorldRadarHubSheet> createState() => _WorldRadarHubSheetState();
}

class _WorldRadarHubSheetState extends State<WorldRadarHubSheet> {
  final List<Map<String, dynamic>> _regions = [
    {'name': 'Global (All World)', 'desc': 'Top viral trends worldwide', 'icon': Icons.public_rounded, 'badge': 'Global'},
    {'name': 'Vindhya & Rewa Region', 'desc': 'Satna, Rewa, Maihar, Sidhi local creators', 'icon': Icons.location_city_rounded, 'badge': 'Local'},
    {'name': 'Madhya Pradesh Central', 'desc': 'Bhopal, Indore, Jabalpur trending clips', 'icon': Icons.map_rounded, 'badge': 'State'},
    {'name': 'India National Spotlight', 'desc': 'All India folk music, cinema & comedy', 'icon': Icons.flag_rounded, 'badge': 'National'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF13171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('World Radar Location', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF5B942).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Text('OJAS RADAR', style: TextStyle(color: Color(0xFFF5B942), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._regions.map((r) {
            final isSelected = widget.activeRegion == r['name'];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF5B942).withValues(alpha: 0.12) : const Color(0xFF1A1F26),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? const Color(0xFFF5B942) : Colors.transparent),
              ),
              child: ListTile(
                leading: Icon(r['icon'] as IconData, color: isSelected ? const Color(0xFFF5B942) : Colors.white70),
                title: Text(r['name'] as String, style: TextStyle(color: isSelected ? const Color(0xFFF5B942) : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(r['desc'] as String, style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFFF5B942)) : null,
                onTap: () {
                  widget.onRegionChanged(r['name'] as String);
                  Navigator.pop(context);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
