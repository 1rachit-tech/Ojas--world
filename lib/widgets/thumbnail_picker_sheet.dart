import 'package:flutter/material.dart';

class ThumbnailPickerSheet extends StatefulWidget {
  final double currentPosition;
  final Function(double position) onThumbnailSelected;

  const ThumbnailPickerSheet({
    super.key,
    required this.currentPosition,
    required this.onThumbnailSelected,
  });

  static void show(
    BuildContext context, {
    required double currentPosition,
    required Function(double position) onThumbnailSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ThumbnailPickerSheet(
        currentPosition: currentPosition,
        onThumbnailSelected: onThumbnailSelected,
      ),
    );
  }

  @override
  State<ThumbnailPickerSheet> createState() => _ThumbnailPickerSheetState();
}

class _ThumbnailPickerSheetState extends State<ThumbnailPickerSheet> {
  late double _pos;

  @override
  void initState() {
    super.initState();
    _pos = widget.currentPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF13171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Video Cover', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5B942),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  widget.onThumbnailSelected(_pos);
                  Navigator.pop(context);
                },
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          const SizedBox(height: 14),

          // Selected Frame Preview Box
          Container(
            width: 130,
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF5B942), width: 2),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.movie_filter_rounded, color: Color(0xFFF5B942), size: 36),
                  const SizedBox(height: 6),
                  Text('Frame: ${(_pos * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const Spacer(),

          // Frame Scrubber Slider
          const Text('Drag slider to choose the best frame for your cover', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          Slider(
            value: _pos,
            activeColor: const Color(0xFFF5B942),
            inactiveColor: Colors.white24,
            onChanged: (val) => setState(() => _pos = val),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
