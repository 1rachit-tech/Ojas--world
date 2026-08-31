import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'post_preview_screen.dart';
import '../widgets/sound_picker_sheet.dart';
import '../widgets/filter_store_sheet.dart';

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
  final List<String> _textOverlays = [];

  // Advanced Editor Modal State
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

  // 1. Text Overlay Tool
  void _addTextOverlay() {
    final TextEditingController textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('Add Text Overlay', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: TextField(
            controller: textCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: 'Type something...',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5B942)),
              onPressed: () {
                if (textCtrl.text.trim().isNotEmpty) {
                  setState(() => _textOverlays.add(textCtrl.text.trim()));
                }
                Navigator.pop(context);
              },
              child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 2. Audio & Music Selector
  void _openMusicSelector() {
    SoundPickerSheet.show(
      context,
      currentSound: _selectedMusic,
      onSoundSelected: (music) {
        setState(() => _selectedMusic = music);
      },
    );
  }

  // 3. Filters Sheet
  void _openFilters() {
    FilterStoreSheet.show(
      context,
      selectedFilterId: _appliedFilter.id,
      onFilterApplied: (filter) {
        setState(() => _appliedFilter = filter);
      },
    );
  }

  // 4. Advanced Timeline Editor (CapCut/TikTok Studio Style)
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
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Advanced Video Studio', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFFF5B942), size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),

                  // Trim Timeline
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

                  // Speed Control Curve
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Playback Speed Curve', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
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

  // 5. Next to Post Preview
  void _goToPostPreview() {
    _videoController?.pause();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostPreviewScreen(
          mediaPath: widget.mediaPath,
          isVideo: widget.isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Media Preview Area (With Filter Applied)
          Center(
            child: ColorFiltered(
              colorFilter: _appliedFilter.matrixFilter ?? const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
              child: widget.isVideo
                  ? (_videoController != null && _videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const CircularProgressIndicator(color: Color(0xFFF5B942)))
                  : (widget.mediaPath.isNotEmpty
                      ? Image.file(File(widget.mediaPath), fit: BoxFit.contain)
                      : const Icon(Icons.image, size: 80, color: Colors.white24)),
            ),
          ),

          // 2. Text Overlays on Screen
          ..._textOverlays.map((text) {
            return Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
            );
          }),

          // 3. Top Action Bar (Back, Sound Selector, Mute)
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
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.music_note_rounded, color: Color(0xFFF5B942), size: 16),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(_selectedMusic, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
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
                          _videoController?.setVolume(_isMuted ? 0.0 : 1.0);
                        });
                      },
                    ),
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
          ),

          // 4. Right Quick Editing Rail (Text, Filters, Voiceover, Stickers)
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
                  _buildEditorTool(icon: Icons.mic_rounded, label: 'Voiceover', onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voiceover recorder ready! 🎙️')));
                  }),
                  const SizedBox(height: 14),
                  _buildEditorTool(icon: Icons.sticky_note_2_outlined, label: 'Stickers', onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stickers tray opened! 🎨')));
                  }),
                ],
              ),
            ),
          ),

          // 5. Bottom Controls (Advanced Edit Video + Next Button)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Advanced Edit Video Button
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

                // Next Button (Redirection to Post Screen)
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
