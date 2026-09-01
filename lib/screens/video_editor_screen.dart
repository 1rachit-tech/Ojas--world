import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'post_preview_screen.dart';
import '../widgets/sound_picker_sheet.dart';
import '../widgets/filter_store_sheet.dart';
import '../widgets/voiceover_mixer_sheet.dart';
import '../widgets/stickers_tray_sheet.dart';

class VideoEditorScreen extends StatefulWidget {
  final String mediaPath;
  final bool isVideo;

  const VideoEditorScreen({
    super.key,
    required this.mediaPath,
    required this.isVideo,
  });

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoPlayerController? _videoController;
  bool _isMuted = false;
  String _selectedMusic = 'Original Sound';
  OjasFilter _appliedFilter = kAllOjasFilters[0];

  // Drag-and-Drop Overlay Models
  final List<Map<String, dynamic>> _textOverlays = [];
  final List<Map<String, dynamic>> _stickerOverlays = [];

  double _origVol = 1.0;
  double _musVol = 0.8;
  double _trimStart = 0.0;
  double _trimEnd = 1.0;
  double _videoSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo && widget.mediaPath.isNotEmpty) {
      _videoController = VideoPlayerController.file(File(widget.mediaPath))
        ..initialize().then((_) {
          _videoController?.setLooping(true);
          _videoController?.play();
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _addTextOverlay() {
    final TextEditingController textCtrl = TextEditingController();
    Color selectedColor = Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textCtrl,
                autofocus: true,
                style: TextStyle(color: selectedColor, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: 'Type something...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildColorDot(Colors.white, selectedColor, (c) => setSheetState(() => selectedColor = c)),
                  _buildColorDot(const Color(0xFFF5B942), selectedColor, (c) => setSheetState(() => selectedColor = c)),
                  _buildColorDot(const Color(0xFFEF4444), selectedColor, (c) => setSheetState(() => selectedColor = c)),
                  _buildColorDot(const Color(0xFF10B981), selectedColor, (c) => setSheetState(() => selectedColor = c)),
                  _buildColorDot(const Color(0xFF38BDF8), selectedColor, (c) => setSheetState(() => selectedColor = c)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5B942),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (textCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _textOverlays.add({
                          'text': textCtrl.text.trim(),
                          'color': selectedColor,
                          'position': const Offset(80, 260),
                        });
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Add to Video', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color, Color selected, Function(Color) onSelect) {
    final isSelected = color == selected;
    return GestureDetector(
      onTap: () => onSelect(color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
        ),
      ),
    );
  }

  void _openMusicSelector() {
    SoundPickerSheet.show(
      context,
      currentSound: _selectedMusic,
      onSoundSelected: (music) => setState(() => _selectedMusic = music),
    );
  }

  void _openFilters() {
    FilterStoreSheet.show(
      context,
      selectedFilterId: _appliedFilter.id,
      onFilterApplied: (filter) => setState(() => _appliedFilter = filter),
    );
  }

  void _openVoiceoverMixer() {
    VoiceoverMixerSheet.show(
      context,
      originalVolume: _origVol,
      musicVolume: _musVol,
      onMixerChanged: (orig, mus, effect) {
        setState(() {
          _origVol = orig;
          _musVol = mus;
          _videoController?.setVolume(_origVol);
        });
      },
    );
  }

  void _openStickersTray() {
    StickersTraySheet.show(
      context,
      onStickerSelected: (stk) {
        setState(() {
          _stickerOverlays.add({
            'sticker': stk,
            'position': const Offset(80, 200),
          });
        });
      },
    );
  }

  void _openAdvancedEditorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF11151B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.52,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Advanced Video Studio', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.check_circle_rounded, color: Color(0xFFF5B942), size: 28), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),
                  const Text('Trim & Cut Timeline', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(color: const Color(0xFF1E242C), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF5B942), width: 1.5)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (i) => Icon(Icons.movie_creation_outlined, color: Colors.white.withValues(alpha: 0.25), size: 24)),
                    ),
                  ),
                  RangeSlider(
                    values: RangeValues(_trimStart, _trimEnd),
                    activeColor: const Color(0xFFF5B942),
                    inactiveColor: Colors.white24,
                    onChanged: (values) {
                      setSheetState(() {
                        _trimStart = values.start;
                        _trimEnd = values.end;
                      });
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Playback Speed', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('${_videoSpeed}x', style: const TextStyle(color: Color(0xFFF5B942), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [0.5, 1.0, 1.5, 2.0, 3.0].map((s) {
                      final isSelected = _videoSpeed == s;
                      return ChoiceChip(
                        label: Text('${s}x'),
                        selected: isSelected,
                        selectedColor: const Color(0xFFF5B942),
                        backgroundColor: const Color(0xFF1E242C),
                        labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                        onSelected: (_) {
                          setSheetState(() => _videoSpeed = s);
                          setState(() {
                            _videoSpeed = s;
                            _videoController?.setPlaybackSpeed(s);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _goToPostPreview() {
    _videoController?.pause();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostPreviewScreen(mediaPath: widget.mediaPath, isVideo: widget.isVideo)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Media Preview with Matrix Filter
          Center(
            child: ColorFiltered(
              colorFilter: _appliedFilter.matrixFilter ?? const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
              child: widget.isVideo
                  ? (_videoController != null && _videoController!.value.isInitialized
                      ? AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!))
                      : const CircularProgressIndicator(color: Color(0xFFF5B942)))
                  : (widget.mediaPath.isNotEmpty
                      ? Image.file(File(widget.mediaPath), fit: BoxFit.contain)
                      : const Icon(Icons.image, size: 80, color: Colors.white24)),
            ),
          ),

          // 2. Drag & Drop Interactive Text Overlays
          ..._textOverlays.asMap().entries.map((entry) {
            final idx = entry.key;
            final data = entry.value;
            final pos = data['position'] as Offset;

            return Positioned(
              left: pos.dx,
              top: pos.dy,
              child: Draggable(
                feedback: Material(
                  color: Colors.transparent,
                  child: Text(
                    data['text'] as String,
                    style: TextStyle(
                      color: data['color'] as Color,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                ),
                childWhenDragging: const SizedBox.shrink(),
                onDragEnd: (details) {
                  setState(() {
                    _textOverlays[idx]['position'] = Offset(
                      details.offset.dx.clamp(20.0, MediaQuery.of(context).size.width - 150),
                      details.offset.dy.clamp(90.0, MediaQuery.of(context).size.height - 150),
                    );
                  });
                },
                child: GestureDetector(
                  onLongPress: () {
                    setState(() => _textOverlays.removeAt(idx));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Text removed'), duration: Duration(milliseconds: 600)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      data['text'] as String,
                      style: TextStyle(
                        color: data['color'] as Color,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),

          // 3. Drag & Drop Interactive Sticker Overlays
          ..._stickerOverlays.asMap().entries.map((entry) {
            final idx = entry.key;
            final data = entry.value;
            final pos = data['position'] as Offset;

            return Positioned(
              left: pos.dx,
              top: pos.dy,
              child: Draggable(
                feedback: Material(
                  color: Colors.transparent,
                  child: Text(
                    data['sticker'] as String,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                childWhenDragging: const SizedBox.shrink(),
                onDragEnd: (details) {
                  setState(() {
                    _stickerOverlays[idx]['position'] = Offset(
                      details.offset.dx.clamp(20.0, MediaQuery.of(context).size.width - 120),
                      details.offset.dy.clamp(90.0, MediaQuery.of(context).size.height - 150),
                    );
                  });
                },
                child: GestureDetector(
                  onLongPress: () {
                    setState(() => _stickerOverlays.removeAt(idx));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sticker removed'), duration: Duration(milliseconds: 600)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF5B942)),
                    ),
                    child: Text(
                      data['sticker'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            );
          }),

          // 4. Top Action Bar
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                GestureDetector(
                  onTap: _openMusicSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.music_note_rounded, color: Color(0xFFF5B942), size: 16),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            _selectedMusic,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.isVideo)
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 20),
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                          _videoController?.setVolume(_isMuted ? 0.0 : _origVol);
                        });
                      },
                    ),
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
          ),

          // 5. Right Quick Editing Rail
          Positioned(
            top: 115,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _buildEditorTool(icon: Icons.title_rounded, label: 'Text', onTap: _addTextOverlay),
                  const SizedBox(height: 14),
                  _buildEditorTool(icon: Icons.auto_awesome_rounded, label: 'Filters', onTap: _openFilters),
                  const SizedBox(height: 14),
                  _buildEditorTool(icon: Icons.mic_rounded, label: 'Audio Mix', onTap: _openVoiceoverMixer),
                  const SizedBox(height: 14),
                  _buildEditorTool(icon: Icons.sticky_note_2_outlined, label: 'Stickers', onTap: _openStickersTray),
                ],
              ),
            ),
          ),

          // 6. Bottom Navigation Controls
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Row(
              children: [
                if (widget.isVideo)
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.black54,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _openAdvancedEditorModal,
                      icon: const Icon(Icons.movie_edit, color: Colors.white, size: 18),
                      label: const Text('Edit Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5B942),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _goToPostPreview,
                    label: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorTool({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
