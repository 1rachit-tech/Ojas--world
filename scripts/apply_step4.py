from pathlib import Path

p=Path('lib/models/reel_model.dart'); s=p.read_text()
s=s.replace("    required this.createdAt,\n", "    required this.createdAt,\n    this.audioTrackId = '',\n")
s=s.replace("  final DateTime createdAt;\n", "  final DateTime createdAt;\n  final String audioTrackId;\n")
s=s.replace("      createdAt: _readDateTime(data['createdAt']),\n", "      createdAt: _readDateTime(data['createdAt']),\n      audioTrackId: data['audioTrackId'] as String? ?? '',\n")
s=s.replace("        'createdAt': Timestamp.fromDate(createdAt),\n", "        'createdAt': Timestamp.fromDate(createdAt),\n        'audioTrackId': audioTrackId,\n")
p.write_text(s)

p=Path('lib/models/ojs_video.dart'); s=p.read_text()
s=s.replace("    this.shopItemIds = const [],\n", "    this.shopItemIds = const [],\n    this.creatorId = '',\n    this.audioTrackId = '',\n")
s=s.replace("  final int avatarColor;\n", "  final int avatarColor;\n  final String creatorId;\n  final String audioTrackId;\n")
p.write_text(s)

p=Path('lib/services/engagement_service.dart'); s=p.read_text()
anchor="  Future<void> syncInteraction({\n"
insert="  Future<void> syncFollow({\n    required String creatorId,\n    required bool following,\n  }) async {\n    final uid = _auth.currentUser?.uid;\n    if (uid == null || uid.isEmpty || creatorId.trim().isEmpty || uid == creatorId) {\n      return;\n    }\n    final followingRef = _firestore.collection('users').doc(uid).collection('following').doc(creatorId);\n    final creatorRef = _firestore.collection('users').doc(creatorId);\n    final batch = _firestore.batch();\n    if (following) {\n      batch.set(followingRef, <String, dynamic>{'following': true, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));\n    } else {\n      batch.delete(followingRef);\n    }\n    batch.set(creatorRef, <String, dynamic>{'followersCount': FieldValue.increment(following ? 1 : -1)}, SetOptions(merge: true));\n    try { await batch.commit(); } catch (error) {\n      // ignore: avoid_print\n      print('OJAS follow sync failed: $error');\n    }\n  }\n\n"
if 'Future<void> syncFollow' not in s: s=s.replace(anchor,insert+anchor,1)
p.write_text(s)

p=Path('lib/screens/ojs_feed_screen.dart'); s=p.read_text()
if "../screens/audio_reels_screen.dart" not in s: s=s.replace("import '../services/video_engine_service.dart';\n", "import '../services/video_engine_service.dart';\nimport '../screens/audio_reels_screen.dart';\n")
s=s.replace("  final Set<String> _followedCreators = {'Rohan Mehta', 'Nia Okafor'};\n", "  final Set<String> _followedCreators = {'Rohan Mehta', 'Nia Okafor'};\n  final Set<String> _notInterestedReels = <String>{};\n")
s=s.replace("      shopItemIds: reel.shopItemIds,\n", "      shopItemIds: reel.shopItemIds,\n      creatorId: reel.creatorId,\n      audioTrackId: reel.audioTrackId,\n",1)
start=s.find("  void _toggleFollowCreator(String creator) {")
if start!=-1:
  end=s.find("  void _syncFollow(", start)
  s=s[:start]+s[end:]
# Replace not-interested method with an analyzer-clean implementation.
start=s.find("  void _markCurrentNotInterested() {")
if start!=-1:
  end=s.find("  void _showOptionsSheet()", start)
  replacement="""  void _markCurrentNotInterested() {\n    if (_forYouReels.isEmpty || _forYouVisibleIndex < 0 || _forYouVisibleIndex >= _forYouReels.length) {\n      return;\n    }\n    final reel = _forYouReels[_forYouVisibleIndex];\n    setState(() => _notInterestedReels.add(reel.id));\n    final marked = _notInterestedReels.contains(reel.id);\n    if (marked && _forYouController.hasClients && _forYouVisibleIndex < _forYouReels.length - 1) {\n      _forYouController.nextPage(duration: const Duration(milliseconds: 180), curve: Curves.easeOut);\n    }\n  }\n\n"""
  s=s[:start]+replacement+s[end:]
