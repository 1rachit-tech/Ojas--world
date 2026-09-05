import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import 'main_navigation_screen.dart';

class PostCreationScreen extends StatefulWidget {
  const PostCreationScreen({
    super.key,
    required this.videoPath,
    required this.selectedShader,
  });

  final String videoPath;
  final String selectedShader;

  @override
  State<PostCreationScreen> createState() => _PostCreationScreenState();
}

class _PostCreationScreenState extends State<PostCreationScreen> {
  late final VideoPlayerController _videoController;
  late final Future<void> _compressionFuture;
  final TextEditingController _captionController = TextEditingController();

  bool _videoReady = false;
  bool _compressing = true;
  bool _publishing = false;
  String? _compressionPath;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(
      File(widget.videoPath),
    );
    _compressionFuture = _compressInBackground();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _videoController.initialize();
      await _videoController.setLooping(true);
      await _videoController.play();
      if (!mounted) return;
      setState(() {
        _videoReady = true;
      });
    } catch (error) {
      debugPrint('PostCreation video initialization failed: $error');
    }
  }

  Future<void> _compressInBackground() async {
    try {
      final info = await VideoCompress.compressVideo(
        widget.videoPath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      final path = info?.path;
      if (path == null || path.isEmpty) {
        throw StateError('Video compression returned no file.');
      }

      _compressionPath = path;
      debugPrint('Compressed video saved to: $path');
    } catch (error) {
      debugPrint('Video compression failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _compressing = false;
        });
      }
    }
  }

  ColorFilter? _shaderFilter() {
    switch (widget.selectedShader) {
      case '4K Ultra HDR':
        return const ColorFilter.matrix(<double>[
          1.12, 0.00, 0.00, 0.00, -0.06,
          0.00, 1.12, 0.00, 0.00, -0.06,
          0.00, 0.00, 1.12, 0.00, -0.06,
          0.00, 0.00, 0.00, 1.00, 0.00,
        ]);
      case '8K Hyper Clarity':
        return const ColorFilter.matrix(<double>[
          1.08, 0.00, 0.00, 0.00, 0.01,
          0.00, 1.04, 0.00, 0.00, 0.00,
          0.00, 0.00, 1.16, 0.00, 0.01,
          0.00, 0.00, 0.00, 1.00, 0.00,
        ]);
      default:
        return null;
    }
  }

  Future<void> _publishToOjas() async {
    if (_publishing || !_videoReady) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showPublishError('Please sign in again before posting.');
      return;
    }

    setState(() {
      _publishing = true;
    });

    try {
      await _compressionFuture;

      final compressedPath = _compressionPath;
      if (compressedPath == null || compressedPath.isEmpty) {
        throw StateError('Compressed video is not available.');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageReference = FirebaseStorage.instance
          .ref()
          .child('reels')
          .child(user.uid)
          .child('$timestamp.mp4');

      final uploadTask = await storageReference.putFile(
        File(compressedPath),
        SettableMetadata(contentType: 'video/mp4'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final reelReference =
          FirebaseFirestore.instance.collection('reels').doc();
      await reelReference.set(<String, dynamic>{
        'creatorId': user.uid,
        'videoUrl': downloadUrl,
        'hlsUrl': downloadUrl,
        'thumbnailUrl': '',
        'caption': _captionController.text.trim(),
        'shaderUsed': widget.selectedShader,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'likes': 0,
        'comments': 0,
        'saves': 0,
        'shares': 0,
        'views': 0,
        'watchTimeMs': 0,
        'completions': 0,
        'shopItemIds': const <String>[],
        'algorithmScore': 0.0,
        'audioTrackId': '',
        'mediaHash': '',
      });

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MainNavigationScreen(),
        ),
        (_) => false,
      );
    } catch (error) {
      debugPrint('OJAS publish failed: $error');
      _showPublishError(
        'Unable to post your video. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishing = false;
        });
      }
    }
  }

  void _showPublishError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _videoController.dispose();
    _captionController.dispose();
    VideoCompress.cancelCompression();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = _shaderFilter();
    final video = _videoReady
        ? VideoPlayer(_videoController)
        : const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _videoReady
                              ? _videoController.value.aspectRatio
                              : 9 / 16,
                          child: filter == null
                              ? video
                              : ColorFiltered(
                                  colorFilter: filter,
                                  child: video,
                                ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Text(
                              widget.selectedShader,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_compressing)
                        const Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF111111),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _captionController,
                        enabled: !_publishing,
                        maxLines: 3,
                        minLines: 1,
                        maxLength: 2200,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Write a caption…',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _videoReady &&
                                  !_publishing
                              ? _publishToOjas
                              : null,
                          icon: _publishing
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            _publishing
                                ? 'Posting…'
                                : 'Post to OJAS',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_publishing)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
