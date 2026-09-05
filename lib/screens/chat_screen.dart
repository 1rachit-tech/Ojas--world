import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientAvatar,
  });

  final String conversationId;
  final String recipientId;
  final String recipientName;
  final String recipientAvatar;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();
  bool _sending = false;
  bool _uploadingImage = false;
  bool _markingRead = false;

  DocumentReference<Map<String, dynamic>> get _conversationRef =>
      _firestore.collection('conversations').doc(widget.conversationId);

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _conversationRef.collection('messages');

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
    String currentUserId,
  ) async {
    if (_markingRead) return;

    final unread = messages.where((doc) {
      final data = doc.data();
      final senderId = data['senderId'];
      if (senderId is! String || senderId == currentUserId) return false;

      final isRead = data['isRead'];
      if (isRead is bool) return !isRead;

      return data['status'] != 'seen';
    }).toList();

    if (unread.isEmpty) return;

    _markingRead = true;
    try {
      final batch = _firestore.batch();
      for (final doc in unread) {
        batch.update(doc.reference, {
          'status': 'seen',
        });
      }
      batch.update(_conversationRef, {
        'unreadCounts.$currentUserId': 0,
        'lastReadAtBy.$currentUserId': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (_) {
      // Read-state is non-critical; keep the chat usable on transient failures.
    } finally {
      _markingRead = false;
    }
  }

  Future<void> _sendMessage() async {
    final user = _auth.currentUser;
    final text = _messageController.text.trim();
    if (user == null || text.isEmpty || _sending || _uploadingImage) return;

    _messageController.clear();
    setState(() => _sending = true);

    try {
      await _messagesRef.add({
        'conversationId': widget.conversationId,
        'senderId': user.uid,
        'type': 'text',
        'text': text,
        'isDeleted': false,
        'status': 'sent',
        'reactions': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _conversationRef.update({
        'lastMessageText': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': user.uid,
        'unreadCounts.${widget.recipientId}': FieldValue.increment(1),
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _restoreDraft(text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to send message.')),
      );
    } catch (_) {
      if (!mounted) return;
      _restoreDraft(text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send message.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showImageSourcePicker() async {
    if (_sending || _uploadingImage || _auth.currentUser == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || source == null) return;
    await _pickAndSendImage(source);
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final user = _auth.currentUser;
    if (user == null || _sending || _uploadingImage) return;

    setState(() => _uploadingImage = true);

    try {
      final picked = await _imagePicker.pickImage(source: source);
      if (picked == null) return;

      final Uint8List? compressed =
          await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: 1080,
        minHeight: 1080,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      if (compressed == null || compressed.isEmpty) {
        throw const FormatException('Unable to compress image.');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath =
          'chat_media/${widget.conversationId}/$timestamp.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      final uploadTask = storageRef.putData(
        compressed,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      await uploadTask;
      final downloadUrl = await storageRef.getDownloadURL();

      await _messagesRef.add({
        'conversationId': widget.conversationId,
        'senderId': user.uid,
        'type': 'image',
        'mediaUrl': downloadUrl,
        'mediaStoragePath': storagePath,
        'mediaBytes': compressed.lengthInBytes,
        'text': '',
        'isDeleted': false,
        'status': 'sent',
        'reactions': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _conversationRef.update({
        'lastMessageText': '📷 Photo',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': user.uid,
        'unreadCounts.${widget.recipientId}': FieldValue.increment(1),
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to upload photo.')),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to prepare photo.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to upload photo.')),
      );
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _restoreDraft(String text) {
    _messageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate().toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _messageStatus(dynamic value) {
    return value is String ? value : 'sent';
  }

  Widget _statusIcon(Map<String, dynamic> data) {
    final status = _messageStatus(data['status']);
    final isRead = data['isRead'] is bool && data['isRead'] == true;
    final read = status == 'seen' || isRead;
    return Icon(
      read ? Icons.done_all_rounded : Icons.done_rounded,
      size: 13,
      color: read ? Colors.lightBlueAccent : Colors.white54,
    );
  }

  Widget _avatar() {
    final url = widget.recipientAvatar.trim();
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFFF3F4F6),
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    final initial = widget.recipientName.isEmpty
        ? 'O'
        : widget.recipientName.substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFF3F4F6),
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _textBubble(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String currentUserId,
  ) {
    final data = doc.data();
    final senderId = data['senderId'];
    final isMine = senderId is String && senderId == currentUserId;
    final text = data['text'] is String ? data['text'] as String : '';
    return _bubbleShell(
      isMine: isMine,
      time: _formatTime(data['createdAt']),
      status: isMine ? _statusIcon(data) : null,
      child: Text(
        text,
        style: TextStyle(
          color: isMine ? Colors.white : const Color(0xFF111827),
          fontSize: 15,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _videoBubble(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String currentUserId,
  ) {
    final data = doc.data();
    final senderId = data['senderId'];
    final isMine = senderId is String && senderId == currentUserId;
    final caption = data['text'] is String ? data['text'] as String : '';
    final mediaUrl = data['mediaUrl'] is String ? data['mediaUrl'] as String : '';
    final time = _formatTime(data['createdAt']);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF243447) : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (mediaUrl.isNotEmpty)
                      Image.network(
                        mediaUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF374151),
                        ),
                      )
                    else
                      const ColoredBox(color: Color(0xFF374151)),
                    const Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (caption.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isMine ? Colors.white : const Color(0xFF111827),
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ],
            if (time.isNotEmpty || isMine) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: TextStyle(
                        color: isMine ? Colors.white54 : const Color(0xFF6B7280),
                        fontSize: 10,
                      ),
                    ),
                  if (isMine) ...[
                    const SizedBox(width: 3),
                    _statusIcon(data),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openImagePreview(String mediaUrl) async {
    if (mediaUrl.trim().isEmpty || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              mediaUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 180,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageBubble(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String currentUserId,
  ) {
    final data = doc.data();
    final senderId = data['senderId'];
    final isMine = senderId is String && senderId == currentUserId;
    final mediaUrl = data['mediaUrl'] is String ? data['mediaUrl'] as String : '';
    final time = _formatTime(data['createdAt']);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF243447) : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Material(
                color: const Color(0xFFE5E7EB),
                child: InkWell(
                  onTap: mediaUrl.isEmpty
                      ? null
                      : () => _openImagePreview(mediaUrl),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: mediaUrl.isEmpty
                        ? const Center(
                            child: Icon(Icons.broken_image_outlined),
                          )
                        : Image.network(
                            mediaUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              );
                            },
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            if (time.isNotEmpty || isMine)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 6, 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (time.isNotEmpty)
                      Text(
                        time,
                        style: TextStyle(
                          color:
                              isMine ? Colors.white54 : const Color(0xFF6B7280),
                          fontSize: 10,
                        ),
                      ),
                    if (isMine) ...[
                      const SizedBox(width: 3),
                      _statusIcon(data),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bubbleShell({
    required bool isMine,
    required String time,
    required Widget child,
    Widget? status,
  }) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 7),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF243447) : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            child,
            if (time.isNotEmpty || status != null) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: TextStyle(
                        color: isMine ? Colors.white54 : const Color(0xFF6B7280),
                        fontSize: 10,
                      ),
                    ),
                  if (status != null) ...[
                    const SizedBox(width: 3),
                    status,
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String currentUserId,
  ) {
    final type = doc.data()['type'];
    if (type is String && type == 'image') {
      return _imageBubble(doc, currentUserId);
    }
    if (type is String && type == 'video') {
      return _videoBubble(doc, currentUserId);
    }
    return _textBubble(doc, currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            _avatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.recipientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Info',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat info coming soon.')),
              );
            },
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: currentUserId == null
                ? const Center(child: Text('Please sign in again.'))
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _messagesRef
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Unable to load this conversation.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }

                      final messages = snapshot.data?.docs ?? const [];
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _markMessagesAsRead(messages, currentUserId);
                        }
                      });

                      if (messages.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Start the conversation with a message.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) =>
                            _messageBubble(messages[index], currentUserId),
                      );
                    },
                  ),
          ),
          if (_uploadingImage)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Attach',
                    onPressed: (_sending || _uploadingImage)
                        ? null
                        : _showImageSourcePicker,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      onSubmitted: (_) {
                        if (!_sending && !_uploadingImage) _sendMessage();
                      },
                      decoration: InputDecoration(
                        hintText: 'Message…',
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Send',
                    onPressed:
                        (_sending || _uploadingImage) ? null : _sendMessage,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                    color: const Color(0xFF111827),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
