import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/reel_model.dart';
import 'create_screen.dart';

class AudioReelsScreen extends StatefulWidget {
  const AudioReelsScreen({
    super.key,
    required this.audioTrackId,
    required this.creatorName,
  });

  final String audioTrackId;
  final String creatorName;

  @override
  State<AudioReelsScreen> createState() => _AudioReelsScreenState();
}

class _AudioReelsScreenState extends State<AudioReelsScreen> {
  late final Future<List<ReelModel>> _reelsFuture = _loadAudioReels();

  Future<List<ReelModel>> _loadAudioReels() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('reels')
        .where('audioTrackId', isEqualTo: widget.audioTrackId)
        .limit(60)
        .get();
    return snapshot.docs.map(ReelModel.fromFirestore).toList(growable: false);
  }

  void _useAudio() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateScreen(audioTrackId: widget.audioTrackId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07090B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Audio',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    FutureBuilder<List<ReelModel>>(
                      future: _reelsFuture,
                      builder: (context, snapshot) {
                        final cover = snapshot.data?.isNotEmpty == true
                            ? snapshot.data!.first.thumbnailUrl
                            : '';
                        return Container(
                          width: 78,
                          height: 78,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E242C),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFF5B942),
                              width: 1.2,
                            ),
                          ),
                          child: cover.isNotEmpty
                              ? Image.network(
                                  cover,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.music_note_rounded,
                                          color: Color(0xFFF5B942), size: 36),
                                )
                              : const Icon(
                                  Icons.music_note_rounded,
                                  color: Color(0xFFF5B942),
                                  size: 36,
                                ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.audioTrackId.isEmpty
                                ? 'Original Audio'
                                : widget.audioTrackId,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Original by ${widget.creatorName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Expanded(
                child: FutureBuilder<List<ReelModel>>(
                  future: _reelsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Unable to load reels for this audio.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    final reels = snapshot.data ?? const <ReelModel>[];
                    if (reels.isEmpty) {
                      return const Center(
                        child: Text(
                          'No reels have used this audio yet.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(2, 8, 2, 90),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: reels.length,
                      itemBuilder: (context, index) {
                        final reel = reels[index];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: const Color(0xFF161B22)),
                            if (reel.thumbnailUrl.isNotEmpty)
                              Image.network(
                                reel.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              ),
                            Positioned(
                              left: 6,
                              right: 6,
                              bottom: 6,
                              child: Row(
                                children: [
                                  const Icon(Icons.play_arrow_rounded,
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${reel.views}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5B942),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _useAudio,
                  icon: const Icon(Icons.music_note_rounded),
                  label: const Text(
                    'Use this Audio',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
