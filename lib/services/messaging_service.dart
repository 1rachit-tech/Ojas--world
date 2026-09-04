import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../models/ojas_conversation.dart';
import '../models/ojas_message.dart';
import '../models/ojas_profile.dart';

class MessagingService extends WidgetsBindingObserver {
  MessagingService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final MessagingService instance = MessagingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Set<String> _activePresenceConversations = <String>{};
  DateTime _lastMessageAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastMessageFingerprint = '';
  int _repeatCount = 0;
  DateTime _repeatWindowStarted = DateTime.fromMillisecondsSinceEpoch(0);

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');
  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      _firestore.collection('publicProfiles');

  String? get currentUid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> conversationReference(String id) =>
      _conversations.doc(id);
  CollectionReference<Map<String, dynamic>> messageCollection(String id) =>
      conversationReference(id).collection('messages');

  String conversationIdFor(String firstUid, String secondUid) {
    final ids = <String>[firstUid, secondUid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<List<OjasConversation>> watchConversations() {
    final uid = currentUid;
    if (uid == null) return Stream.value(const <OjasConversation>[]);
    return _conversations
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(OjasConversation.fromFirestore).toList());
  }

  Stream<int> watchTotalUnreadCount() {
    final uid = currentUid;
    if (uid == null) return Stream.value(0);
    return watchConversations().map((conversations) {
      var total = 0;
      for (final conversation in conversations) total += conversation.unreadCountFor(uid);
      return total;
    });
  }

  Stream<List<OjasMessage>> watchMessages(String conversationId) {
    return messageCollection(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(OjasMessage.fromFirestore).toList());
  }

  Future<List<OjasProfile>> searchUsers(String query) async {
    final currentUserId = currentUid;
    if (currentUserId == null) return [];
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    final results = <String, OjasProfile>{};
    final idQuery = await _publicProfiles.orderBy('ojasId').startAt([normalized]).endAt(['$normalized\uf8ff']).limit(20).get();
    for (final document in idQuery.docs) {
      if (document.id != currentUserId) results[document.id] = OjasProfile.fromMap(document.data(), uid: document.id);
    }
    final cleanQuery = query.trim();
    final nameQuery = await _publicProfiles.orderBy('displayName').startAt([cleanQuery]).endAt(['$cleanQuery\uf8ff']).limit(20).get();
    for (final document in nameQuery.docs) {
      if (document.id != currentUserId) results[document.id] = OjasProfile.fromMap(document.data(), uid: document.id);
    }
    final users = results.values.toList();
    users.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return users;
  }

  Future<String> openConversation(OjasProfile otherUser) async {
    final uid = currentUid;
    if (uid == null) throw const MessagingException('Please sign in again.');
    if (otherUser.uid.isEmpty || otherUser.uid == uid) throw const MessagingException('Invalid OJAS user.');
    final currentProfile = await _getCurrentProfile(uid);
    final conversationId = conversationIdFor(uid, otherUser.uid);
    final reference = conversationReference(conversationId);
    final data = <String, dynamic>{
      'participants': [uid, otherUser.uid],
      'participantProfiles': {
        uid: _profileMap(currentProfile),
        otherUser.uid: _profileMap(otherUser),
      },
      'lastMessage': '',
      'lastMessageSenderId': '',
      'unreadCounts': {uid: 0, otherUser.uid: 0},
      'lastReadAtBy': {uid: FieldValue.serverTimestamp()},
      'typingBy': {uid: false, otherUser.uid: false},
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    };
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (!existing.exists) transaction.set(reference, data);
    });
    return conversationId;
  }

  Future<void> sendTextMessage({
    required String conversationId,
    required String receiverId,
    required String text,
    OjasMessage? replyTo,
  }) async {
    final uid = currentUid;
    if (uid == null) throw const MessagingException('Please sign in again.');
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    if (cleanText.length > 2000) throw const MessagingException('Messages can contain up to 2000 characters.');
    if (receiverId.isEmpty) throw const MessagingException('Invalid conversation.');
    _guardLocalSend(cleanText);
    final conversation = conversationReference(conversationId);
    final message = messageCollection(conversationId).doc();
    final batch = _firestore.batch();
    final messageData = <String, dynamic>{
      'conversationId': conversationId,
      'senderId': uid,
      'text': cleanText,
      'type': 'text',
      'isDeleted': false,
      'reactions': <String, String>{},
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (replyTo != null) {
      messageData.addAll({
        'replyToMessageId': replyTo.id,
        'replyToSenderId': replyTo.senderId,
        'replyToText': replyTo.isDeleted ? 'This message was deleted.' : replyTo.isImage ? 'Photo' : _safeReplyPreview(replyTo.text),
        'replyToType': replyTo.type,
      });
    }
    batch.set(message, messageData);
    batch.set(conversation, {
      'lastMessage': cleanText,
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCounts.$uid': 0,
      'lastReadAtBy.$uid': FieldValue.serverTimestamp(),
      'typingBy.$uid': false,
      'unreadCounts.$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> sendImageMessage({
    required String conversationId,
    required String receiverId,
    required String mediaUrl,
    required String storagePath,
    required int width,
    required int height,
    required int mediaBytes,
    String? caption,
    OjasMessage? replyTo,
  }) async {
    final uid = currentUid;
    if (uid == null) throw const MessagingException('Please sign in again.');
    if (receiverId.isEmpty || mediaUrl.trim().isEmpty) throw const MessagingException('Invalid conversation.');
    if (mediaBytes <= 0 || mediaBytes > 10 * 1024 * 1024) throw const MessagingException('Image is too large.');
    final conversation = conversationReference(conversationId);
    final message = messageCollection(conversationId).doc();
    final batch = _firestore.batch();
    final cleanCaption = caption?.trim() ?? '';
    batch.set(message, {
      'conversationId': conversationId,
      'senderId': uid,
      'text': cleanCaption,
      'type': 'image',
      'mediaUrl': mediaUrl,
      'mediaStoragePath': storagePath,
      'mediaWidth': width,
      'mediaHeight': height,
      'isDeleted': false,
      'reactions': <String, String>{},
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(conversation, {
      'lastMessage': cleanCaption.isEmpty ? 'Photo' : cleanCaption,
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCounts.$uid': 0,
      'lastReadAtBy.$uid': FieldValue.serverTimestamp(),
      'typingBy.$uid': false,
      'unreadCounts.$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> setTyping({required String conversationId, required bool isTyping}) async {
    final uid = currentUid;
    if (uid == null) return;
    await conversationReference(conversationId).set({'typingBy.$uid': isTyping}, SetOptions(merge: true));
  }

  Future<void> markConversationRead(String conversationId) async {
    final uid = currentUid;
    if (uid == null) return;
    await conversationReference(conversationId).set({
      'unreadCounts.$uid': 0,
      'lastReadAtBy.$uid': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void registerPresenceConversation(String conversationId) {
    if (conversationId.trim().isNotEmpty) _activePresenceConversations.add(conversationId);
  }
  void unregisterPresenceConversation(String conversationId) => _activePresenceConversations.remove(conversationId);
  Future<void> setPresence({required String conversationId, required bool isOnline}) async {}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Future<OjasProfile> _getCurrentProfile(String uid) async {
    final snapshot = await _publicProfiles.doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) throw const MessagingException('Your profile is not ready yet.');
    return OjasProfile.fromMap(snapshot.data()!, uid: uid);
  }

  Map<String, dynamic> _profileMap(OjasProfile profile) => {
    'displayName': profile.displayName,
    'ojasId': profile.ojasId,
    'photoUrl': profile.photoUrl,
  };

  String _safeReplyPreview(String value) => value.length <= 120 ? value : '${value.substring(0, 120)}…';

  void _guardLocalSend(String text) {
    final now = DateTime.now();
    final fingerprint = text.toLowerCase();
    if (now.difference(_lastMessageAttempt) > const Duration(seconds: 15)) {
      _repeatCount = 0;
      _repeatWindowStarted = now;
    }
    if (fingerprint == _lastMessageFingerprint) _repeatCount++; else _repeatCount = 0;
    _lastMessageFingerprint = fingerprint;
    _lastMessageAttempt = now;
    if (_repeatCount >= 8 && now.difference(_repeatWindowStarted) < const Duration(minutes: 1)) {
      throw const MessagingException('Please slow down and try again shortly.');
    }
  }
}

class MessagingException implements Exception {
  const MessagingException(this.message);
  final String message;
  @override
  String toString() => message;
}
