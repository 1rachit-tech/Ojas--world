import 'package:flutter/material.dart';

class CameraSettingsSheet extends StatefulWidget {
  final bool isGridEnabled;
  final String selectedResolution;
  final bool autoSaveToGallery;
  final Function(bool grid, String res, bool autoSave) onSettingsChanged;

  const CameraSettingsSheet({
    super.key,
    required this.isGridEnabled,
    required this.selectedResolution,
    required this.autoSaveToGallery,
    required this.onSettingsChanged,
  });

  static void show(
    BuildContext context, {
    required bool isGridEnabled,
    required String selectedResolution,
    required bool autoSaveToGallery,
    required Function(bool grid, String res, bool autoSave) onSettingsChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CameraSettingsSheet(
        isGridEnabled: isGridEnabled,
        selectedResolution: selectedResolution,
        autoSaveToGallery: autoSaveToGallery,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }

  @override
  State<CameraSettingsSheet> createState() => _CameraSettingsSheetState();
}

class _CameraSettingsSheetState extends State<CameraSettingsSheet> {
  late bool _grid;
  late String _res;
  late bool _autoSave;

  @override
  void initState() {
    super.initState();
    _grid = widget.isGridEnabled;
    _res = widget.selectedResolution;
    _autoSave = widget.autoSaveToGallery;
  }

  void _update() {
    widget.onSettingsChanged(_grid, _res, _autoSave);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
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
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera Studio Settings',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Resolution Selection (Max 1080p 60FPS)
          const Text('Video Quality (Max 1080p 60FPS)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: ['720p 30fps', '1080p 30fps', '1080p 60fps'].map((r) {
              final isSelected = _res == r;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(r),
                  selected: isSelected,
                  selectedColor: const Color(0xFFF5B942),
                  backgroundColor: const Color(0xFF21262D),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (_) {
                    setState(() => _res = r);
                    _update();
                  },
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white10),

          // 3x3 Grid Lines Switch
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('3x3 Camera Grid', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Helps with alignment and framing', style: TextStyle(color: Colors.white38, fontSize: 12)),
            value: _grid,
            activeColor: const Color(0xFFF5B942),
            onChanged: (val) {
              setState(() => _grid = val);
              _update();
            },
          ),

          // Auto Save Switch
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-save to Gallery', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Save original raw video to device gallery', style: TextStyle(color: Colors.white38, fontSize: 12)),
            value: _autoSave,
            activeColor: const Color(0xFFF5B942),
            onChanged: (val) {
              setState(() => _autoSave = val);
              _update();
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
