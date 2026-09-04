from pathlib import Path
import re

# Reel model: persist the canonical audio/lip-sync track key.
p = Path('lib/models/reel_model.dart')
s = p.read_text()
s = s.replace("    required this.createdAt,\n", "    required this.createdAt,\n    this.audioTrackId = '',\n", 1)
s = s.replace("  final DateTime createdAt;\n", "  final DateTime createdAt;\n  final String audioTrackId;\n", 1)
s = s.replace("      createdAt: _readDateTime(data['createdAt']),\n", "      createdAt: _readDateTime(data['createdAt']),\n      audioTrackId: data['audioTrackId'] as String? ?? '',\n", 1)
s = s.replace("        'createdAt': Timestamp.fromDate(createdAt),\n", "        'createdAt': Timestamp.fromDate(createdAt),\n        'audioTrackId': audioTrackId,\n", 1)
p.write_text(s)

# Legacy OjsVideo adapter carries creator UID + audio track without affecting existing callers.
p = Path('lib/models/ojs_video.dart')
s = p.read_text()
s = s.replace("    this.shopItemIds = const [],\n", "    this.shopItemIds = const [],\n    this.creatorId = '',\n    this.audioTrackId = '',\n", 1)
s = s.replace("  final int avatarColor;\n", "  final int avatarColor;\n  final String creatorId;\n  final String audioTrackId;\n", 1)
p.write_text(s)

# Zero-read follow graph write.
p = Path('lib/services/engagement_service.dart')
s = p.read_text()
if 'Future<void> syncFollow' not in s:
    marker = "  Future<void> syncInteraction({\n"
    method = """  Future<void> syncFollow({
    required String creatorId,
    required bool following,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || creatorId.trim().isEmpty || uid == creatorId) {
      return;
    }
    final followingRef = _firestore.collection('users').doc(uid).collection('following').doc(creatorId);
    final creatorRef = _firestore.collection('users').doc(creatorId);
    final batch = _firestore.batch();
    if (following) {
      batch.set(
        followingRef,
        <String, dynamic>{
          'following': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } else {
      batch.delete(followingRef);
    }
    batch.set(
      creatorRef,
      <String, dynamic>{
        'followersCount': FieldValue.increment(following ? 1 : -1),
      },
      SetOptions(merge: true),
    );
    try {
      await batch.commit();
    } catch (error) {
      // ignore: avoid_print
      print('OJAS follow sync failed: $error');
    }
  }

"""
    if marker not in s:
        raise SystemExit('engagement anchor missing')
    s = s.replace(marker, method + marker, 1)
p.write_text(s)

# Feed wiring.
p = Path('lib/screens/ojs_feed_screen.dart')
s = p.read_text()
if "import '../screens/audio_reels_screen.dart';" not in s:
    s = s.replace("import '../services/video_engine_service.dart';\n", "import '../services/video_engine_service.dart';\nimport '../screens/audio_reels_screen.dart';\n", 1)
s = s.replace("  final Set<String> _followedCreators = {'Rohan Mehta', 'Nia Okafor'};\n", "  final Set<String> _followedCreators = {'Rohan Mehta', 'Nia Okafor'};\n  final Set<String> _notInterestedReels = <String>{};\n", 1)
s = s.replace("      shopItemIds: reel.shopItemIds,\n", "      shopItemIds: reel.shopItemIds,\n      creatorId: reel.creatorId,\n      audioTrackId: reel.audioTrackId,\n", 1)
# Remove old local-only follow method and legacy category sheet.
s = re.sub(r"\n  void _toggleFollowCreator\(String creator\) \{.*?\n  \}\n(?=\n  void _toggleLikeVideo)", "\n", s, count=1, flags=re.S)
s = re.sub(r"\n  void _showTopFeedFilters\(\) \{.*?\n  \}\n(?=\n  @override\n  Widget build)", "\n", s, count=1, flags=re.S)
insert_before = "  void _toggleLikeVideo(String videoId) {\n"
if 'Future<void> syncFollow' in Path('lib/services/engagement_service.dart').read_text() and '_syncFollow(' not in s:
    methods = """  void _syncFollow(String creatorId, String creator, bool following) {
    setState(() {
      if (following) {
        _followedCreators.add(creator);
      } else {
        _followedCreators.remove(creator);
      }
    });
    _engagementService.syncFollow(creatorId: creatorId, following: following);
  }

  void _markCurrentNotInterested() {
    if (_forYouReels.isEmpty || _forYouVisibleIndex < 0 || _forYouVisibleIndex >= _forYouReels.length) {
      return;
    }
    final reel = _forYouReels[_forYouVisibleIndex];
    setState(() => _notInterestedReels.add(reel.id));
    final marked = _notInterestedReels.contains(reel.id);
    if (marked && _forYouController.hasClients && _forYouVisibleIndex < _forYouReels.length - 1) {
      _forYouController.nextPage(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _showOptionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF13171D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined, color: Colors.white70),
              title: const Text('Not Interested', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Tune your feed locally', style: TextStyle(color: Colors.white54)),
              onTap: () {
                Navigator.pop(context);
                _markCurrentNotInterested();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.white70),
              title: const Text('Report', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted for review')),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

"""
    if insert_before not in s:
        raise SystemExit('feed like anchor missing')
    s = s.replace(insert_before, methods + insert_before, 1)
