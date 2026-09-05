import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId, required this.recipientId, required this.recipientName, required this.recipientAvatar});
  final String conversationId;
  final String recipientId;
  final String recipientName;
  final String recipientAvatar;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _imagePicker = ImagePicker();
  final _recorder = AudioRecorder();
  bool _sending = false;
  bool _uploadingImage = false;
  bool _uploadingAudio = false;
  bool _markingRead = false;
  bool _recording = false;
  String? _replyId;
  String? _replyText;
  String? _replySender;

  DocumentReference<Map<String, dynamic>> get _conversationRef => _firestore.collection('conversations').doc(widget.conversationId);
  CollectionReference<Map<String, dynamic>> get _messagesRef => _conversationRef.collection('messages');

  @override
  void dispose() {
    if (_recording) unawaited(_recorder.stop());
    unawaited(_recorder.dispose());
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Map<String, dynamic> _replyFields() {
    if (_replyId == null || _replyText == null || _replySender == null) return {};
    return {'replyingToMessageId': _replyId, 'replyingToText': _replyText, 'replyingToSenderName': _replySender};
  }

  void _clearReply() {
    if (!mounted) return;
    setState(() { _replyId = null; _replyText = null; _replySender = null; });
  }

  String _replyPreviewText(Map<String, dynamic> data) {
    final text = data['text'];
    if (text is String && text.trim().isNotEmpty) return text.trim();
    switch (data['type']) {
      case 'image': return '📷 Photo';
      case 'video': return '🎬 Video';
      case 'audio': return '🎤 Voice note';
      default: return 'Message';
    }
  }

  void _replyTo(QueryDocumentSnapshot<Map<String, dynamic>> doc, String currentUserId) {
    final data = doc.data();
    final text = _replyPreviewText(data);
    if (text.isEmpty) return;
    final senderId = data['senderId'];
    final sender = senderId is String && senderId == currentUserId ? 'You' : widget.recipientName;
    HapticFeedback.selectionClick();
    setState(() {
      _replyId = doc.id;
      _replyText = text;
      _replySender = sender.trim().isEmpty ? 'OJAS user' : sender.trim();
    });
    _messageFocusNode.requestFocus();
  }

  Future<void> _markMessagesAsRead(List<QueryDocumentSnapshot<Map<String, dynamic>>> messages, String uid) async {
    if (_markingRead) return;
    final unread = messages.where((doc) {
      final data = doc.data();
      final senderId = data['senderId'];
      if (senderId is! String || senderId == uid) return false;
      final isRead = data['isRead'];
      return isRead is bool ? !isRead : data['status'] != 'seen';
    }).toList();
    if (unread.isEmpty) return;
    _markingRead = true;
    try {
      final batch = _firestore.batch();
      for (final doc in unread) batch.update(doc.reference, {'status': 'seen'});
      batch.update(_conversationRef, {'unreadCounts.$uid': 0, 'lastReadAtBy.$uid': FieldValue.serverTimestamp()});
      await batch.commit();
    } catch (_) {
      // Non-critical; keep the conversation usable.
    } finally { _markingRead = false; }
  }

  Future<void> _sendMessage() async {
    final user = _auth.currentUser;
    final text = _messageController.text.trim();
    if (user == null || text.isEmpty || _sending || _uploadingImage || _uploadingAudio) return;
    _messageController.clear();
    setState(() => _sending = true);
    try {
      await _messagesRef.add({
        'conversationId': widget.conversationId, 'senderId': user.uid, 'type': 'text', 'text': text,
        'isDeleted': false, 'status': 'sent', 'reactions': <String, dynamic>{}, 'createdAt': FieldValue.serverTimestamp(), ..._replyFields(),
      });
      await _conversationRef.update({'lastMessageText': text, 'lastMessageAt': FieldValue.serverTimestamp(), 'lastSenderId': user.uid, 'unreadCounts.${widget.recipientId}': FieldValue.increment(1)});
      _clearReply();
    } on FirebaseException catch (e) {
      if (!mounted) return; _restoreDraft(text);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Unable to send message.')));
    } catch (_) {
      if (!mounted) return; _restoreDraft(text);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to send message.')));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _showImageSourcePicker() async {
    if (_sending || _uploadingImage || _uploadingAudio || _recording) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context, showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Gallery'), onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery)),
        ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Camera'), onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera)),
        const SizedBox(height: 8),
      ])),
    );
    if (mounted && source != null) await _pickAndSendImage(source);
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final user = _auth.currentUser;
    if (user == null || _sending || _uploadingImage || _uploadingAudio) return;
    setState(() => _uploadingImage = true);
    try {
      final picked = await _imagePicker.pickImage(source: source);
      if (picked == null) return;
      final compressed = await FlutterImageCompress.compressWithFile(picked.path, minWidth: 1080, minHeight: 1080, quality: 75, format: CompressFormat.jpeg);
      if (compressed == null || compressed.isEmpty) throw const FormatException('Unable to compress image.');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'chat_media/${widget.conversationId}/$timestamp.jpg';
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putData(compressed, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await _messagesRef.add({'conversationId': widget.conversationId, 'senderId': user.uid, 'type': 'image', 'mediaUrl': url, 'mediaStoragePath': path, 'mediaBytes': compressed.lengthInBytes, 'text': '', 'isDeleted': false, 'status': 'sent', 'reactions': <String, dynamic>{}, 'createdAt': FieldValue.serverTimestamp(), ..._replyFields()});
      await _conversationRef.update({'lastMessageText': '📷 Photo', 'lastMessageAt': FieldValue.serverTimestamp(), 'lastSenderId': user.uid, 'unreadCounts.${widget.recipientId}': FieldValue.increment(1)});
      _clearReply();
    } on FirebaseException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Unable to upload photo.')));
    } on FormatException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Unable to prepare photo.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to upload photo.')));
    } finally { if (mounted) setState(() => _uploadingImage = false); }
  }

  Future<void> _startRecording() async {
    if (_sending || _uploadingImage || _uploadingAudio || _recording) return;
    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted || !await _recorder.hasPermission()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission is required for voice notes.')));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/ojas_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000, sampleRate: 22050, numChannels: 1), path: path);
      if (!mounted) { unawaited(_recorder.stop()); return; }
      HapticFeedback.mediumImpact();
      setState(() => _recording = true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to start voice recording.')));
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    if (!_recording) return;
    setState(() => _recording = false);
    String? path;
    try { path = await _recorder.stop(); } catch (_) { return; }
    if (!send || path == null || path.isEmpty) return;
    await _uploadVoice(path);
  }

  Future<void> _uploadVoice(String localPath) async {
    final user = _auth.currentUser;
    final file = File(localPath);
    if (user == null || !await file.exists() || _sending || _uploadingAudio) return;
    setState(() => _uploadingAudio = true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'chat_media/audio/${widget.conversationId}/$timestamp.m4a';
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putFile(file, SettableMetadata(contentType: 'audio/mp4'));
      final url = await ref.getDownloadURL();
      await _messagesRef.add({'conversationId': widget.conversationId, 'senderId': user.uid, 'type': 'audio', 'mediaUrl': url, 'mediaStoragePath': storagePath, 'text': '', 'isDeleted': false, 'status': 'sent', 'reactions': <String, dynamic>{}, 'createdAt': FieldValue.serverTimestamp(), ..._replyFields()});
      await _conversationRef.update({'lastMessageText': '🎤 Voice note', 'lastMessageAt': FieldValue.serverTimestamp(), 'lastSenderId': user.uid, 'unreadCounts.${widget.recipientId}': FieldValue.increment(1)});
      _clearReply();
    } on FirebaseException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Unable to upload voice note.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to upload voice note.')));
    } finally {
      try { if (await file.exists()) await file.delete(); } catch (_) {}
      if (mounted) setState(() => _uploadingAudio = false);
    }
  }

  void _restoreDraft(String text) {
    _messageController.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate().toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _statusIcon(Map<String, dynamic> data) {
    final read = data['status'] == 'seen' || data['isRead'] == true;
    return Icon(read ? Icons.done_all_rounded : Icons.done_rounded, size: 13, color: read ? Colors.lightBlueAccent : Colors.white54);
  }

  Widget _replyQuote(Map<String, dynamic> data, bool mine) {
    final id = data['replyingToMessageId'];
    final text = data['replyingToText'];
    final sender = data['replyingToSenderName'];
    if (id is! String || id.isEmpty || text is! String || text.trim().isEmpty || sender is! String || sender.trim().isEmpty) return const SizedBox.shrink();
    final color = mine ? Colors.white54 : const Color(0xFF6B7280);
    return Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.fromLTRB(9, 6, 9, 6), decoration: BoxDecoration(color: mine ? Colors.white10 : Colors.black.withValues(alpha: .04), borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: mine ? Colors.white38 : const Color(0xFF9CA3AF), width: 3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(sender.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(text.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11))]));
  }

  Widget _bubbleShell({required bool mine, required String time, required Widget child, Widget? status}) {
    return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: const BoxConstraints(maxWidth: 320), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), padding: const EdgeInsets.fromLTRB(14, 10, 14, 7), decoration: BoxDecoration(color: mine ? const Color(0xFF243447) : const Color(0xFFE5E7EB), borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 4), bottomRight: Radius.circular(mine ? 4 : 18))), child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [child, if (time.isNotEmpty || status != null) ...[const SizedBox(height: 3), Row(mainAxisSize: MainAxisSize.min, children: [if (time.isNotEmpty) Text(time, style: TextStyle(color: mine ? Colors.white54 : const Color(0xFF6B7280), fontSize: 10)), if (status != null) ...[const SizedBox(width: 3), status!]])]]));
  }

  Widget _textBubble(QueryDocumentSnapshot<Map<String, dynamic>> doc, String uid) {
    final data = doc.data();
    final mine = data['senderId'] == uid;
    final text = data['text'] is String ? data['text'] as String : '';
    return _bubbleShell(mine: mine, time: _formatTime(data['createdAt']), status: mine ? _statusIcon(data) : null, child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [_replyQuote(data, mine), Text(text, style: TextStyle(color: mine ? Colors.white : const Color(0xFF111827), fontSize: 15, height: 1.35))]));
  }

  Future<void> _openImage(String url) async {
    if (!mounted || url.isEmpty) return;
    await showDialog<void>(context: context, barrierColor: Colors.black87, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: InteractiveViewer(minScale: .8, maxScale: 4, child: Image.network(url, fit: BoxFit.contain))));
  }

  Widget _imageBubble(QueryDocumentSnapshot<Map<String, dynamic>> doc, String uid) {
    final data = doc.data();
    final mine = data['senderId'] == uid;
    final url = data['mediaUrl'] is String ? data['mediaUrl'] as String : '';
    return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: const BoxConstraints(maxWidth: 280), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: mine ? const Color(0xFF243447) : const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(18)), child: Column(children: [Padding(padding: const EdgeInsets.all(4), child: _replyQuote(data, mine)), InkWell(onTap: url.isEmpty ? null : () => _openImage(url), child: AspectRatio(aspectRatio: 4 / 3, child: url.isEmpty ? const Center(child: Icon(Icons.broken_image_outlined)) : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined))))), Row(mainAxisSize: MainAxisSize.min, children: [Text(_formatTime(data['createdAt']), style: TextStyle(color: mine ? Colors.white54 : const Color(0xFF6B7280), fontSize: 10)), if (mine) ...[const SizedBox(width: 3), _statusIcon(data)]])])));
  }

  Widget _videoBubble(QueryDocumentSnapshot<Map<String, dynamic>> doc, String uid) {
    final data = doc.data();
    final mine = data['senderId'] == uid;
    final url = data['mediaUrl'] is String ? data['mediaUrl'] as String : '';
    final caption = data['text'] is String ? data['text'] as String : '';
    return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: const BoxConstraints(maxWidth: 280), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: mine ? const Color(0xFF243447) : const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(18)), child: Column(children: [_replyQuote(data, mine), ClipRRect(borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: 16 / 9, child: Stack(fit: StackFit.expand, children: [url.isEmpty ? const ColoredBox(color: Color(0xFF374151)) : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF374151))), const Center(child: DecoratedBox(decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28))))]))), if (caption.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(caption, maxLines: 3, overflow: TextOverflow.ellipsis)), const SizedBox(height: 3), Row(mainAxisSize: MainAxisSize.min, children: [Text(_formatTime(data['createdAt']), style: TextStyle(color: mine ? Colors.white54 : const Color(0xFF6B7280), fontSize: 10)), if (mine) ...[const SizedBox(width: 3), _statusIcon(data)]])])));
  }

  Widget _audioBubble(QueryDocumentSnapshot<Map<String, dynamic>> doc, String uid) {
    final data = doc.data();
    final mine = data['senderId'] == uid;
    return _AudioBubble(mediaUrl: data['mediaUrl'] is String ? data['mediaUrl'] as String : '', isMine: mine, time: _formatTime(data['createdAt']), status: mine ? _statusIcon(data) : null, reply: _replyQuote(data, mine));
  }

  Widget _messageBubble(QueryDocumentSnapshot<Map<String, dynamic>> doc, String uid) {
    switch (doc.data()['type']) { case 'image': return _imageBubble(doc, uid); case 'video': return _videoBubble(doc, uid); case 'audio': return _audioBubble(doc, uid); default: return _textBubble(doc, uid); }
  }

  Widget _headerAvatar() {
    final url = widget.recipientAvatar.trim();
    if (url.isNotEmpty) return CircleAvatar(radius: 18, backgroundImage: NetworkImage(url), backgroundColor: const Color(0xFFF3F4F6));
    final initial = widget.recipientName.isEmpty ? 'O' : widget.recipientName.substring(0, 1).toUpperCase();
    return CircleAvatar(radius: 18, backgroundColor: const Color(0xFFF3F4F6), child: Text(initial, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w800)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    final inputEmpty = _messageController.text.trim().isEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: const Color(0xFF111827), surfaceTintColor: Colors.transparent, elevation: 0, titleSpacing: 0, title: Row(children: [_headerAvatar(), const SizedBox(width: 10), Expanded(child: Text(widget.recipientName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))]), actions: [IconButton(tooltip: 'Info', onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat info coming soon.'))), icon: const Icon(Icons.info_outline_rounded))]),
      body: Column(children: [
        Expanded(child: uid == null ? const Center(child: Text('Please sign in again.')) : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: _messagesRef.orderBy('createdAt', descending: true).snapshots(), builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Unable to load this conversation.', textAlign: TextAlign.center)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          final messages = snapshot.data?.docs ?? const [];
          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _markMessagesAsRead(messages, uid); });
          if (messages.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Start the conversation with a message.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280)))));
          return ListView.builder(reverse: true, padding: const EdgeInsets.symmetric(vertical: 12), itemCount: messages.length, itemBuilder: (context, index) { final doc = messages[index]; return _SwipeReply(key: ValueKey(doc.id), onReply: () => _replyTo(doc, uid), child: _messageBubble(doc, uid)); });
        })),
        if (_uploadingImage || _uploadingAudio) const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: LinearProgressIndicator(minHeight: 2)),
        if (_recording) Container(width: double.infinity, color: const Color(0xFFF9FAFB), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [const Icon(Icons.mic_rounded, color: Color(0xFFDC2626), size: 18), const SizedBox(width: 8), const Expanded(child: Text('Recording… release to send', style: TextStyle(fontWeight: FontWeight.w700))), TextButton(onPressed: () => _stopRecording(send: false), child: const Text('Cancel'))])),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), child: Column(children: [
          if (_replyId != null) _ReplyComposer(sender: _replySender ?? 'OJAS user', text: _replyText ?? 'Message', onCancel: _clearReply),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IconButton(tooltip: 'Attach', onPressed: (_sending || _uploadingImage || _uploadingAudio || _recording) ? null : _showImageSourcePicker, icon: const Icon(Icons.add_circle_outline_rounded)),
            Expanded(child: TextField(controller: _messageController, focusNode: _messageFocusNode, minLines: 1, maxLines: 5, textCapitalization: TextCapitalization.sentences, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: _recording ? 'Recording voice note…' : 'Message…', filled: true, fillColor: const Color(0xFFF3F4F6), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
            const SizedBox(width: 6),
            inputEmpty ? _VoiceButton(enabled: !_sending && !_uploadingImage && !_uploadingAudio, recording: _recording, onStart: _startRecording, onEnd: () => _stopRecording(send: true)) : IconButton(tooltip: 'Send', onPressed: (_sending || _uploadingImage || _uploadingAudio) ? null : _sendMessage, icon: _sending ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_upward_rounded), color: const Color(0xFF111827)),
          ]),
        ]))),
      ]),
    );
  }
}

