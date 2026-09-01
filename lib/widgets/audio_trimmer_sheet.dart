import 'package:flutter/material.dart';

class AudioTrimmerSheet extends StatefulWidget {
  final String soundTitle;
  final String artist;
  final Function(double startSec, double duration) onSoundSelected;

  const AudioTrimmerSheet({
    super.key,
    required this.soundTitle,
    required this.artist,
    required this.onSoundSelected,
  });

  static void show(
    BuildContext context, {
    required String soundTitle,
    required String artist,
    required Function(double startSec, double duration) onSoundSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AudioTrimmerSheet(
        soundTitle: soundTitle,
        artist: artist,
        onSoundSelected: onSoundSelected,
      ),
    );
  }

  @override
  State<AudioTrimmerSheet> createState() => _AudioTrimmerSheetState();
}

class _AudioTrimmerSheetState extends State<AudioTrimmerSheet> {
  double _startPosition = 0.0;
  double _clipDuration = 15.0; // 15s or 30s
  bool _isPlaying = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.soundTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                    ),
                    Text(
                      widget.artist,
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: const Color(0xFF111827),
                  size: 32,
                ),
                onPressed: () => setState(() => _isPlaying = !_isPlaying),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Duration Selection Pills
          Row(
            children: [
              const Text('Clip Length:', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              _buildDurationPill(15.0, '15s'),
              const SizedBox(width: 8),
              _buildDurationPill(30.0, '30s'),
              const SizedBox(width: 8),
              _buildDurationPill(60.0, '60s'),
            ],
          ),
          const SizedBox(height: 20),

          // Simulated Audio Waveform & Trimmer Range Slider
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    28,
                    (i) => Container(
                      width: 4,
                      height: 12.0 + ((i % 5) * 6.0),
                      decoration: BoxDecoration(
                        color: (i >= (_startPosition / 2) && i <= ((_startPosition + _clipDuration) / 2))
                            ? const Color(0xFF111827)
                            : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF111827),
                    inactiveTrackColor: const Color(0xFFE5E7EB),
                    thumbColor: const Color(0xFF111827),
                    overlayColor: const Color(0x1A111827),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _startPosition,
                    min: 0.0,
                    max: 60.0,
                    onChanged: (val) => setState(() => _startPosition = val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Apply Audio Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onSoundSelected(_startPosition, _clipDuration);
              },
              child: const Text('Use Selected Part', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationPill(double dur, String label) {
    final isSelected = _clipDuration == dur;
    return GestureDetector(
      onTap: () => setState(() => _clipDuration = dur),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
