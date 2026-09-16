import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/creation_project.dart';
import 'creation_project_store.dart';
import 'creation_validation_service.dart';

class CreationPublishResult {
  const CreationPublishResult({
    required this.postId,
    required this.mediaUrl,
  });

  final String postId;
  final String mediaUrl;
}

class CreationPublishService {
  CreationPublishService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<CreationPublishResult> publish(CreationProject project) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != project.ownerId) {
      throw const CreationPublishException('Please sign in again before posting.');
    }

    final validation = await CreationValidationService.validateProject(project);
    if (!validation.isValid) {
      throw CreationPublishException(validation.message);
    }

    if (project.mediaAssets.length != 1 || project.mediaAssets.first.type != 'video') {
      throw const CreationPublishException(
        'This publishing path currently accepts one video. Multi-media and image publishing remain draft-ready until an existing post schema is verified.',
      );
    }

    final source = File(project.mediaAssets.first.localUri);
    final postRef = _firestore.collection('reels').doc(project.projectId);

    final existing = await postRef.get();
    if (existing.exists) {
      final existingUrl = existing.data()?['videoUrl'] as String? ?? '';
      return CreationPublishResult(
        postId: postRef.id,
        mediaUrl: existingUrl,
      );
    }

    final storageReference = _storage
        .ref()
        .child('reels')
        .child(user.uid)
        .child('${project.projectId}.mp4');

    final uploadTask = await storageReference.putFile(
      source,
      SettableMetadata(contentType: 'video/mp4'),
    );
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    final publishRequestId = const Uuid().v4();
    await postRef.set(<String, dynamic>{
      'creatorId': user.uid,
      'projectId': project.projectId,
      'publishRequestId': publishRequestId,
      'videoUrl': downloadUrl,
      'hlsUrl': downloadUrl,
      'thumbnailUrl': '',
      'caption': project.caption,
      'shaderUsed': 'Natural',
      'visibility': project.privacy.toLowerCase(),
      'recommendationEligible': project.privacy.toLowerCase() == 'public',
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

    final published = project.copyWith(
      status: CreationProjectStatus.published,
      publishState: <String, dynamic>{
        'postId': postRef.id,
        'mediaUrl': downloadUrl,
        'publishedAt': DateTime.now().toIso8601String(),
        'publishRequestId': publishRequestId,
      },
    );
    await CreationProjectStore.instance.save(published);

    return CreationPublishResult(
      postId: postRef.id,
      mediaUrl: downloadUrl,
    );
  }
}

class CreationPublishException implements Exception {
  const CreationPublishException(this.message);

  final String message;

  @override
  String toString() => message;
}
