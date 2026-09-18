import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/creation_project.dart';
import '../services/creation_project_store.dart';
import '../services/local_audio_picker_service.dart';
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
  int _selectedClipIndex = 0;
  int _previewRevision = 0;
  late final TextEditingController _captionController;
  double _trimStart = 0.0;
  double _trimEnd = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _project = widget.project;
    _captionController = TextEditingController(text: _project.caption);
    _prepareEditor();
  }


  Future<void> _prepareEditor() async {
    await _hydrateTimelineMetadata();
    await _initializeSelectedClip();
  }

  Future<void> _hydrateTimelineMetadata() async {
    if (_project.mediaAssets.isEmpty) return;

    final assets = List<CreationMediaAsset>.from(_project.mediaAssets);
    final timeline = List<CreationTimelineClip>.from(_project.timeline);

    for (var i = 0; i < assets.length; i++) {
      final asset = assets[i];

      if (asset.type == 'image') {
        final duration = asset.durationMs ?? 3000;
        assets[i] = asset.copyWith(
          durationMs: duration,
        );

        if (i < timeline.length) {
          final clip = timeline[i];
          final trimOut = clip.trimOutMs == null || clip.trimOutMs! <= 0
              ? duration
              : clip.trimOutMs!.clamp(1, duration);
          timeline[i] = clip.copyWith(
            startMs: clip.startMs,
            endMs: duration,
            trimInMs: 0,
            trimOutMs: trimOut,
          );
        }
        continue;
      }

      try {
        final controller =
            VideoPlayerController.file(File(asset.localUri));
        await controller.initialize();
        final duration = controller.value.duration.inMilliseconds;
        await controller.dispose();

        if (duration <= 0) continue;

        assets[i] = asset.copyWith(
          durationMs: duration,
        );

        if (i < timeline.length) {
          final clip = timeline[i];
          final trimIn = clip.trimInMs.clamp(0, duration);
          final trimOut = (clip.trimOutMs == null || clip.trimOutMs! <= trimIn)
              ? duration
              : clip.trimOutMs!.clamp(trimIn + 1, duration);
          timeline[i] = clip.copyWith(
            endMs: duration,
            trimInMs: trimIn,
            trimOutMs: trimOut,
          );
        }
      } catch (error) {
        debugPrint('OJAS metadata hydration failed for clip $i: $error');
      }
    }

    if (!mounted) return;
    setState(() {
      _project = _project.copyWith(
        mediaAssets: assets,
        timeline: timeline,
        updatedAt: DateTime.now(),
      );
      _previewRevision++;
    });

    await CreationProjectStore.instance.save(_project);
  }

  Future<void> _initializeSelectedClip() async {
    _videoController?.dispose();
    _videoController = null;

    if (_project.mediaAssets.isEmpty ||
        _selectedClipIndex >= _project.mediaAssets.length) {
      if (mounted) setState(() => _videoInitializing = false);
      return;
    }

    final asset = _project.mediaAssets[_selectedClipIndex];

    if (asset.type != 'video') {
      if (mounted) {
        setState(() {
          _videoInitializing = false;
          _videoError = false;
          _trimStart = 0.0;
          _trimEnd = 1.0;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _videoInitializing = true;
          _videoError = false;
        });
      }

      final controller =
          VideoPlayerController.file(File(asset.localUri));
      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(false);

      final durationMs = controller.value.duration.inMilliseconds;
      final timeline = List<CreationTimelineClip>.from(_project.timeline);

      if (_selectedClipIndex < timeline.length && durationMs > 0) {
        final current = timeline[_selectedClipIndex];
        final trimIn = current.trimInMs.clamp(0, durationMs);
        final trimOut =
            (current.trimOutMs == null || current.trimOutMs! <= trimIn)
                ? durationMs
                : current.trimOutMs!.clamp(trimIn + 1, durationMs);

        timeline[_selectedClipIndex] = current.copyWith(
          endMs: durationMs,
          trimInMs: trimIn,
          trimOutMs: trimOut,
        );

        _project = _project.copyWith(timeline: timeline);
        _trimStart = (trimIn / durationMs).clamp(0.0, 0.98).toDouble();
        _trimEnd =
            (trimOut / durationMs).clamp(_trimStart + 0.01, 1.0).toDouble();
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoInitializing = false;
        _videoError = false;
        _previewRevision++;
      });
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

  Future<void> _selectClip(int index) async {
    if (_exporting || index < 0 || index >= _project.mediaAssets.length) {
      return;
    }

    setState(() {
      _selectedClipIndex = index;
    });
    await _initializeSelectedClip();
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
    if (_saving || _exporting || _project.mediaAssets.isEmpty) return;

    final timeline = List<CreationTimelineClip>.from(_project.timeline);

    while (timeline.length < _project.mediaAssets.length) {
      final index = timeline.length;
      final asset = _project.mediaAssets[index];
      final duration = asset.durationMs ?? 3000;
      timeline.add(
        CreationTimelineClip(
          clipId: _project.projectId + '_clip_' + index.toString(),
          sourceId: asset.assetId,
          startMs: 0,
          endMs: duration,
          trimInMs: 0,
          trimOutMs: duration,
        ),
      );
    }

    final selected = _selectedClipIndex < timeline.length
        ? timeline[_selectedClipIndex]
        : null;
    if (selected != null &&
        _videoController?.value.isInitialized == true &&
        _selectedClipIndex < _project.mediaAssets.length &&
        selected.sourceId ==
            _project.mediaAssets[_selectedClipIndex].assetId) {
      final durationMs = _videoController!.value.duration.inMilliseconds;
      if (durationMs > 0) {
        timeline[_selectedClipIndex] = selected.copyWith(
          endMs: durationMs,
          trimInMs: (durationMs * _trimStart).round(),
          trimOutMs: (durationMs * _trimEnd).round(),
        );
      }
    }

    final processingProject = _project.copyWith(
      status: CreationProjectStatus.processing,
      caption: _captionController.text.trim(),
      timeline: timeline,
      renderedUri: null,
      updatedAt: DateTime.now(),
    );

    await CreationProjectStore.instance.save(processingProject);
    if (!mounted) return;

    setState(() {
      _project = processingProject;
      _exporting = true;
      _cancelExportRequested = false;
      _exportProgress = 0.0;
    });

    try {
      final result = await VideoExportService.instance.exportComposition(
        project: processingProject.toMap(),
        projectId: processingProject.projectId,
        onProgress: (progress) {
          if (!mounted || !_exporting) return;
          setState(
            () => _exportProgress = progress.clamp(0.0, 1.0).toDouble(),
          );
        },
      );

      final finalAssets =
          List<CreationMediaAsset>.from(processingProject.mediaAssets);

      if (finalAssets.length == 1 && finalAssets.first.type == 'video') {
        finalAssets[0] = finalAssets.first.copyWith(
          normalizedUri: result.outputPath,
          sizeBytes: result.bytes,
        );
      }

      final readyProject = processingProject.copyWith(
        status: CreationProjectStatus.ready,
        mediaAssets: finalAssets,
        renderedUri: result.outputPath,
        updatedAt: DateTime.now(),
      );

      await CreationProjectStore.instance.save(readyProject);
      if (!mounted) return;

      setState(() {
        _project = readyProject;
        _exporting = false;
        _exportProgress = 1.0;
        _previewRevision++;
      });

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CreationPostComposerScreen(project: readyProject),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      final cancelled = _cancelExportRequested;
      final editingProject = _project.copyWith(
        status: CreationProjectStatus.editing,
        renderedUri: null,
        updatedAt: DateTime.now(),
      );

      await CreationProjectStore.instance.save(editingProject);

      setState(() {
        _project = editingProject;
        _exporting = false;
        _exportProgress = 0.0;
      });

      if (!cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is VideoExportException
                  ? error.message
                  : 'Local composition export failed.',
            ),
          ),
        );
      }
    } finally {
      _cancelExportRequested = false;
      if (mounted && _exporting) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _cancelExport() async {
    if (!_exporting) return;
    _cancelExportRequested = true;
    try {
      await VideoExportService.instance.cancelActiveExport();
    } catch (error) {
      debugPrint('OJAS export cancellation failed: $error');
    }
  }
  Future<void> _setTrim(double start, double end) async {
    final safeStart = start.clamp(0.0, 0.98).toDouble();
    final safeEnd = end.clamp(safeStart + 0.01, 1.0).toDouble();
    final controller = _videoController;
    final durationMs = controller?.value.duration.inMilliseconds ?? 0;
    setState(() {
      _trimStart = safeStart;
      _trimEnd = safeEnd;
      if (_selectedClipIndex < _project.timeline.length && durationMs > 0) {
        final timeline = List<CreationTimelineClip>.from(_project.timeline);
        timeline[_selectedClipIndex] = timeline[_selectedClipIndex].copyWith(
          startMs: 0,
          endMs: durationMs,
          trimInMs: (durationMs * safeStart).round(),
          trimOutMs: (durationMs * safeEnd).round(),
        );
        _project = _project.copyWith(
          timeline: timeline,
          renderedUri: null,
        );
        _previewRevision++;
      }
    });
    if (controller != null && controller.value.isInitialized) {
      await controller.seekTo(
        Duration(milliseconds: (durationMs * safeStart).round()),
      );
      await controller.pause();
    }
    _scheduleAutosave();
  }

  CreationTimelineClip get _selectedTimelineClip =>
      _project.timeline[_selectedClipIndex];

  Future<void> _setSelectedSpeed(double speed) async {
    if (_selectedClipIndex >= _project.timeline.length) return;
    final timeline = List<CreationTimelineClip>.from(_project.timeline);
    timeline[_selectedClipIndex] = timeline[_selectedClipIndex].copyWith(
      speed: speed.clamp(0.5, 2.0).toDouble(),
    );
    setState(() {
      _project = _project.copyWith(
        timeline: timeline,
        renderedUri: null,
        updatedAt: DateTime.now(),
      );
      _previewRevision++;
    });
    _scheduleAutosave();
  }

  void _rotateSelected() {
    if (_selectedClipIndex >= _project.timeline.length) return;
    final current = _project.timeline[_selectedClipIndex];
    final nextRotation = (current.rotation + 90) % 360;
    final timeline = List<CreationTimelineClip>.from(_project.timeline);
    timeline[_selectedClipIndex] = current.copyWith(rotation: nextRotation);
    setState(() {
      _project = _project.copyWith(
        timeline: timeline,
        renderedUri: null,
        updatedAt: DateTime.now(),
      );
      _previewRevision++;
    });
    _scheduleAutosave();
  }

  Future<void> _openScaleSheet() async {
    if (_selectedClipIndex >= _project.timeline.length) return;
    double scale = _selectedTimelineClip.scale;
    final result = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Scale',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Slider(
                    value: scale,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    label: scale.toStringAsFixed(2),
                    onChanged: (value) => setSheetState(() => scale = value),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, scale),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    final timeline = List<CreationTimelineClip>.from(_project.timeline);
    timeline[_selectedClipIndex] = timeline[_selectedClipIndex].copyWith(scale: result);
    setState(() {
      _project = _project.copyWith(
        timeline: timeline,
        renderedUri: null,
        updatedAt: DateTime.now(),
      );
      _previewRevision++;
    });
    _scheduleAutosave();
  }

  double _effectValue(String type) {
    for (final effect in _project.effectLayers.reversed) {
      if (effect['assetId'] == _project.mediaAssets[_selectedClipIndex].assetId &&
          effect['type'] == type) {
        return (effect['value'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return type == 'saturation' ? 0.0 : 0.0;
  }

  void _setEffect(String type, double value) {
    final assetId = _project.mediaAssets[_selectedClipIndex].assetId;
    final effects = <Map<String, dynamic>>[
      ..._project.effectLayers.where(
        (effect) => !(effect['assetId'] == assetId && effect['type'] == type),
      ),
    ];
    if ((type == 'grayscale' && value > 0.5) ||
        (type != 'grayscale' && value.abs() > 0.001)) {
      effects.add(<String, dynamic>{
        'assetId': assetId,
        'type': type,
        'value': value,
      });
    }
    setState(() {
      _project = _project.copyWith(
        effectLayers: effects,
        renderedUri: null,
        updatedAt: DateTime.now(),
      );
      _previewRevision++;
    });
  }

  Future<void> _openAdjustSheet() async {
    if (_project.mediaAssets.isEmpty) return;
    var brightness = _effectValue('brightness');
    var contrast = _effectValue('contrast');
    var saturation = _effectValue('saturation');
    var grayscale = _project.effectLayers.any(
      (effect) =>
          effect['assetId'] == _project.mediaAssets[_selectedClipIndex].assetId &&
          effect['type'] == 'grayscale',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Adjust',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _AdjustSlider(
                    label: 'Brightness',
                    value: brightness,
                    min: -1,
                    max: 1,
                    onChanged: (value) => setSheetState(() => brightness = value),
                  ),
                  _AdjustSlider(
                    label: 'Contrast',
                    value: contrast,
                    min: -1,
                    max: 1,
                    onChanged: (value) => setSheetState(() => contrast = value),
                  ),
                  _AdjustSlider(
                    label: 'Saturation',
                    value: saturation,
                    min: -100,
                    max: 100,
                    onChanged: (value) => setSheetState(() => saturation = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: grayscale,
                    title: const Text('Grayscale'),
                    onChanged: (value) => setSheetState(() => grayscale = value),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () {
                        _setEffect('brightness', brightness);
                        _setEffect('contrast', contrast);
                        _setEffect('saturation', saturation);
                        _setEffect('grayscale', grayscale ? 1 : 0);
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Apply adjustments'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    _scheduleAutosave();
  }

  Future<void> _openAudioPicker() async {
    try {
      final audio = await LocalAudioPickerService.instance.pickAudio();
      if (audio == null || !mounted) return;
      setState(() {
        _project = _project.copyWith(
          audio: <Map<String, dynamic>>[
            <String, dynamic>{
              'localUri': audio.path,
              'durationMs': audio.durationMs,
              'volume': 1.0,
              'startMs': 0,
            },
          ],
          renderedUri: null,
          updatedAt: DateTime.now(),
        );
        _previewRevision++;
      });
      _scheduleAutosave();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to import audio.')),
        );
      }
      debugPrint('OJAS audio picker failed: $error');
    }
  }

  Future<void> _moveClip(int from, int direction) async {
    final to = from + direction;
    if (from < 0 || from >= _project.mediaAssets.length ||
        to < 0 || to >= _project.mediaAssets.length) return;

    final assets = List<CreationMediaAsset>.from(_project.mediaAssets);
    final timeline = List<CreationTimelineClip>.from(_project.timeline);
    final asset = assets.removeAt(from);
    assets.insert(to, asset);
    if (from < timeline.length) {
      final clip = timeline.removeAt(from);
      timeline.insert(to, clip);
    }

    setState(() {
      _project = _project.copyWith(
        mediaAssets: assets,
        timeline: timeline,
        renderedUri: null,
        updatedAt: DateTime.now(),
      );
      _selectedClipIndex = to;
      _previewRevision++;
    });
    await _initializeSelectedClip();
    _scheduleAutosave();
  }

  Future<void> _deleteClip(int index) async {
    if (_project.mediaAssets.length <= 1 ||
        index < 0 || index >= _project.mediaAssets.length) return;
    final assets = List<CreationMediaAsset>.from(_project.mediaAssets)
      ..removeAt(index);
    final timeline = List<CreationTimelineClip>.from(_project.timeline)
      ..removeAt(index);
    final nextIndex = _selectedClipIndex >= assets.length
        ? assets.length - 1
        : _selectedClipIndex > index
            ? _selectedClipIndex - 1
            : _selectedClipIndex;
    setState(() {
      _project = _project.copyWith(
        mediaAssets: assets,
        timeline: timeline,
        renderedUri: null,
        updatedAt: DateTime.now(),
      );
      _selectedClipIndex = nextIndex;
      _previewRevision++;
    });
    await _initializeSelectedClip();
    _scheduleAutosave();
  }

  Widget _buildPreview() {
    if (_project.mediaAssets.isEmpty) {
      return const Center(
        child: Text('No media', style: TextStyle(color: Colors.white)),
      );
    }

    if (Theme.of(context).platform == TargetPlatform.android) {
      return AndroidView(
        key: ValueKey('composition_preview_$_previewRevision'),
        viewType: 'ojas/composition_preview',
        creationParams: _project.toMap(),
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    final asset = _project.mediaAssets[_selectedClipIndex];
    if (asset.type != 'video') {
      return Image.file(
        File(asset.localUri),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('Unable to load media', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    if (_videoInitializing) return const Center(child: CircularProgressIndicator());
    if (_videoError || _videoController == null || !_videoController!.value.isInitialized) {
      return const Center(child: Text('Unable to load video', style: TextStyle(color: Colors.white)));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio > 0
            ? _videoController!.value.aspectRatio
            : 9 / 16,
        child: VideoPlayer(_videoController!),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final canContinue =
        !_saving && !_exporting && _project.mediaAssets.isNotEmpty;
    final selectedVideoReady =
        _videoController?.value.isInitialized == true;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Edit · ${_project.mediaAssets.length} clip${_project.mediaAssets.length == 1 ? '' : 's'}',
        ),
        actions: [
          TextButton(
            onPressed: _saving || _exporting
                ? null
                : () => _saveProject(showFeedback: true),
            child: const Text(
              'Draft',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
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
                if (_exporting)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black87,
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 28),
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151515),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Rendering composition…',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: _exportProgress > 0
                                    ? _exportProgress
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${(_exportProgress * 100).round()}%',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: _cancelExport,
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.43,
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Timeline',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _project.audio.isNotEmpty
                              ? 'Music attached'
                              : 'No music',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 78,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _project.mediaAssets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final selected = index == _selectedClipIndex;
                          final asset = _project.mediaAssets[index];
                          final duration = index < _project.timeline.length
                              ? _project.timeline[index].trimOutMs
                                      != null &&
                                  _project.timeline[index].trimOutMs! >
                                      _project.timeline[index].trimInMs
                                  ? ((_project.timeline[index].trimOutMs! -
                                            _project.timeline[index].trimInMs) /
                                        1000)
                                  : (asset.durationMs ?? 0) / 1000
                              : (asset.durationMs ?? 0) / 1000;
                          return GestureDetector(
                            onTap: () => _selectClip(index),
                            child: Container(
                              width: 126,
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF111827)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF111827)
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        asset.type == 'image'
                                            ? Icons.image_outlined
                                            : Icons.movie_outlined,
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFF111827),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Clip ${index + 1}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: selected
                                                ? Colors.white
                                                : const Color(0xFF111827),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        duration.toStringAsFixed(1) + 's',
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white70
                                              : const Color(0xFF6B7280),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 24,
                                          minHeight: 24,
                                        ),
                                        onPressed: index > 0
                                            ? () => _moveClip(index, -1)
                                            : null,
                                        icon: const Icon(Icons.chevron_left_rounded),
                                        color: selected
                                            ? Colors.white70
                                            : const Color(0xFF6B7280),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 24,
                                          minHeight: 24,
                                        ),
                                        onPressed: index <
                                                _project.mediaAssets.length - 1
                                            ? () => _moveClip(index, 1)
                                            : null,
                                        icon: const Icon(Icons.chevron_right_rounded),
                                        color: selected
                                            ? Colors.white70
                                            : const Color(0xFF6B7280),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 24,
                                          minHeight: 24,
                                        ),
                                        onPressed: _project.mediaAssets.length > 1
                                            ? () => _deleteClip(index)
                                            : null,
                                        icon: const Icon(Icons.delete_outline_rounded),
                                        color: selected
                                            ? Colors.white70
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _EditorAction(
                          icon: Icons.speed_rounded,
                          label: '${_selectedTimelineClip.speed.toStringAsFixed(1)}x',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Colors.white,
                            builder: (sheetContext) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final speed in <double>[0.5, 1, 1.5, 2])
                                      ChoiceChip(
                                        label: Text('${speed}x'),
                                        selected:
                                            _selectedTimelineClip.speed == speed,
                                        onSelected: (_) {
                                          _setSelectedSpeed(speed);
                                          Navigator.pop(sheetContext);
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        _EditorAction(
                          icon: Icons.rotate_right_rounded,
                          label: '${_selectedTimelineClip.rotation.round()}°',
                          onTap: _rotateSelected,
                        ),
                        _EditorAction(
                          icon: Icons.zoom_in_map_rounded,
                          label: 'Scale',
                          onTap: _openScaleSheet,
                        ),
                        _EditorAction(
                          icon: Icons.tune_rounded,
                          label: 'Adjust',
                          onTap: _openAdjustSheet,
                        ),
                        _EditorAction(
                          icon: Icons.music_note_rounded,
                          label: _project.audio.isEmpty ? 'Audio' : 'Music ✓',
                          onTap: _openAudioPicker,
                        ),
                      ],
                    ),
                    if (selectedVideoReady) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Trim',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          Text(
                            '${(_trimStart * 100).round()}% — ${(_trimEnd * 100).round()}%',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      RangeSlider(
                        values: RangeValues(_trimStart, _trimEnd),
                        onChanged: (value) =>
                            _setTrim(value.start, value.end),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: _ComposerTile(
                            icon: Icons.subtitles_rounded,
                            title: _captionController.text.isEmpty
                                ? 'Caption'
                                : 'Caption added',
                            onTap: _openCaption,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ComposerTile(
                            icon: Icons.visibility_outlined,
                            title: _project.privacy,
                            onTap: _openPrivacy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: canContinue ? _openPostComposer : null,
                        icon: const Icon(Icons.movie_creation_rounded),
                        label: Text(
                          _project.renderedUri != null
                              ? 'Re-render & Continue'
                              : 'Render & Continue',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

class _AdjustSlider extends StatelessWidget {
  const _AdjustSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              value.toStringAsFixed(1),
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _EditorAction extends StatelessWidget {
  const _EditorAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: const Color(0xFF111827)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
