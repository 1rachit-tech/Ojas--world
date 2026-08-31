import 'package:flutter/material.dart';

class VoiceoverMixerSheet extends StatefulWidget {
  final double originalVolume;
  final double musicVolume;
  final Function(double origVol, double musVol, String voiceEffect) onMixerChanged;

  const VoiceoverMixerSheet({
    super.key,
    required this.originalVolume,
    required this.musicVolume,
    required this.onMixerChanged,
  });

  static void show(
    BuildContext context, {
    required double originalVolume,
    required double musicVolume,
    required Function(double origVol, double musVol, String voiceEffect) onMixerChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceoverMixerSheet(
        originalVolume: originalVolume,
        musicVolume: musicVolume,
        onMixerChanged: onMixerChanged,
      ),
    );
  }

  @override
  State<VoiceoverMixerSheet> createState() => _VoiceoverMixerSheetState();
}

class _VoiceoverMixerSheetState extends State<VoiceoverMixerSheet> {
  late double _orig;
  late double _mus;
  String _selectedEffect = 'None';
  bool _isRecordingVoiceover = false;

  final List<String> _voiceEffects = ['None', 'Studio Mic 🎙️', 'Deep Voice 🦁', 'Helium 🎈', 'Echo Chamber 🌌', 'Robot 🤖'];

  @override
  void initState() {
    super.initState();
    _orig = widget.originalVolume;
    _mus = widget.musicVolume;
  }

  void _apply() {
    widget.onMixerChanged(_orig, _mus, _selectedEffect);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF13171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Audio Studio & Voiceover', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.check_circle_rounded, color: Color(0xFFF5B942), size: 28), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),

          // Sliders: Original & Added Music
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Original Audio', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('${(_orig * 100).round()}%', style: const TextStyle(color: Color(0xFFF5B942), fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _orig,
            activeColor: const Color(0xFFF5B942),
            inactiveColor: Colors.white24,
            onChanged: (val) {
              setState(() => _orig = val);
              _apply();
            },
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Added Music Track', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('${(_mus * 100).round()}%', style: const TextStyle(color: Color(0xFFF5B942), fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _mus,
            activeColor: const Color(0xFFF5B942),
            inactiveColor: Colors.white24,
            onChanged: (val) {
              setState(() => _mus = val);
              _apply();
            },
          ),

          const SizedBox(height: 10),
          const Text('Voice Effects & AI Filter', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _voiceEffects.length,
              itemBuilder: (context, index) {
                final ef = _voiceEffects[index];
                final isSelected = _selectedEffect == ef;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(ef),
                    selected: isSelected,
                    selectedColor: const Color(0xFFF5B942),
                    backgroundColor: const Color(0xFF21262D),
                    labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                    onSelected: (_) {
                      setState(() => _selectedEffect = ef);
                      _apply();
                    },
                  ),
                );
              },
            ),
          ),

          const Spacer(),

          // Tap to Record Voiceover Button
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() => _isRecordingVoiceover = !_isRecordingVoiceover);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_isRecordingVoiceover ? 'Recording voiceover... 🎙️' : 'Voiceover saved to track!')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _isRecordingVoiceover ? Colors.redAccent : const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _isRecordingVoiceover ? Colors.redAccent : const Color(0xFFF5B942)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isRecordingVoiceover ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      _isRecordingVoiceover ? 'Stop Recording' : 'Tap to Record Voiceover',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