class _SwipeReply extends StatelessWidget {
  const _SwipeReply({super.key, required this.child, required this.onReply});
  final Widget child; final VoidCallback onReply;
  @override Widget build(BuildContext context) => GestureDetector(behavior: HitTestBehavior.translucent, onHorizontalDragEnd: (details) { if ((details.primaryVelocity ?? 0).abs() >= 350) onReply(); }, child: child);
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({required this.sender, required this.text, required this.onCancel});
  final String sender; final String text; final VoidCallback onCancel;
  @override Widget build(BuildContext context) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.fromLTRB(12, 8, 6, 8), decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))), child: Row(children: [Container(width: 3, height: 34, decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(99))), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Replying to $sender…', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12))])), IconButton(tooltip: 'Cancel reply', onPressed: onCancel, icon: const Icon(Icons.close_rounded, size: 19))]));
}

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({required this.enabled, required this.recording, required this.onStart, required this.onEnd});
  final bool enabled; final bool recording; final Future<void> Function() onStart; final Future<void> Function() onEnd;
  @override Widget build(BuildContext context) => GestureDetector(onLongPressStart: enabled && !recording ? (_) => unawaited(onStart()) : null, onLongPressEnd: recording ? (_) => unawaited(onEnd()) : null, child: Tooltip(message: recording ? 'Release to send' : 'Hold to record', child: Container(width: 44, height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: enabled && !recording ? const Color(0xFF111827) : const Color(0xFF374151), shape: BoxShape.circle), child: const Icon(Icons.mic_rounded, color: Colors.white, size: 21))));
}

