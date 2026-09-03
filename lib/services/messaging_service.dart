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

  bool get isSignedIn => currentUid != null;

  String conversationIdFor(String uidA, String uidB) {
    final ids = <String>[uidA, uidB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  DocumentReference<Map<String, dynamic>> conversationReference(
    String conversationId,
  ) => _conversations.doc(conversationId);

  CollectionReference<Map<String, dynamic>> messageCollection(
    String conversationId,
  ) => conversationReference(conversationId).collection('messages');

  Stream<List<OjasConversation>> watchConversations() {
    final uid = currentUid;
    if (uid == null) {
      return Stream<List<OjasConversation>>.value(const []);
    }

    return _conversations
        .where('participants', arrayContains: uid)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map(OjasConversation.fromFirestore)
              .toList();

          conversations.sort((a, b) {
            final aTime = a.lastMessageAt;
            final bTime = b.lastMessageAt;

            if (aTime == null && bTime == null) {
              return 0;
            }
            if (aTime == null) {
              return 1;
            }
            if (bTime == null) {
              return -1;
            }
            return bTime.compareTo(aTime);
          });

          return conversations
              .where(
                (conversation) => conversation.lastMessage.trim().isNotEmpty,
              )
              .toList(growable: false);
        });
  }

  Stream<OjasConversation> watchConversation(String conversationId) =>
      conversationReference(conversationId)
          .snapshots()
          .where((snapshot) => snapshot.exists)
          .map(OjasConversation.fromFirestore);

  Stream<bool> watchTyping(String conversationId, String userId) {
    return conversationReference(conversationId).snapshots().map((snapshot) {
      final data = snapshot.data();
      final rawTypingBy = data?['typingBy'];
      if (rawTypingBy is! Map) {
        return false;
      }
      return rawTypingBy[userId] == true;
    });
  }

  Future<void> setTyping({
    required String conversationId,
    required bool isTyping,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      return;
    }

    await conversationReference(
      conversationId,
    ).set({'typingBy.$uid': isTyping}, SetOptions(merge: true));
  }

  void registerPresenceConversation(String conversationId) {
    if (conversationId.trim().isNotEmpty) {
      _activePresenceConversations.add(conversationId);
    }
  }

  void unregisterPresenceConversation(String conversationId) {
    _activePresenceConversations.remove(conversationId);
  }

  Future<void> setPresence({
    required String conversationId,
    required bool isOnline,
  }) async {
    // Presence is owned by RealtimePresenceService with onDisconnect().
    // This compatibility method intentionally performs no Firestore write.
    return;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // RealtimePresenceService owns lifecycle and disconnect state.
  }

  Stream<int> watchTotalUnreadCount() {
    final uid = currentUid;
    if (uid == null) {
      return Stream<int>.value(0);
    }

    return watchConversations().map((conversations) {
      var total = 0;
      for (final conversation in conversations) {
        total += conversation.unreadCountFor(uid);
      }
      return total;
    });
  }

  Stream<List<OjasMessage>> watchMessages(String conversationId) {
    return messageCollection(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(OjasMessage.fromFirestore).toList(),
        );
  }

  Future<List<OjasProfile>> searchUsers(String query) async {
    final currentUserId = currentUid;
    if (currentUserId == null) {
      return [];
    }

    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return [];
    }

    final results = <String, OjasProfile>{};

    final idQuery = await _publicProfiles
        .orderBy('ojasId')
        .startAt([normalized])
        .endAt(['$normalized\uf8ff'])
        .limit(20)
        .get();

    for (final document in idQuery.docs) {
      if (document.id == currentUserId) {
        continue;
      }
      results[document.id] = OjasProfile.fromMap(
        document.data(),
        uid: document.id,
      );
    }

    final cleanQuery = query.trim();
    final nameQuery = await _publicProfiles
        .orderBy('displayName')
        .startAt([cleanQuery])
        .endAt(['$cleanQuery\uf8ff'])
        .limit(20)
        .get();

    for (final document in nameQuery.docs) {
      if (document.id == currentUserId) {
        continue;
      }
      results[document.id] = OjasProfile.fromMap(
        document.data(),
        uid: document.id,
      );
    }

    final users = results.values.toList();
    users.sort((a, b) {
      final aExact = a.ojasId.toLowerCase() == normalized;
      final bExact = b.ojasId.toLowerCase() == normalized;
      if (aExact && !bExact) {
        return -1;
      }
      if (!aExact && bExact) {
        return 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return users;
  }

  Future<String> openConversation(OjasProfile otherUser) async {
    final uid = currentUid;
    if (uid == null) {
      throw const MessagingException('Please sign in again.');
    }
    if (otherUser.uid.isEmpty || otherUser.uid == uid) {
      throw const MessagingException('Invalid OJAS user.');
    }

    final currentProfile = await _getCurrentProfile(uid);
    final conversationId = conversationIdFor(uid, otherUser.uid);
    final reference = conversationReference(conversationId);

    final existing = await _conversations
        .where('participants', arrayContains: uid)
        .limit(50)
        .get();

    for (final document in existing.docs) {
      if (document.id == conversationId) {
        return conversationId;
      }
    }

    await reference.set({
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
    if (uid == null) {
      throw const MessagingException('Please sign in again.');
    }

    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return;
    }
    if (cleanText.length > 2000) {
      throw const MessagingException(
        'Messages can contain up to 2000 characters.',
      );
    }
    if (receiverId.isEmpty) {
      throw const MessagingException('Invalid conversation.');
    }

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
        'replyToText': replyTo.isDeleted
            ? 'This message was deleted.'
            : replyTo.isImage
            ? 'Photo'
            : _safeReplyPreview(replyTo.text),
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
    required String imageUrl,
    required String storagePath,
    required int width,
    required int height,
    required int mediaBytes,
    String? caption,
    OjasMessage? replyTo,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw const MessagingException('Please sign in again.');
    }
    if (receiverId.isEmpty) {
      throw const MessagingException('Invalid conversation.');
    }
    if (imageUrl.trim().isEmpty) {
      throw const MessagingException('Image upload failed.');
    }
    if (mediaBytes <= 0 || mediaBytes > 10 * 1024 * 1024) {
      throw const MessagingException('Image is too large.');
    }

    final cleanCaption = (caption ?? '').trim();
    if (cleanCaption.length > 2000) {
      throw const MessagingException(
        'Caption can contain up to 2000 characters.',
      );
    }

    _guardLocalSend('image:$imageUrl:$storagePath');

    final conversation = conversationReference(conversationId);
    final message = messageCollection(conversationId).doc();
    final batch = _firestore.batch();

    final messageData = <String, dynamic>{
      'conversationId': conversationId,
      'senderId': uid,
      'text': cleanCaption,
      'type': 'image',
      'isDeleted': false,
      'reactions': <String, String>{},
      'mediaUrl': imageUrl,
      'mediaStoragePath': storagePath,
      'mediaWidth': width,
      'mediaHeight': height,
      'mediaBytes': mediaBytes,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (replyTo != null) {
      messageData.addAll({
        'replyToMessageId': replyTo.id,
        'replyToSenderId': replyTo.senderId,
        'replyToText': replyTo.isDeleted
            ? 'This message was deleted.'
            : replyTo.isImage
            ? 'Photo'
            : _safeReplyPreview(replyTo.text),
        'replyToType': replyTo.type,
      });
    }

    batch.set(message, messageData);
    batch.set(conversation, {
      'lastMessage': cleanCaption.isNotEmpty ? cleanCaption : '📷 Photo',
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCounts.$uid': 0,
      'unreadCounts.$receiverId': FieldValue.increment(1),
      'typingBy.$uid': false,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      throw const MessagingException('Please sign in again.');
    }
    if (!_allowedReactions.contains(emoji)) {
      throw const MessagingException('Invalid reaction.');
    }

    final reference = messageCollection(conversationId).doc(messageId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const MessagingException('Message no longer exists.');
      }
      if (data['isDeleted'] == true) {
        throw const MessagingException(
          'Deleted messages cannot be reacted to.',
        );
      }

      final reactions = <String, String>{};
      final rawReactions = data['reactions'];
      if (rawReactions is Map) {
        rawReactions.forEach((key, value) {
          if (key is String && value is String) {
            reactions[key] = value;
          }
        });
      }

      if (reactions[uid] == emoji) {
        reactions.remove(uid);
      } else {
        reactions[uid] = emoji;
      }

      transaction.update(reference, {'reactions': reactions});
    });
  }

  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      return;
    }

    final reference = messageCollection(conversationId).doc(messageId);
    await reference.update({'reactions.$uid': FieldValue.delete()});
  }

  Future<void> markConversationRead(String conversationId) async {
    final uid = currentUid;
    if (uid == null) {
      return;
    }

    await conversationReference(conversationId).set({
      'unreadCounts.$uid': 0,
      'lastReadAtBy.$uid': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      return;
    }

    final reference = messageCollection(conversationId).doc(messageId);
    final snapshot = await reference.get();
    final data = snapshot.data();

    if (data == null || data['senderId'] != uid) {
      throw const MessagingException('You can only delete your own messages.');
    }

    await reference.update({
      'text': 'This message was deleted.',
      'isDeleted': true,
      'reactions': <String, String>{},
    });
  }

  Future<OjasProfile> _getCurrentProfile(String uid) async {
    final snapshot = await _publicProfiles.doc(uid).get();
    final data = snapshot.data();
    if (data == null) {
      final user = _auth.currentUser;
      return OjasProfile.empty(
        uid: uid,
        displayName: user?.displayName ?? 'OJAS User',
        photoUrl: 'avatar_1',
      );
    }
    return OjasProfile.fromMap(data, uid: uid);
  }

  Map<String, dynamic> _profileMap(OjasProfile profile) {
    return {
      'uid': profile.uid,
      'ojasId': profile.ojasId,
      'displayName': profile.displayName,
      'photoUrl': profile.photoUrl,
      'isVerified': profile.isVerified,
    };
  }

  void _guardLocalSend(String fingerprint) {
    final now = DateTime.now();
    final sinceLast = now.difference(_lastMessageAttempt);
    if (sinceLast < const Duration(milliseconds: 300)) {
      throw const MessagingException('Please slow down for a moment.');
    }

    if (fingerprint == _lastMessageFingerprint &&
        now.difference(_repeatWindowStarted) <= const Duration(seconds: 30)) {
      _repeatCount += 1;
    } else {
      _repeatWindowStarted = now;
      _repeatCount = 1;
      _lastMessageFingerprint = fingerprint;
    }

    if (_repeatCount > 4) {
      throw const MessagingException(
        'Repeated messages are temporarily blocked.',
      );
    }

    _lastMessageAttempt = now;
  }

  static const List<String> _allowedReactions = [
    '❤️',
    '👍',
    '😂',
    '😮',
    '😢',
    '🔥',
  ];

  static String _safeReplyPreview(String text) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= 140) {
      return clean;
    }
    return '${clean.substring(0, 137)}...';
  }
}

class MessagingException implements Exception {
  const MessagingException(this.message);

  final String message;

  @override
  String toString() => message;
}