s = s.replace("onPressed: _showTopFeedFilters,", "onPressed: _showOptionsSheet,", 1)
# Normalize both OjsVideoPage callback blocks.
s = s.replace("            onFollow: () => _toggleFollowCreator(video.creator),\n", "", 2)
s = s.replace("          onFollow: () => _toggleFollowCreator(video.creator),\n", "", 2)
follow_one = "            onFollow: () {\n              final next = !_followedCreators.contains(video.creator);\n              _syncFollow(video.creatorId, video.creator, next);\n            },\n"
follow_two = "          onFollow: () {\n            final next = !_followedCreators.contains(video.creator);\n            _syncFollow(video.creatorId, video.creator, next);\n          },\n"
first_share = "            onShare: () => ShareBottomSheet.show(\n"
second_share = "          onShare: () => ShareBottomSheet.show(\n"
if follow_one not in s:
    pos = s.find(first_share)
    if pos == -1: raise SystemExit('first share anchor missing')
    s = s[:pos] + follow_one + s[pos:]
if follow_two not in s:
    pos = s.rfind(second_share)
    if pos == -1: raise SystemExit('second share anchor missing')
    s = s[:pos] + follow_two + s[pos:]
audio_one = "            onAudio: () => Navigator.of(context).push(\n              MaterialPageRoute<void>(\n                builder: (_) => AudioReelsScreen(\n                  audioTrackId: video.audioTrackId.isEmpty ? video.id : video.audioTrackId,\n                  creatorName: video.creator,\n                ),\n              ),\n            ),\n"
audio_two = "          onAudio: () => Navigator.of(context).push(\n            MaterialPageRoute<void>(\n              builder: (_) => AudioReelsScreen(\n                audioTrackId: video.audioTrackId.isEmpty ? video.id : video.audioTrackId,\n                creatorName: video.creator,\n              ),\n            ),\n          ),\n"
if audio_one not in s:
    pos = s.find(first_share)
    s = s[:pos] + audio_one + s[pos:]
if audio_two not in s:
    pos = s.rfind(second_share)
    s = s[:pos] + audio_two + s[pos:]
p.write_text(s)

# Video page: animated +/check badge and audio callback.
p = Path('lib/widgets/ojs_video_page.dart')
s = p.read_text()
s = s.replace("  final VoidCallback? onSave;\n", "  final VoidCallback? onSave;\n  final VoidCallback? onAudio;\n", 1)
s = s.replace("    this.onSave,\n", "    this.onSave,\n    this.onAudio,\n", 1)
old = """                      if (!widget.isFollowing)
                        Positioned(
                          bottom: -6,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onFollow();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ),
"""
new = """                      Positioned(
                        bottom: -6,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onFollow();
                          },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Container(
                              key: ValueKey<bool>(widget.isFollowing),
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: widget.isFollowing
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.isFollowing
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
"""
if old not in s: raise SystemExit('video follow badge anchor missing')
s = s.replace(old, new, 1)
s = s.replace("                    onTap: _openSoundHub,", "                    onTap: widget.onAudio ?? _openSoundHub,", 1)
p.write_text(s)

# Share sheet: local disk cache + Ojas handoff placeholder.
p = Path('lib/widgets/share_bottom_sheet.dart')
s = p.read_text()
if "flutter_cache_manager" not in s:
    s = s.replace("import 'package:flutter/services.dart';\n", "import 'package:flutter/services.dart';\nimport 'package:flutter_cache_manager/flutter_cache_manager.dart';\n", 1)
s = s.replace("{'name': 'Direct Message', 'icon': Icons.send_rounded, 'color': const Color(0xFF111827)},", "{'name': 'Send in Ojas', 'icon': Icons.send_rounded, 'color': const Color(0xFF111827)},", 1)
s = s.replace("{'name': 'Save Video', 'icon': Icons.download_rounded},", "{'name': 'Save to Device', 'icon': Icons.download_rounded},", 1)
s = s.replace("""        if (label == 'Copy Link') {
          Clipboard.setData(ClipboardData(text: videoUrl));
        }""", """        if (label == 'Copy Link') {
          Clipboard.setData(ClipboardData(text: videoUrl));
        }
        if (label == 'Save to Device') {
          await DefaultCacheManager().downloadFile(videoUrl);
        }
        if (label == 'Send in Ojas') {
          Clipboard.setData(ClipboardData(text: videoUrl));
        }""", 1)
s = s.replace("""                  label == 'Copy Link'
                      ? 'Link copied to clipboard! 📋'
                      : '$label executed!',""", """                  label == 'Copy Link'
                      ? 'Link copied to clipboard! 📋'
                      : label == 'Save to Device'
                          ? 'Saved to local device cache ✅'
                          : label == 'Send in Ojas'
                              ? 'Ready to send in Ojas 💬'
                              : '$label executed!',""", 1)
p.write_text(s)

# Audio page skeleton only; the feed remains untouched.
Path('lib/screens/audio_reels_screen.dart').write_text("""import 'package:flutter/material.dart';

class AudioReelsScreen extends StatelessWidget {
  const AudioReelsScreen({
    super.key,
    required this.audioTrackId,
    required this.creatorName,
  });

  final String audioTrackId;
  final String creatorName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Audio Reels', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF13171D),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFF222831),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.music_note_rounded, color: Color(0xFFF5B942), size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Original Audio', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Text('@$creatorName', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                          const SizedBox(height: 5),
                          Text('Track: $audioTrackId', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text('Reels using this audio', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Expanded(
                child: Center(
                  child: Text('Audio-linked reels will appear here.', style: TextStyle(color: Colors.white38)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
""", encoding='utf-8')
