import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/reel_model.dart';
import '../../services/azure_media_playback_service.dart';
import '../services/published_show_edit_service.dart';
import 'creation_pipeline_editor_screen.dart';

class PublishedShowsScreen extends StatefulWidget {
  const PublishedShowsScreen({super.key});

  @override
  State<PublishedShowsScreen> createState() => _PublishedShowsScreenState();
}

class _PublishedShowsScreenState extends State<PublishedShowsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final AzureMediaPlaybackService _playback;
  late final PublishedShowEditService _editService;

  bool _loading = true;
  String? _error;
  final Set<String> _busyIds = <String>{};
  List<ReelModel> _shows = const <ReelModel>[];

  @override
  void initState() {
    super.initState();
    _playback = AzureMediaPlaybackService();
    _editService = PublishedShowEditService(playback: _playback);
    _load();
  }

  @override
  void dispose() {
    _editService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Please sign in before editing a Show.';
      });
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('reels')
          .where('creatorId', isEqualTo: user.uid)
          .limit(50)
          .get();

      final docs = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['deletedAt'] == null && data['moderationStatus'] != 'deleted';
      }).toList(growable: false);

      final models = docs.map(ReelModel.fromFirestore).toList(growable: true)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final hydrated = <ReelModel>[];
      for (var start = 0; start < models.length; start += 10) {
        final chunk = models.sublist(start, start + 10 > models.length ? models.length : start + 10);
        final assets = await _playback.resolvePlaybackAssets(chunk.map((show) => show.id));
        hydrated.addAll(
          chunk.map((show) {
            final secure = assets[show.id];
            if (secure == null) return show;
            return show.copyWith(
              thumbnailUrl: secure.thumbnailUrl ?? show.thumbnailUrl,
              hlsUrl: secure.playbackUrl,
            );
          }),
        );
      }

      if (!mounted) return;
      setState(() {
        _shows = hydrated;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load your published Shows.';
      });
      debugPrint('OJAS published Shows load failed: $error');
    }
  }

  Future<void> _openEditor(ReelModel show) async {
    if (_busyIds.contains(show.id)) return;
    setState(() => _busyIds.add(show.id));
    try {
      final project = await _editService.createProjectForEditing(show.id);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CreationPipelineEditorScreen(project: project),
        ),
      );
    } on PublishedShowEditException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the Show editor.')),
        );
      }
      debugPrint('OJAS published Show editor failed: $error');
    } finally {
      if (mounted) setState(() => _busyIds.remove(show.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Published Shows',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _shows.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        itemCount: _shows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final show = _shows[index];
                          final busy = _busyIds.contains(show.id);
                          return _PublishedShowCard(
                            show: show,
                            busy: busy,
                            onEdit: () => _openEditor(show),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _PublishedShowCard extends StatelessWidget {
  const _PublishedShowCard({
    required this.show,
    required this.busy,
    required this.onEdit,
  });

  final ReelModel show;
  final bool busy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 9 / 14,
            child: show.thumbnailUrl.isEmpty
                ? const ColoredBox(
                    color: Color(0xFF111827),
                    child: Center(
                      child: Icon(Icons.play_circle_outline_rounded, color: Colors.white54, size: 48),
                    ),
                  )
                : Image.network(
                    show.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFF111827),
                      child: Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 42),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  show.caption.isEmpty ? 'Untitled Show' : show.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_compact(show.views)} views • ${show.createdAt.toLocal()}',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.timeline_rounded),
                    label: Text(busy ? 'Preparing editor…' : 'Edit timeline'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_settings_rounded, size: 52, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text('No published Shows yet.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text(
              'Publish a Show first. It will appear here when its secure media is ready.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