# Remove legacy filter method since menu is now options.
start=s.find("  void _showTopFeedFilters() {")
if start!=-1:
  end=s.find("  @override\n  Widget build", start)
  s=s[:start]+s[end:]
# Clean up the follow/audio/share wiring deterministically.
for text in [
"            onFollow: () => _toggleFollowCreator(video.creator),\n",
"          onFollow: () => _toggleFollowCreator(video.creator),\n",
"            onAudio: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AudioReelsScreen(audioTrackId: video.audioTrackId.isEmpty ? video.id : video.audioTrackId, creatorName: video.creator))),\n            onAudio: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AudioReelsScreen(audioTrackId: video.audioTrackId.isEmpty ? video.id : video.audioTrackId, creatorName: video.creator))),\n",
"          onAudio: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AudioReelsScreen(audioTrackId: video.audioTrackId.isEmpty ? video.id : video.audioTrackId, creatorName: video.creator))),\n          onAudio: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AudioReelsScreen(audioTrackId: video.audioTrackId.isEmpty ? video.id : video.audioTrackId, creatorName: video.creator))),\n",
]: s=s.replace(text,'')
# Follow/audio insertions: first and second OjsVideoPage blocks.
follow="            onFollow: () { final next = !_followedCreators.contains(video.creator); _syncFollow(video.creatorId, video.creator, next); },\n"
follow2="          onFollow: () { final next = !_followedCreators.contains(video.creator); _syncFollow(video.creatorId, video.creator, next); },\n"
audio="            onAudio: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AudioReelsScreen(audioTrackId: video.audioTrackId.isEmpty ? video.id : video.audioTrackId, creatorName: video.creator))),\n"
audio2="          onAudio: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AudioReelsScreen(audioTrackId: video.audioTrackId.isEmpty ? video.id : video.audioTrackId, creatorName: video.creator))),\n"
# insert before onShare occurrences using first/rfind
share="            onShare: () => ShareBottomSheet.show(\n"
pos=s.find(share)
if pos!=-1 and follow not in s: s=s[:pos]+follow+audio+s[pos:]
share2="          onShare: () => ShareBottomSheet.show(\n"
pos=s.rfind(share2)
if pos!=-1 and follow2 not in s: s=s[:pos]+follow2+audio2+s[pos:]
p.write_text(s)

p=Path('lib/widgets/ojs_video_page.dart'); s=p.read_text()
s=s.replace("  final VoidCallback? onSave;\n", "  final VoidCallback? onSave;\n  final VoidCallback? onAudio;\n")
s=s.replace("    this.onSave,\n", "    this.onSave,\n    this.onAudio,\n")
old="""                      if (!widget.isFollowing)\n                        Positioned(\n                          bottom: -6,\n                          child: GestureDetector(\n                            onTap: () {\n                              HapticFeedback.selectionClick();\n                              widget.onFollow();\n                            },\n                            child: Container(\n                              padding: const EdgeInsets.all(2),\n                              decoration: const BoxDecoration(\n                                color: Color(0xFFEF4444),\n                                shape: BoxShape.circle,\n                              ),\n                              child: const Icon(\n                                Icons.add_rounded,\n                                color: Colors.white,\n                                size: 13,\n                              ),\n                            ),\n                          ),\n                        ),\n"""
new="""                      Positioned(\n                        bottom: -6,\n                        child: GestureDetector(\n                          onTap: () { HapticFeedback.selectionClick(); widget.onFollow(); },\n                          child: AnimatedSwitcher(\n                            duration: const Duration(milliseconds: 180),\n                            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),\n                            child: Container(\n                              key: ValueKey<bool>(widget.isFollowing),\n                              padding: const EdgeInsets.all(2),\n                              decoration: BoxDecoration(color: widget.isFollowing ? const Color(0xFF22C55E) : const Color(0xFFEF4444), shape: BoxShape.circle),\n                              child: Icon(widget.isFollowing ? Icons.check_rounded : Icons.add_rounded, color: Colors.white, size: 13),\n                            ),\n                          ),\n                        ),\n                      ),\n"""
if old not in s: raise SystemExit('follow badge anchor missing')
s=s.replace(old,new,1)
s=s.replace("                    onTap: _openSoundHub,", "                    onTap: widget.onAudio ?? _openSoundHub,",1)
p.write_text(s)

