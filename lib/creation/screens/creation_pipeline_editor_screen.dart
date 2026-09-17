import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
  String? _selectedClipId;
  late final CreationEditCommandService _editEngine;
  final List<CreationProject> _undoStack = <CreationProject>[];
  final List<CreationProject> _redoStack = <CreationProject>[];

  CreationTimelineClip? get _primaryClip {
    if (_project.timeline.isEmpty) return null;
    final selectedId = _selectedClipId;
    if (selectedId != null) {
      for (final clip in _project.timeline) {
        if (clip.clipId == selectedId) return clip;
      }
    }
    return _project.timeline.first;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _editEngine = const CreationEditCommandService();
    _project = widget.project;
    _selectedClipId = _project.timeline.isEmpty ? null : _project.timeline.first.clipId;
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
      final clip = _primaryClip;
      if (clip != null) _syncTrimState(clip, seek: false);
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

  void _syncTrimState(CreationTimelineClip clip, {bool seek = true}) {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final durationMs = controller.value.duration.inMilliseconds;
    if (durationMs <= 0) return;
    final start = (clip.effectiveStartMs / durationMs).clamp(0.0, 0.98).toDouble();
    final end = (clip.effectiveEndMs / durationMs).clamp(start + 0.01, 1.0).toDouble();
    _trimStart = start;
    _trimEnd = end;
    if (seek) {
      controller.seekTo(Duration(milliseconds: clip.effectiveStartMs));
      controller.pause();
    }
  }

  void _selectClip(CreationTimelineClip clip) {
    if (!mounted) return;
    setState(() {
      _selectedClipId = clip.clipId;
      _syncTrimState(clip, seek: true);
    });
  }

  void _repairSelection(CreationProject next) {
    final selectedId = _selectedClipId;
    if (selectedId != null && next.timeline.any((clip) => clip.clipId == selectedId)) return;
    _selectedClipId = next.timeline.isEmpty ? null : next.timeline.first.clipId;
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
      _repairSelection(next);
      final clip = _primaryClip;
      if (clip != null) _syncTrimState(clip, seek: false);
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
    setState(() {
      _project = next;
      _repairSelection(next);
      final clip = _primaryClip;
      if (clip != null) _syncTrimState(clip, seek: false);
    });
    _scheduleAutosave();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    _redoStack.add(_project);
    setState(() {
      _project = previous;
      _repairSelection(previous);
      final clip = _primaryClip;
      if (clip != null) _syncTrimState(clip, seek: false);
    });
    _scheduleAutosave();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(_project);
    setState(() {
      _project = next;
      _repairSelection(next);
      final clip = _primaryClip;
      if (clip != null) _syncTrimState(clip, seek: false);
    });
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
    final clip = _primaryClip;
    final controllerValue = _videoController;
    final startMs = clip?.effectiveStartMs ?? 0;
    final endMs = clip?.effectiveEndMs ?? controllerValue?.value.duration.inMilliseconds;
    _applyEdit(_editEngine.addText(_project, text: value, startMs: startMs, endMs: endMs));
  }

  Future<void> _openAudioTool() async {
    final picked = await FilePicker.pickFile(type: FileType.audio);
    if (picked == null || !mounted) return;

    final localPath = picked.path?.trim();
    if (localPath == null || localPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This audio file is not available as a local file.')),
      );
      return;
    }

    final length = await picked.length();
    if (length == null || length <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected audio file.')),
      );
      return;
    }
    if (length > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio must be 10 MB or smaller.')),
      );
      return;
    }

    final clip = _primaryClip;
    _applyEdit(
      _editEngine.addAudio(
        _project,
        uri: localPath,
        title: picked.name,
        startMs: clip?.effectiveStartMs ?? 0,
        endMs: clip?.effectiveEndMs,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${picked.name} added to the edit.')),
    );
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
            ListTile(leading: const Icon(Icons.opacity), title: const Text('Opacity 50%'), onTap: () => Navigator.pop(sheetContext, 'opacity')),
            ListTile(leading: const Icon(Icons.call_split), title: const Text('Split at current position'), onTap: () => Navigator.pop(sheetContext, 'split')),
            ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete this clip'), onTap: () => Navigator.pop(sheetContext, 'delete')),
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
      case 'opacity':
        _applyEdit(_editEngine.setTransform(_project, clipId: clip.clipId, opacity: 0.5));
        break;
      case 'split':
        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) return;
        final position = controller.value.position.inMilliseconds;
        final currentIndex = _project.timeline.indexWhere((item) => item.clipId == clip.clipId);
        final next = _editEngine.splitClip(_project, clipId: clip.clipId, splitAtMs: position);
        if (next.version != _project.version) {
          _selectedClipId = currentIndex >= 0 && currentIndex < next.timeline.length
              ? next.timeline[currentIndex].clipId
              : next.timeline.first.clipId;
        }
        _applyEdit(next);
        break;
      case 'delete':
        if (_project.timeline.length == 1) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one clip is required.')));
          return;
        }
        final currentIndex = _project.timeline.indexWhere((item) => item.clipId == clip.clipId);
        final next = _editEngine.deleteClip(_project, clipId: clip.clipId);
        if (next.version != _project.version) {
          final nextIndex = currentIndex.clamp(0, next.timeline.length - 1);
          _selectedClipId = next.timeline[nextIndex].clipId;
        }
        _applyEdit(next);
        break;
    }
  }

  Future<void> _openCropTool() async {
    final clip = _primaryClip;
    if (clip == null) return;
    var left = clip.cropLeft;
    var top = clip.cropTop;
    var right = clip.cropRight;
    var bottom = clip.cropBottom;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: Text('Crop', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
                  const SizedBox(height: 12),
                  _CropSlider(label: 'Left', value: left, onChanged: (v) => setSheetState(() => left = v)),
                  _CropSlider(label: 'Top', value: top, onChanged: (v) => setSheetState(() => top = v)),
                  _CropSlider(label: 'Right', value: right, onChanged: (v) => setSheetState(() => right = v)),
                  _CropSlider(label: 'Bottom', value: bottom, onChanged: (v) => setSheetState(() => bottom = v)),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: () => Navigator.pop(sheetContext, true), child: const Text('Apply crop'))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result != true || !mounted) return;
    _applyEdit(_editEngine.setCrop(_project, clipId: clip.clipId, left: left, top: top, right: right, bottom: bottom));
  }

  void _movePrimaryClip(int delta) {
    final clip = _primaryClip;
    if (clip == null) return;
    final current = _project.timeline.indexWhere((item) => item.clipId == clip.clipId);
    final target = current + delta;
    if (current < 0 || target < 0 || target >= _project.timeline.length) return;
    _applyEdit(_editEngine.reorderClip(_project, clipId: clip.clipId, toIndex: target));
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
    final safeStart = start.clamp(0.0, 0.98).toDouble();
    final safeEnd = end.clamp(safeStart + 0.01, 1.0).toDouble();
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
    final clip = _primaryClip;
    final rotationTurns = ((clip?.rotation ?? 0) / 90).round();
    final opacity = (clip?.opacity ?? 1).clamp(0.0, 1.0).toDouble();
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
          child: Opacity(
            opacity: opacity,
            child: RotatedBox(quarterTurns: rotationTurns % 4, child: VideoPlayer(controller)),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStrip(CreationTimelineClip? selected) {
    return Container(
      height: 62,
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _project.timeline.length < 2 ? null : () => _movePrimaryClip(-1),
            color: Colors.white,
            disabledColor: Colors.white24,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Move clip left',
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _project.timeline.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, index) {
                final clip = _project.timeline[index];
                final selectedClip = selected?.clipId == clip.clipId;
                return GestureDetector(
                  onTap: () => _selectClip(clip),
                  child: Container(
                    width: 92,
                    decoration: BoxDecoration(
                      color: selectedClip ? Colors.white : const Color(0xFF292929),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selectedClip ? Colors.white : Colors.white12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Clip ${index + 1}\n${(clip.renderedDurationMs / 1000).toStringAsFixed(1)}s',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: selectedClip ? Colors.black : Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            onPressed: _project.timeline.length < 2 ? null : () => _movePrimaryClip(1),
            color: Colors.white,
            disabledColor: Colors.white24,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Move clip right',
          ),
        ],
      ),
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
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _ToolButton(icon: Icons.text_fields_rounded, label: 'Text', onTap: _openTextTool),
                      const SizedBox(width: 7),
                      _ToolButton(icon: Icons.music_note_rounded, label: 'Audio', onTap: _openAudioTool),
                      const SizedBox(width: 7),
                      _ToolButton(icon: Icons.auto_awesome_rounded, label: 'Effects', onTap: _openEffectsTool),
                      const SizedBox(width: 7),
                      _ToolButton(icon: Icons.tune_rounded, label: 'Adjust', onTap: _openAdjustTool),
                      const SizedBox(width: 7),
                      _ToolButton(icon: Icons.crop_rounded, label: 'Crop', onTap: _openCropTool),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          _buildTimelineStrip(clip),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(children: [
              if (_videoController?.value.isInitialized == true && clip != null) ...[
                Row(children: [const Text('Trim', style: TextStyle(fontWeight: FontWeight.w800)), const Spacer(), Text('${(_trimStart * 100).round()}% — ${(_trimEnd * 100).round()}%')]),
                RangeSlider(values: RangeValues(_trimStart, _trimEnd), onChanged: (value) => _setTrim(value.start, value.end)),
                Align(alignment: Alignment.centerLeft, child: Text('${clip.speed.toStringAsFixed(2)}×  •  ${clip.rotation.toStringAsFixed(0)}°  •  crop ${(clip.cropLeft * 100).round()}%/${(clip.cropTop * 100).round()}%/${(clip.cropRight * 100).round()}%/${(clip.cropBottom * 100).round()}%  •  v${_project.version}', style: const TextStyle(fontSize: 12, color: Colors.black54))),
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
  Widget build(BuildContext context) => Material(color: Colors.black54, borderRadius: BorderRadius.circular(14), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 19), const SizedBox(width: 5), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10))])));
}

class _ComposerTile extends StatelessWidget {
  const _ComposerTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));
}

class _CropSlider extends StatelessWidget {
  const _CropSlider({required this.label, required this.value, required this.onChanged});
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 58, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Slider(value: value, min: 0, max: 0.45, divisions: 45, label: '${(value * 100).round()}%', onChanged: onChanged)),
        SizedBox(width: 44, child: Text('${(value * 100).round()}%', textAlign: TextAlign.end)),
      ],
    );
  }
}
