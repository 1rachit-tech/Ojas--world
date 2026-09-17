import {FieldValue, getFirestore} from 'firebase-admin/firestore';

type CallableRequest = {
  auth?: {uid?: string} | null;
  data?: Record<string, unknown>;
};

type CallableResult = Record<string, unknown>;

const MAX_CAPTION_LENGTH = 2200;
const SAFE_VISIBILITIES = new Set(['public', 'followers', 'only me']);
const SAFE_REUSE_POLICIES = new Set(['allowed', 'followers', 'public']);

function requireUid(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new Error('unauthenticated');
  return uid;
}

function cleanCaption(value: unknown): string {
  return typeof value === 'string' ? value.trim().slice(0, MAX_CAPTION_LENGTH) : '';
}

function normalizeVisibility(value: unknown): string {
  const valueString = typeof value === 'string' ? value.trim().toLowerCase() : 'public';
  return SAFE_VISIBILITIES.has(valueString) ? valueString : 'public';
}

export async function manageReelLifecycle(request: CallableRequest): Promise<CallableResult> {
  const uid = requireUid(request);
  const data = request.data ?? {};
  const operation = typeof data.operation === 'string' ? data.operation : '';
  const postId = typeof data.postId === 'string' ? data.postId.trim() : '';

  if (!postId) throw new Error('invalid-argument');

  const db = getFirestore();
  const reelRef = db.doc(`reels/${postId}`);
  const snapshot = await reelRef.get();
  if (!snapshot.exists) throw new Error('not-found');

  const reel = snapshot.data() ?? {};
  if (reel.creatorId !== uid) throw new Error('permission-denied');
  if (reel.deletedAt) throw new Error('already-deleted');

  if (operation === 'edit') {
    const caption = cleanCaption(data.caption ?? reel.caption);
    const visibility = normalizeVisibility(data.visibility ?? reel.visibility);
    const allowComments = typeof data.allowComments === 'boolean'
      ? data.allowComments
      : reel.allowComments === true;
    const recommendationEligible = visibility === 'public'
      && data.recommendationEligible === true;

    await reelRef.update({
      caption,
      visibility,
      allowComments,
      recommendationEligible,
      moderationStatus: 'pending',
      updatedAt: FieldValue.serverTimestamp(),
      editedAt: FieldValue.serverTimestamp(),
    });

    return {ok: true, operation: 'edit', postId};
  }

  if (operation === 'delete') {
    await reelRef.update({
      deletedAt: FieldValue.serverTimestamp(),
      deletedBy: uid,
      visibility: 'only me',
      recommendationEligible: false,
      moderationStatus: 'deleted',
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {ok: true, operation: 'delete', postId};
  }

  if (operation === 'reuse') {
    const sourceVisibility = typeof reel.visibility === 'string' ? reel.visibility.toLowerCase() : '';
    const reusePolicy = typeof reel.reusePolicy === 'string' ? reel.reusePolicy.toLowerCase() : 'allowed';
    if (sourceVisibility !== 'public' || !SAFE_REUSE_POLICIES.has(reusePolicy) || reusePolicy === 'followers') {
      throw new Error('reuse-not-allowed');
    }

    const requestRef = db.collection('reelReuseRequests').doc();
    await requestRef.set({
      requestId: requestRef.id,
      sourcePostId: postId,
      sourceCreatorId: reel.creatorId,
      requesterId: uid,
      status: 'requested',
      createdAt: FieldValue.serverTimestamp(),
    });

    return {ok: true, operation: 'reuse', requestId: requestRef.id, sourcePostId: postId};
  }

  throw new Error('unsupported-operation');
}

export async function moderateAndIndexReel(snapshot: {data: () => Record<string, unknown> | undefined; ref: {set: Function}; params: {reelId: string}}): Promise<void> {
  const data = snapshot.data() ?? {};
  const caption = typeof data.caption === 'string' ? data.caption.trim() : '';
  const creatorId = typeof data.creatorId === 'string' ? data.creatorId : '';
  const visibility = typeof data.visibility === 'string' ? data.visibility.toLowerCase() : '';
  const rightsConfirmed = data.copyrightConfirmed === true;
  const mediaHash = typeof data.mediaHash === 'string' ? data.mediaHash : '';

  const problems: string[] = [];
  if (!creatorId) problems.push('missing_creator');
  if (caption.length > MAX_CAPTION_LENGTH) problems.push('caption_too_long');
  if (!rightsConfirmed) problems.push('rights_unconfirmed');
  if (mediaHash.length !== 64) problems.push('invalid_media_hash');

  const moderationStatus = problems.length === 0 ? 'approved' : 'review';
  await snapshot.ref.set({
    moderationStatus,
    moderationIssues: problems,
    recommendationEligible: moderationStatus === 'approved' && visibility === 'public' && data.recommendationEligible === true,
    moderatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  if (moderationStatus !== 'approved' || visibility !== 'public') return;

  const tokens = Array.from(new Set(
    caption
      .toLowerCase()
      .replace(/[^a-z0-9_#@\s]/g, ' ')
      .split(/\s+/)
      .map((token) => token.startsWith('#') ? token.slice(1) : token)
      .filter((token) => token.length >= 2 && token.length <= 64),
  )).slice(0, 100);

  await getFirestore().doc(`searchIndex/${snapshot.params.reelId}`).set({
    postId: snapshot.params.reelId,
    creatorId,
    caption,
    tokens,
    visibility,
    moderationStatus,
    createdAt: data.createdAt ?? FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}
