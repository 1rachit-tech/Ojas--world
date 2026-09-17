import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/creation_project.dart';
import '../services/creation_checkpoint_store.dart';
import '../services/creation_edit_command_service.dart';
import '../services/creation_pipeline_service.dart';
import '../services/creation_project_store.dart';
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
  late final TextEditingController _captionController;
  double _trimStart = 0;
  double _trimEnd = 1;
  late final CreationEditCommandService _editEngine;
  final List<CreationProject> _undoStack = <CreationProject>[];
  final List<CreationProject> _redoStack = <CreationProject>[];

  CreationTimelineClip? get _primaryClip => _project.timeline.isEmpty ? null : _project.timeline.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _editEngine = const CreationEditCommandService();
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
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      controller.pause();
      _scheduleAutosave();
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
    if (_saving || !mounted) return;
    setState(() => _saving = true);
    try {
      var next = _project.copyWith(
        status: CreationProjectStatus.autosaved,
        caption: _captionController.text,
        updatedAt: DateTime.now(),
      );
      next = CreationPipelineService.markStage(
        next,
        CreationProjectStatus.autosaved,
        stageName: 'draft_checkpoint',
      );
      await CreationProjectStore.instance.save(next);
      await CreationCheckpointStore.instance.save(next);
      _project = next;
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft checkpoint saved locally.')),
        );
      }
    } catch (error) {
      debugPrint('Creation draft checkpoint failed: $error');
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this checkpoint.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyEdit(CreationProject next) {
    if (identical(next, _project) || next.version == _project.version) return;
    _undoStack.add(_project);
    if (_undoStack.length > 30) _undoStack.removeAt(0);
    _redoStack.clear();
    setState(() => _project = next);
    _scheduleAutosave();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    _redoStack.add(_project);
    setState(() => _project = previous);
    _scheduleAutosave();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(_project);
    setState(() => _project = next);
    _scheduleAutosave();
  }

  Future<void> _openTextTool() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(hintText: 'Type text'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (value == null || value.isEmpty || !mounted) return;
    _applyEdit(_editEngine.addText(_project, text: value));
  }

  Future<void> _openAudioTool() async {
    final controller = TextEditingController();
    final uri = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add audio'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'Local/content URI'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (uri == null || uri.isEmpty || !mounted) return;
    _applyEdit(_editEngine.addAudio(_project, uri: uri));
  }

  Future<void> _openEffectsTool() async {
    const effects = <String>['warm', 'cool', 'mono', 'vivid'];
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: effects
              .map((effect) => ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: Text(effect.toUpperCase()),
                    onTap: () => Navigator.pop(sheetContext, effect),
                  ))
              .toList(),
        ),
      ),
    );
    if (value == null || !mounted) return;
    _applyEdit(_editEngine.addEffect(_project, effectId: value));
  }

  Future<void> _openAdjustTool() async {
    final clip = _primaryClip;
    if (clip == null) return;
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Adjust clip', style: TextStyle(fontWeight: FontWeight.w800))),
            ListTile(leading: const Icon(Icons.rotate_right), title: const Text('Rotate 90°'), onTap: () => Navigator.pop(sheetContext, 'rotate')),
            ListTile(leading: const Icon(Icons.speed), title: const Text('Speed 2×'), onTap: () => Navigator.pop(sheetContext, 'speed2')),
            ListTile(leading: const Icon(Icons.slow_motion_video), title: const Text('Speed 0.5×'), onTap: () => Navigator.pop(sheetContext, 'speed05')),
            ListTile(leading: const Icon(Icons.call_split), title: const Text('Split at current position'), onTap: () => Navigator.pop(sheetContext, 'split')),
          ],
        ),
      ),
    );
    if (value == null || !mounted) return;
    switch (value) {
      case 'rotate':
        _applyEdit(_editEngine.setTransform(_project, clipId: clip.clipId, rotation: clip.rotation + 90));
        break;
      case 'speed2':
        _applyEdit(_editEngine.setSpeed(_project, clipId: clip.clipId, speed: 2));
        break;
      case 'speed05':
        _applyEdit(_editEngine.setSpeed(_project, clipId: clip.clipId, speed: 0.5));
        break;
      case 'split':
        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) return;
        final position = controller.value.position.inMilliseconds;
        _applyEdit(_editEngine.splitClip(_project, clipId: clip.clipId, splitAtMs: position));
        break;
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
              TextField(controller: controller, maxLength: 2200, minLines: 4, maxLines: 8, decoration: InputDecoration(hintText: 'Tell people about this post…', filled: true, fillColor: const Color(0xFFF5F5F5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: () => Navigator.pop(sheetContext, controller.text.trim()), child: const Text('Save caption'))),
            ],
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    _captionController.text = result;
    setState(() {});
    _scheduleAutosave();
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
                ...options.map((option) => ListTile(leading: Icon(option == 'Public' ? Icons.public : option == 'Followers' ? Icons.group : Icons.lock), title: Text(option), trailing: _project.privacy == option ? const Icon(Icons.check_circle) : null, onTap: () => Navigator.pop(sheetContext, option))),
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
    var readyProject = _project.copyWith(status: CreationProjectStatus.ready, caption: _captionController.text.trim(), updatedAt: DateTime.now());
    readyProject = CreationPipelineService.markStage(readyProject, CreationProjectStatus.ready, stageName: 'post_composition');
    await CreationProjectStore.instance.save(readyProject);
    await CreationCheckpointStore.instance.save(readyProject);
    _project = readyProject;
    if (!mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => CreationPostComposerScreen(project: readyProject)));
  }

  Future<void> _setTrim(double start, double end) async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized || _project.timeline.isEmpty) return;
    final durationMs = controller.value.duration.inMilliseconds;
    final safeStart = start.clamp(0.0, 0.98);
    final safeEnd = end.clamp(safeStart + 0.01, 1.0);
    final clip = _primaryClip!;
    final trimIn = (durationMs * safeStart).round();
    final trimOut = (durationMs * safeEnd).round();
    _trimStart = safeStart;
    _trimEnd = safeEnd;
    _applyEdit(_editEngine.trimClip(_project, clipId: clip.clipId, trimInMs: trimIn, trimOutMs: trimOut));
    await controller.seekTo(Duration(milliseconds: trimIn));
    await controller.pause();
  }

  Widget _buildPreview() {
    if (_project.mediaAssets.isEmpty) return const Center(child: Text('No media', style: TextStyle(color: Colors.white)));
    final asset = _project.mediaAssets.first;
    if (asset.type != 'video') {
      return Image.file(File(asset.localUri), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Text('Unable to load image', style: TextStyle(color: Colors.white))));
    }
    if (_videoInitializing) return const Center(child: CircularProgressIndicator());
    if (_videoError || _videoController == null || !_videoController!.value.isInitialized) return const Center(child: Text('Unable to load video', style: TextStyle(color: Colors.white)));
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
      child: Center(child: AspectRatio(aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 9 / 16, child: VideoPlayer(controller))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = !_saving && _project.mediaAssets.isNotEmpty;
    final clip = _primaryClip;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Edit'),
        actions: [
          IconButton(onPressed: _undoStack.isEmpty ? null : _undo, icon: const Icon(Icons.undo), tooltip: 'Undo'),
          IconButton(onPressed: _redoStack.isEmpty ? null : _redo, icon: const Icon(Icons.redo), tooltip: 'Redo'),
          TextButton(onPressed: _saving ? null : () => _saveProject(showFeedback: true), child: const Text('Draft', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(child: _buildPreview()),
                Positioned(left: 12, right: 12, bottom: 12, child: Row(children: [
                  _ToolButton(icon: Icons.text_fields_rounded, label: 'Text', onTap: _openTextTool),
                  const SizedBox(width: 7),
                  _ToolButton(icon: Icons.music_note_rounded, label: 'Audio', onTap: _openAudioTool),
                  const SizedBox(width: 7),
                  _ToolButton(icon: Icons.auto_awesome_rounded, label: 'Effects', onTap: _openEffectsTool),
                  const SizedBox(width: 7),
                  _ToolButton(icon: Icons.tune_rounded, label: 'Adjust', onTap: _openAdjustTool),
                ])),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(children: [
              if (_videoController?.value.isInitialized == true && clip != null) ...[
                Row(children: [const Text('Trim', style: TextStyle(fontWeight: FontWeight.w800)), const Spacer(), Text('${(_trimStart * 100).round()}% — ${(_trimEnd * 100).round()}%')]),
                RangeSlider(values: RangeValues(_trimStart, _trimEnd), onChanged: (value) => _setTrim(value.start, value.end)),
                Align(alignment: Alignment.centerLeft, child: Text('${clip.speed.toStringAsFixed(2)}×  •  ${clip.rotation.toStringAsFixed(0)}°  •  v${_project.version}', style: const TextStyle(fontSize: 12, color: Colors.black54))),
                const SizedBox(height: 6),
              ],
              Row(children: [
                Expanded(child: _ComposerTile(icon: Icons.subtitles_rounded, title: _captionController.text.isEmpty ? 'Caption' : 'Caption added', onTap: _openCaption)),
                const SizedBox(width: 8),
                Expanded(child: _ComposerTile(icon: Icons.visibility_outlined, title: _project.privacy, onTap: _openPrivacy)),
              ]),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: canContinue ? _openPostComposer : null, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Continue to Post'))),
            ]),
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
  Widget build(BuildContext context) => Expanded(child: Material(color: Colors.black54, borderRadius: BorderRadius.circular(14), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Column(children: [Icon(icon, color: Colors.white, size: 19), const SizedBox(height: 3), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10))])))));
}

class _ComposerTile extends StatelessWidget {
  const _ComposerTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));
}
