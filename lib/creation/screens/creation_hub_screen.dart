import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/creation_project.dart';
import '../services/creation_checkpoint_store.dart';
import '../services/creation_project_store.dart';
import '../services/creation_publish_recovery_service.dart';
import 'creation_pipeline_editor_screen.dart';
import 'published_shows_screen.dart';

class CreationHubScreen extends StatefulWidget {
  const CreationHubScreen({super.key});

  @override
  State<CreationHubScreen> createState() => _CreationHubScreenState();
}

class _CreationHubScreenState extends State<CreationHubScreen> {
  final ImagePicker _picker = ImagePicker();
  final CreationPublishRecoveryService _recovery =
      const CreationPublishRecoveryService();

  bool _loading = false;
  bool _recovering = false;
  List<CreationPublishRecoveryItem> _recoveryItems =
      const <CreationPublishRecoveryItem>[];

  String get _ownerId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadRecovery();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRecovery();
  }

  Future<void> _loadRecovery() async {
    final ownerId = _ownerId;
    if (ownerId.isEmpty) {
      if (mounted) setState(() => _recoveryItems = const <CreationPublishRecoveryItem>[]);
      return;
    }
    try {
      final items = await _recovery.list(ownerId: ownerId);
      if (!mounted) return;
      setState(() => _recoveryItems = items.take(3).toList(growable: false));
    } catch (error) {
      debugPrint('OJAS publish recovery scan failed: $error');
    }
  }

  Future<void> _openCamera() async {
    if (_ownerId.isEmpty) {
      _show('Please sign in before creating content.');
      return;
    }
    final video = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 15),
    );
    if (video == null || !mounted) return;
    await _openVideoProject(video);
  }

  Future<void> _pickMedia({bool multi = false}) async {
    if (_ownerId.isEmpty) {
      _show('Please sign in before creating content.');
      return;
    }
    setState(() => _loading = true);
    try {
      final List<XFile> files;
      if (multi) {
        files = await _picker.pickMultipleMedia(imageQuality: 92);
      } else {
        final media = await _picker.pickMedia(imageQuality: 92);
        files = media == null ? <XFile>[] : <XFile>[media];
      }

      if (files.isEmpty || !mounted) return;

      final assets = <CreationMediaAsset>[];
      for (var index = 0; index < files.length; index++) {
        final selected = files[index];
        assets.add(await _buildAsset(selected, index));
      }

      final projectId = '${_ownerId}_${DateTime.now().microsecondsSinceEpoch}';
      final now = DateTime.now();
      final timeline = <CreationTimelineClip>[];
      for (var index = 0; index < assets.length; index++) {
        final asset = assets[index];
        timeline.add(
          CreationTimelineClip(
            clipId: '${projectId}_clip_$index',
            sourceId: asset.assetId,
            startMs: 0,
            endMs: (asset.durationMs ?? 1000).clamp(1, 900000).toInt(),
          ),
        );
      }

      final project = CreationProject(
        projectId: projectId,
        ownerId: _ownerId,
        createdAt: now,
        updatedAt: now,
        creationType: assets.length == 1 && assets.first.type == 'video'
            ? CreationType.show
            : CreationType.post,
        status: CreationProjectStatus.editing,
        mediaAssets: assets,
        timeline: timeline,
      );

      await CreationProjectStore.instance.save(project);

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CreationPipelineEditorScreen(project: project),
        ),
      );
      await _loadRecovery();
    } catch (error) {
      _show('Unable to import media: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openVideoProject(XFile selected) async {
    final asset = await _buildAsset(selected, 0);
    final durationMs = (asset.durationMs ?? 1000).clamp(1, 900000).toInt();
    final projectId = '${_ownerId}_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final project = CreationProject(
      projectId: projectId,
      ownerId: _ownerId,
      createdAt: now,
      updatedAt: now,
      creationType: CreationType.show,
      status: CreationProjectStatus.editing,
      mediaAssets: <CreationMediaAsset>[asset.copyWithDuration(durationMs)],
      timeline: <CreationTimelineClip>[
        CreationTimelineClip(
          clipId: '${projectId}_clip_0',
          sourceId: asset.assetId,
          startMs: 0,
          endMs: durationMs,
        ),
      ],
    );
    await CreationProjectStore.instance.save(project);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CreationPipelineEditorScreen(project: project),
      ),
    );
    await _loadRecovery();
  }

  Future<CreationMediaAsset> _buildAsset(XFile selected, int index) async {
    final file = File(selected.path);
    if (!await file.exists()) {
      throw const FileSystemException('Selected media is no longer available.');
    }
    final size = await file.length();
    if (size <= 0) {
      throw const FileSystemException('Selected media is empty.');
    }
    final isVideo = _isVideoPath(selected.path);
    int? durationMs;
    if (isVideo) {
      final controller = VideoPlayerController.file(file);
      try {
        await controller.initialize();
        durationMs = controller.value.duration.inMilliseconds;
      } finally {
        await controller.dispose();
      }
    }

    return CreationMediaAsset(
      assetId: '${DateTime.now().microsecondsSinceEpoch}_$index',
      localUri: selected.path,
      type: isVideo ? 'video' : 'image',
      mimeType: isVideo ? 'video/mp4' : 'image/*',
      sizeBytes: size,
      durationMs: durationMs,
    );
  }

  bool _isVideoPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi');
  }

  Future<void> _resumePublish(CreationPublishRecoveryItem item) async {
    if (_recovering) return;
    setState(() => _recovering = true);
    try {
      final result = await _recovery.resume(item);
      if (!mounted) return;
      final message = result.isProcessing
          ? 'Upload recovered. OJAS is processing the Show.'
          : 'Publishing recovered successfully.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _loadRecovery();
    } catch (error) {
      if (!mounted) return;
      final message = error is CreationPublishException
          ? error.message
          : 'Could not resume this publish: $error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _loadRecovery();
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  Future<void> _openDrafts() async {
    if (_ownerId.isEmpty) {
      _show('Please sign in before opening drafts.');
      return;
    }

    final primaryDrafts = await CreationProjectStore.instance.list(ownerId: _ownerId);
    final checkpoints = await CreationCheckpointStore.instance.listLatest(ownerId: _ownerId);
    final byProjectId = <String, CreationProject>{
      for (final project in primaryDrafts) project.projectId: project,
    };
    for (final checkpoint in checkpoints) {
      final primary = byProjectId[checkpoint.projectId];
      if (primary == null || checkpoint.updatedAt.isAfter(primary.updatedAt)) {
        byProjectId[checkpoint.projectId] = checkpoint;
      }
    }
    final drafts = byProjectId.values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Drafts',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: drafts.isEmpty
                      ? const Center(child: Text('No saved projects yet.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(18),
                          itemCount: drafts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final project = drafts[index];
                            final asset = project.mediaAssets.isEmpty
                                ? null
                                : project.mediaAssets.first;
                            return ListTile(
                              tileColor: const Color(0xFFF7F7F8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              leading: const Icon(Icons.edit_note_rounded),
                              title: Text(
                                project.caption.isEmpty ? 'Untitled project' : project.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${project.status.name} • ${project.mediaAssets.length} asset(s) • ${asset?.type ?? 'media'}',
                              ),
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                if (!mounted) return;
                                await Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => CreationPipelineEditorScreen(project: project),
                                  ),
                                );
                                await _loadRecovery();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPublishedShows() async {
    if (_ownerId.isEmpty) {
      _show('Please sign in before opening published Shows.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PublishedShowsScreen()),
    );
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            const Text(
              'Create',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.2),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create, edit and publish from one project pipeline.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.35),
            ),
            if (_recoveryItems.isNotEmpty) ...[
              const SizedBox(height: 18),
              _RecoveryCard(
                items: _recoveryItems,
                busy: _recovering,
                onResume: _resumePublish,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _EntryCard(
                    icon: Icons.videocam_rounded,
                    title: 'Camera',
                    subtitle: 'Record directly into the production Show pipeline',
                    onTap: _loading ? null : _openCamera,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _EntryCard(
                    icon: Icons.photo_library_rounded,
                    title: 'Gallery',
                    subtitle: 'Choose media',
                    onTap: _loading ? null : () => _pickMedia(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _EntryCard(
                    icon: Icons.dashboard_customize_rounded,
                    title: 'Drafts',
                    subtitle: 'Resume a project',
                    onTap: _openDrafts,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _EntryCard(
                    icon: Icons.library_add_rounded,
                    title: 'Import',
                    subtitle: 'Multiple media',
                    onTap: _loading ? null : () => _pickMedia(multi: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EntryCard(
              icon: Icons.video_settings_rounded,
              title: 'Published Shows',
              subtitle: 'Re-edit and replace your published Show through the secure timeline pipeline',
              onTap: _openPublishedShows,
            ),
            const SizedBox(height: 22),
            _PipelineCard(
              title: 'Creation Pipeline',
              steps: const [
                'Media ingestion',
                'Project / draft',
                'Editing',
                'Preview',
                'Post composition',
                'Privacy & safety',
                'Device preparation',
                'Resumable upload & publish',
                'Server validation, render & moderation',
                'Secure Home / Show playback',
              ],
            ),
            const SizedBox(height: 14),
            const _ArchitectureNote(),
          ],
        ),
      ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({
    required this.items,
    required this.busy,
    required this.onResume,
  });

  final List<CreationPublishRecoveryItem> items;
  final bool busy;
  final Future<void> Function(CreationPublishRecoveryItem item) onResume;

  @override
  Widget build(BuildContext context) {
    final item = items.first;
    final percent = (item.progress * 100).round().clamp(0, 100);
    final label = item.resumable
        ? 'Upload interrupted — $percent% ready to resume'
        : 'Publish needs attention — resume when ready';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sync_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Publish recovery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
          if (item.progress > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: item.progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white12,
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : () => onResume(item),
              icon: busy
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(busy ? 'Recovering…' : 'Resume publish'),
            ),
          ),
          if (items.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${items.length - 1} more publish task(s) need attention.', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 14),
          ...steps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.white12,
                    child: Text('${entry.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(entry.value, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchitectureNote extends StatelessWidget {
  const _ArchitectureNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Text(
        'Original gallery media stays local. The editor checkpoints project state locally. Device preparation happens before cloud upload. Upload resumes from confirmed Azure blocks after interruption. Server processing is used only when validation or a real edit requires it. No new paid backend is enabled by this screen.',
        style: TextStyle(color: Color(0xFF78350F), fontSize: 12, height: 1.45),
      ),
    );
  }
}

extension on CreationMediaAsset {
  CreationMediaAsset copyWithDuration(int durationMs) => CreationMediaAsset(
        assetId: assetId,
        localUri: localUri,
        type: type,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        width: width,
        height: height,
        durationMs: durationMs,
        creationTime: creationTime,
        orientation: orientation,
        normalizedUri: normalizedUri,
      );
}
