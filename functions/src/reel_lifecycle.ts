import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';

type CallableRequest = {
  auth?: {uid?: string} | null;
  data?: unknown;
};

type CallableResult = Record<string, unknown>;
type ReelSnapshot = {
  data: () => Record<string, unknown> | undefined;
  ref: {set: (data: Record<string, unknown>, options?: {merge?: boolean}) => Promise<unknown>};
  params: {reelId: string};
};

const MAX_CAPTION_LENGTH = 2200;
const SAFE_VISIBILITIES = new Set(['public', 'followers', 'only me']);
const SAFE_REUSE_POLICIES = new Set(['allowed', 'followers', 'public']);

function requireUid(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Please sign in again.');
  return uid;
}

function requestData(request: CallableRequest): Record<string, unknown> {
  if (request.data && typeof request.data === 'object' && !Array.isArray(request.data)) return request.data as Record<string, unknown>;
  return {};
}

function cleanCaption(value: unknown): string {
  return typeof value === 'string' ? value.trim().slice(0, MAX_CAPTION_LENGTH) : '';
}

function normalizeVisibility(value: unknown): string {
  const normalized = typeof value === 'string' ? value.trim().toLowerCase() : 'public';
  return SAFE_VISIBILITIES.has(normalized) ? normalized : 'public';
}

export async function manageReelLifecycle(request: CallableRequest): Promise<CallableResult> {
  const uid = requireUid(request);
  const data = requestData(request);
  const operation = typeof data.operation === 'string' ? data.operation : '';
  const postId = typeof data.postId === 'string' ? data.postId.trim() : '';
  if (!postId) throw new HttpsError('invalid-argument', 'Post ID is required.');

  const db = getFirestore();
  const reelRef = db.doc(`reels/${postId}`);
  const snapshot = await reelRef.get();
  if (!snapshot.exists) throw new HttpsError('not-found', 'Post not found.');
  const reel = snapshot.data() ?? {};
  if (reel.creatorId !== uid) throw new HttpsError('permission-denied', 'You cannot manage this post.');
  if (reel.deletedAt) throw new HttpsError('failed-precondition', 'This post is already deleted.');

  if (operation === 'edit') {
    const caption = cleanCaption(data.caption ?? reel.caption);
    const visibility = normalizeVisibility(data.visibility ?? reel.visibility);
    const allowComments = typeof data.allowComments === 'boolean' ? data.allowComments : reel.allowComments === true;
    const recommendationEligible = visibility === 'public' && data.recommendationEligible === true;
    await reelRef.update({caption, visibility, allowComments, recommendationEligible, moderationStatus: 'pending', updatedAt: FieldValue.serverTimestamp(), editedAt: FieldValue.serverTimestamp()});
    return {ok: true, operation: 'edit', postId};
  }

  if (operation === 'delete') {
    await reelRef.update({deletedAt: FieldValue.serverTimestamp(), deletedBy: uid, visibility: 'only me', recommendationEligible: false, moderationStatus: 'deleted', updatedAt: FieldValue.serverTimestamp()});
    return {ok: true, operation: 'delete', postId};
  }

  if (operation === 'reuse') {
    const sourceVisibility = typeof reel.visibility === 'string' ? reel.visibility.toLowerCase() : '';
    const reusePolicy = typeof reel.reusePolicy === 'string' ? reel.reusePolicy.toLowerCase() : 'allowed';
    if (sourceVisibility !== 'public' || !SAFE_REUSE_POLICIES.has(reusePolicy) || reusePolicy === 'followers') throw new HttpsError('permission-denied', 'Reuse is not allowed for this post.');
    const requestRef = db.collection('reelReuseRequests').doc();
    await requestRef.set({requestId: requestRef.id, sourcePostId: postId, sourceCreatorId: reel.creatorId, requesterId: uid, status: 'requested', createdAt: FieldValue.serverTimestamp()});
    return {ok: true, operation: 'reuse', requestId: requestRef.id, sourcePostId: postId};
  }

  throw new HttpsError('invalid-argument', 'Unsupported post operation.');
}

export async function moderateAndIndexReel(snapshot: ReelSnapshot): Promise<void> {
  const data = snapshot.data() ?? {};
  const reelId = snapshot.params.reelId;
  const searchRef = getFirestore().doc(`searchIndex/${reelId}`);
  const caption = typeof data.caption === 'string' ? data.caption.trim() : '';
  const creatorId = typeof data.creatorId === 'string' ? data.creatorId : '';
  const visibility = typeof data.visibility === 'string' ? data.visibility.toLowerCase() : '';
  const rightsConfirmed = data.copyrightConfirmed === true;
  const mediaHash = typeof data.mediaHash === 'string' ? data.mediaHash : '';
  const mediaProvider = typeof data.mediaProvider === 'string' ? data.mediaProvider.toLowerCase() : '';
  const mediaProcessingStatus = typeof data.mediaProcessingStatus === 'string' ? data.mediaProcessingStatus.toLowerCase() : '';
  const deleted = data.deletedAt != null || data.moderationStatus === 'deleted';

  if (deleted) {
    await snapshot.ref.set({moderationStatus: 'deleted', recommendationEligible: false, moderatedAt: FieldValue.serverTimestamp()}, {merge: true});
    await searchRef.delete();
    return;
  }

  const problems: string[] = [];
  if (!creatorId) problems.push('missing_creator');
  if (caption.length > MAX_CAPTION_LENGTH) problems.push('caption_too_long');
  if (!rightsConfirmed) problems.push('rights_unconfirmed');
  if (mediaHash.length !== 64) problems.push('invalid_media_hash');
  if (mediaProvider === 'azure' && !['ready', 'published'].includes(mediaProcessingStatus)) problems.push('media_not_ready');

  const moderationStatus = problems.length === 0 ? 'approved' : 'review';
  await snapshot.ref.set({moderationStatus, moderationIssues: problems, recommendationEligible: moderationStatus === 'approved' && visibility === 'public' && data.recommendationEligible === true, moderatedAt: FieldValue.serverTimestamp()}, {merge: true});

  if (moderationStatus !== 'approved' || visibility !== 'public') {
    await searchRef.delete();
    return;
  }

  const tokens = Array.from(new Set(caption.toLowerCase().replace(/[^a-z0-9_#@\s]/g, ' ').split(/\s+/).map((token) => token.startsWith('#') ? token.slice(1) : token).filter((token) => token.length >= 2 && token.length <= 64))).slice(0, 100);
  await searchRef.set({postId: reelId, creatorId, caption, tokens, visibility, moderationStatus, createdAt: data.createdAt ?? FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
}

export function shouldReprocessReel(before: Record<string, unknown>, after: Record<string, unknown>): boolean {
  const fields = [
    'caption',
    'creatorId',
    'visibility',
    'copyrightConfirmed',
    'mediaHash',
    'mediaProvider',
    'mediaProcessingStatus',
    'recommendationEligible',
    'deletedAt',
  ];
  return fields.some((field) => JSON.stringify(before[field] ?? null) !== JSON.stringify(after[field] ?? null));
}
