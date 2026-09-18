import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/creation_project.dart';
import '../services/creation_project_store.dart';
import '../services/video_export_service.dart';
import 'creation_post_composer_screen.dart';

class CreationPipelineEditorScreen extends StatefulWidget {
  const CreationPipelineEditorScreen({super.key, required this.project});

  final CreationProject project;

  @override
  State<CreationPipelineEditorScreen> createState() => _CreationPipelineEditorScreenState();
}

class _CreationPipelineEditorScreenState extends State<CreationPipelineEditorScreen>
    with WidgetsBindingObserver {
  late CreationProject _project;
  VideoPlayerController? _videoController;
  Timer? _autosaveTimer;
  bool _saving = false;
  bool _videoInitializing = true;
  bool _videoError = false;
  bool _exporting = false;
  bool _cancelExportRequested = false;
  double _exportProgress = 0.0;
  late final TextEditingController _captionController;
  double _trimStart = 0.0;
  double _trimEnd = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _project = widget.project;
    _captionController = TextEditingController(text: _project.caption);
    _initializeMedia();
  }

  Future<void> _initializeMedia() async {
    if (_project.mediaAssets.isEmpty || _project.mediaAssets.first.type != 'video') {
      if (mounted) setState(() => _videoInitializing = false);
      return;
    }
    try {
      final controller = VideoPlayerController.file(File(_project.mediaAssets.first.localUri));
      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(false);
      final durationMs = controller.value.duration.inMilliseconds;
      if (_project.timeline.isNotEmpty && durationMs > 0) {
        final timeline = List<CreationTimelineClip>.from(_project.timeline);
        final current = timeline.first;
        final savedTrimOut = current.trimOutMs ?? durationMs;
        final safeTrimOut = savedTrimOut.clamp(1, durationMs);
        timeline[0] = current.copyWith(
          endMs: durationMs,
          trimOutMs: safeTrimOut,
        );
        _project = _project.copyWith(timeline: timeline);
        _trimStart = (current.trimInMs / durationMs).clamp(0.0, 0.98);
        _trimEnd = (safeTrimOut / durationMs).clamp(_trimStart + 0.01, 1.0);
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _videoInitializing = false);
    } catch (error) {
      debugPrint('Creation editor media initialization failed: $error');
      if (mounted) {
        setState(() {
          _videoInitializing = false;
          _videoError = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _videoController;
    if (controller == null) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 550), () {
      _saveProject(showFeedback: false);
    });
  }

  Future<void> _saveProject({required bool showFeedback}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      _project = _project.copyWith(
        status: CreationProjectStatus.autosaved,
        caption: _captionController.text,
        updatedAt: DateTime.now(),
        operations: <Map<String, dynamic>>[
          ..._project.operations,
          <String, dynamic>{
            'type': 'trim',
            'start': _trimStart,
            'end': _trimEnd,
            'at': DateTime.now().toIso8601String(),
          },
        ],
      );
      await CreationProjectStore.instance.save(_project);
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft checkpoint saved locally.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openCaption() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        final controller = TextEditingController(text: _captionController.text);
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 18, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Caption', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLength: 2200,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Tell people about this post…',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, controller.text.trim()),
                  child: const Text('Save caption'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    _captionController.text = result;
    _scheduleAutosave();
    setState(() {});
  }

  Future<void> _openPrivacy() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        const options = <String>['Public', 'Followers', 'Only Me'];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(alignment: Alignment.centerLeft, child: Text('Audience', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
                const SizedBox(height: 12),
                ...options.map(
                  (option) => ListTile(
                    leading: Icon(option == 'Public' ? Icons.public : option == 'Followers' ? Icons.group : Icons.lock),
                    title: Text(option),
                    trailing: _project.privacy == option ? const Icon(Icons.check_circle) : null,
                    onTap: () => Navigator.pop(sheetContext, option),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() => _project = _project.copyWith(privacy: result));
    _scheduleAutosave();
  }

  Future<void> _openPostComposer() async {
    if (_saving || _project.mediaAssets.isEmpty) return;
    final readyProject = _project.copyWith(
      status: CreationProjectStatus.ready,
      caption: _captionController.text.trim(),
      updatedAt: DateTime.now(),
    );
    await CreationProjectStore.instance.save(readyProject);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => CreationPostComposerScreen(project: readyProject)),
    );
  }

  Future<void> _setTrim(double start, double end) async {
    final safeStart = start.clamp(0.0, 0.98);
    final safeEnd = end.clamp(safeStart + 0.01, 1.0);
    setState(() {
      _trimStart = safeStart;
      _trimEnd = safeEnd;
    });
    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      final duration = controller.value.duration;
      await controller.seekTo(Duration(milliseconds: (duration.inMilliseconds * safeStart).round()));
      await controller.pause();
    }
    _scheduleAutosave();
  }

  Widget _buildPreview() {
    if (_project.mediaAssets.isEmpty) return const Center(child: Text('No media', style: TextStyle(color: Colors.white)));
    final asset = _project.mediaAssets.first;
    if (asset.type != 'video') {
      return Image.file(
        File(asset.localUri),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(child: Text('Unable to load image', style: TextStyle(color: Colors.white))),
      );
    }
    if (_videoInitializing) return const Center(child: CircularProgressIndicator());
    if (_videoError || _videoController == null || !_videoController!.value.isInitialized) {
      return const Center(child: Text('Unable to load video', style: TextStyle(color: Colors.white)));
    }
    final controller = _videoController!;
    return GestureDetector(
      onTap: () async {
        if (controller.value.isPlaying) {
          await controller.pause();
        } else {
          await controller.play();
        }
        if (mounted) setState(() {});
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 9 / 16,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = !_saving && _project.mediaAssets.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Edit'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _saveProject(showFeedback: true),
            child: const Text('Draft', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(child: _buildPreview()),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      _ToolButton(icon: Icons.text_fields_rounded, label: 'Text', onTap: () {}),
                      const SizedBox(width: 8),
                      _ToolButton(icon: Icons.music_note_rounded, label: 'Audio', onTap: () {}),
                      const SizedBox(width: 8),
                      _ToolButton(icon: Icons.auto_awesome_rounded, label: 'Effects', onTap: () {}),
                      const SizedBox(width: 8),
                      _ToolButton(icon: Icons.tune_rounded, label: 'Adjust', onTap: () {}),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                if (_videoController?.value.isInitialized == true) ...[
                  Row(
                    children: [
                      const Text('Trim', style: TextStyle(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text('${(_trimStart * 100).round()}% — ${(_trimEnd * 100).round()}%'),
                    ],
                  ),
                  RangeSlider(values: RangeValues(_trimStart, _trimEnd), onChanged: (value) => _setTrim(value.start, value.end)),
                ],
                Row(
                  children: [
                    Expanded(child: _ComposerTile(icon: Icons.subtitles_rounded, title: _captionController.text.isEmpty ? 'Caption' : 'Caption added', onTap: _openCaption)),
                    const SizedBox(width: 8),
                    Expanded(child: _ComposerTile(icon: Icons.visibility_outlined, title: _project.privacy, onTap: _openPrivacy)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: canContinue ? _openPostComposer : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Continue to Post'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(children: [Icon(icon, color: Colors.white, size: 19), const SizedBox(height: 3), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10))]),
          ),
        ),
      ),
    );
  }
}

class _ComposerTile extends StatelessWidget {
  const _ComposerTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    );
  }
}
