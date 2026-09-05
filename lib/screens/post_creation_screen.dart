import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

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
  final TextEditingController _captionController = TextEditingController();

  bool _videoReady = false;
  bool _compressing = true;
  String? _compressionPath;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(
      File(widget.videoPath),
    );
    _initializeVideo();
    _compressInBackground();
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
      if (path != null) {
        _compressionPath = path;
        debugPrint('Compressed video saved to: $path');
      }
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
      body: SafeArea(
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
                      onPressed: _videoReady && !_compressing
                          ? () {
                              debugPrint(
                                'Post to OJAS pending upload implementation. '
                                'Compressed path: $_compressionPath',
                              );
                            }
                          : null,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text(
                        'Post to OJAS',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
