import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../screens/create_screen.dart';
import '../models/creation_project.dart';
import '../services/creation_project_store.dart';
import 'creation_pipeline_editor_screen.dart';

class CreationHubScreen extends StatefulWidget {
  const CreationHubScreen({super.key});

  @override
  State<CreationHubScreen> createState() => _CreationHubScreenState();
}

class _CreationHubScreenState extends State<CreationHubScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;

  String get _ownerId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _openCamera() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CreateScreen()),
    );
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
      for (final selected in files) {
        final file = File(selected.path);
        final size = await file.length();
        final isVideo = _isVideoPath(selected.path);
        assets.add(
          CreationMediaAsset(
            assetId: '${DateTime.now().microsecondsSinceEpoch}_${assets.length}',
            localUri: selected.path,
            type: isVideo ? 'video' : 'image',
            mimeType: isVideo ? 'video/*' : 'image/*',
            sizeBytes: size,
          ),
        );
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
            endMs: asset.durationMs ?? 0,
          ),
        );
      }

      final project = CreationProject(
        projectId: projectId,
        ownerId: _ownerId,
        createdAt: now,
        updatedAt: now,
        creationType: CreationType.post,
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
    } catch (error) {
      _show('Unable to import media: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isVideoPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi');
  }

  Future<void> _openDrafts() async {
    if (_ownerId.isEmpty) {
      _show('Please sign in before opening drafts.');
      return;
    }
    final drafts = await CreationProjectStore.instance.list(ownerId: _ownerId);
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
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _EntryCard(
                    icon: Icons.videocam_rounded,
                    title: 'Camera',
                    subtitle: 'Record new media',
                    onTap: _openCamera,
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
                'Upload & publish',
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
              Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
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
                  Text(entry.value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
        'Media originals stay local. Project state is saved locally first. Heavy media processing can later be routed through the existing OJAS Azure architecture after its creation-media endpoint is verified. No new paid backend is enabled by this screen.',
        style: TextStyle(color: Color(0xFF78350F), fontSize: 12, height: 1.45),
      ),
    );
  }
}