p=Path('lib/widgets/share_bottom_sheet.dart'); s=p.read_text()
s=s.replace("import 'package:flutter/services.dart';\n", "import 'package:flutter/services.dart';\nimport 'package:flutter_cache_manager/flutter_cache_manager.dart';\n")
s=s.replace("{'name': 'Direct Message', 'icon': Icons.send_rounded, 'color': const Color(0xFF111827)},", "{'name': 'Send in Ojas', 'icon': Icons.send_rounded, 'color': const Color(0xFF111827)},")
s=s.replace("{'name': 'Save Video', 'icon': Icons.download_rounded},", "{'name': 'Save to Device', 'icon': Icons.download_rounded},")
s=s.replace("""        if (label == 'Copy Link') {\n          Clipboard.setData(ClipboardData(text: videoUrl));\n        }""", """        if (label == 'Copy Link') {\n          Clipboard.setData(ClipboardData(text: videoUrl));\n        }\n        if (label == 'Save to Device') {\n          DefaultCacheManager().downloadFile(videoUrl);\n        }\n        if (label == 'Send in Ojas') {\n          Clipboard.setData(ClipboardData(text: videoUrl));\n        }""")
s=s.replace("""                  label == 'Copy Link'\n                      ? 'Link copied to clipboard! 📋'\n                      : '$label executed!',""", """                  label == 'Copy Link'\n                      ? 'Link copied to clipboard! 📋'\n                      : label == 'Save to Device'\n                          ? 'Saved to local device cache ✅'\n                          : label == 'Send in Ojas'\n                              ? 'Ready to send in Ojas 💬'\n                              : '$label executed!',""")
p.write_text(s)

Path('lib/screens/audio_reels_screen.dart').write_text("""import 'package:flutter/material.dart';\n\nclass AudioReelsScreen extends StatelessWidget {\n  const AudioReelsScreen({super.key, required this.audioTrackId, required this.creatorName});\n\n  final String audioTrackId;\n  final String creatorName;\n\n  @override\n  Widget build(BuildContext context) {\n    return Scaffold(\n      backgroundColor: Colors.black,\n      appBar: AppBar(\n        backgroundColor: Colors.black,\n        foregroundColor: Colors.white,\n        elevation: 0,\n        title: const Text('Audio Reels', style: TextStyle(fontWeight: FontWeight.w800)),\n      ),\n      body: SafeArea(\n        child: Padding(\n          padding: const EdgeInsets.all(20),\n          child: Column(\n            crossAxisAlignment: CrossAxisAlignment.start,\n            children: [\n              Container(\n                width: double.infinity,\n                padding: const EdgeInsets.all(20),\n                decoration: BoxDecoration(color: const Color(0xFF13171D), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),\n                child: Row(children: [\n                  Container(width: 64, height: 64, decoration: const BoxDecoration(color: Color(0xFF222831), shape: BoxShape.circle), child: const Icon(Icons.music_note_rounded, color: Color(0xFFF5B942), size: 30)),\n                  const SizedBox(width: 14),\n                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                    const Text('Original Audio', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),\n                    const SizedBox(height: 5),\n                    Text('@$creatorName', style: const TextStyle(color: Colors.white60, fontSize: 13)),\n                    const SizedBox(height: 5),\n                    Text('Track: $audioTrackId', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),\n                  ])),\n                ]),\n              ),\n              const SizedBox(height: 28),\n              const Text('Reels using this audio', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),\n              const SizedBox(height: 12),\n              const Expanded(child: Center(child: Text('Audio-linked reels will appear here.', style: TextStyle(color: Colors.white38)))),\n            ],\n          ),\n        ),\n      ),\n    );\n  }\n}\n""", encoding='utf-8')