class _AudioBubble extends StatefulWidget {
  const _AudioBubble({required this.mediaUrl, required this.isMine, required this.time, required this.status, required this.reply});
  final String mediaUrl; final bool isMine; final String time; final Widget? status; final Widget reply;
  @override State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _state;
  StreamSubscription<Duration>? _duration;
  StreamSubscription<Duration>? _position;
  StreamSubscription<void>? _complete;
  PlayerState _playerState = PlayerState.stopped;
  Duration _total = Duration.zero;
  Duration _current = Duration.zero;
  @override void initState() {
    super.initState();
    _state = _player.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _playerState = s); });
    _duration = _player.onDurationChanged.listen((d) { if (mounted) setState(() => _total = d); });
    _position = _player.onPositionChanged.listen((p) { if (mounted) setState(() => _current = p > _total ? _total : p); });
    _complete = _player.onPlayerComplete.listen((_) { if (mounted) setState(() { _current = Duration.zero; _playerState = PlayerState.stopped; }); });
  }
  @override void dispose() { unawaited(_state?.cancel()); unawaited(_duration?.cancel()); unawaited(_position?.cancel()); unawaited(_complete?.cancel()); unawaited(_player.dispose()); super.dispose(); }
  Future<void> _toggle() async { if (widget.mediaUrl.trim().isEmpty) return; try { if (_playerState == PlayerState.playing) { await _player.pause(); } else { await _player.play(UrlSource(widget.mediaUrl.trim(), mimeType: 'audio/mp4')); } } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to play this voice note.'))); } }
  String _durationText(Duration value) { final s = value.inSeconds; return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'; }
  @override Widget build(BuildContext context) {
    final maxMs = _total.inMilliseconds; final value = _current.inMilliseconds.clamp(0, maxMs); final foreground = widget.isMine ? Colors.white : const Color(0xFF111827);
    return Align(alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: const BoxConstraints(maxWidth: 320), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), padding: const EdgeInsets.fromLTRB(10, 9, 10, 7), decoration: BoxDecoration(color: widget.isMine ? const Color(0xFF243447) : const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: widget.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [widget.reply, Row(children: [IconButton(onPressed: widget.mediaUrl.trim().isEmpty ? null : _toggle, icon: Icon(_playerState == PlayerState.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: foreground)), Expanded(child: Slider(value: value.toDouble(), min: 0, max: maxMs > 0 ? maxMs.toDouble() : 1, onChanged: maxMs > 0 ? (v) => _player.seek(Duration(milliseconds: v.round())) : null)), Text(_durationText(_total), style: TextStyle(color: widget.isMine ? Colors.white54 : const Color(0xFF6B7280), fontSize: 10))]), Row(mainAxisSize: MainAxisSize.min, children: [if (widget.time.isNotEmpty) Text(widget.time, style: TextStyle(color: widget.isMine ? Colors.white54 : const Color(0xFF6B7280), fontSize: 10)), if (widget.status != null) ...[const SizedBox(width: 3), widget.status!]])])));
  }
}
