import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';

type CallableRequest = {auth?: {uid?: string} | null; data?: unknown};
type CallableResult = Record<string, unknown>;
type ReelSnapshot = {data: () => Record<string, unknown> | undefined; ref: {set: (data: Record<string, unknown>, options?: {merge?: boolean}) => Promise<unknown>}; params: {reelId: string}};

const MAX_CAPTION_LENGTH = 2200;
const SAFE_VISIBILITIES = new Set(['public', 'followers', 'only me']);
const SAFE_REUSE_POLICIES = new Set(['allowed', 'followers', 'public']);
const MAX_TIMELINE_CLIPS = 32;
const MAX_TEXT_LAYERS = 64;
const MAX_AUDIO_LAYERS = 32;
const MAX_STICKER_LAYERS = 64;
const MAX_EFFECT_LAYERS = 32;
const MAX_OPERATIONS = 256;

function requireUid(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Please sign in again.');
  return uid;
}

function requestData(request: CallableRequest): Record<string, unknown> {
  if (request.data && typeof request.data === 'object' && !Array.isArray(request.data)) return request.data as Record<string, unknown>;
  return {};
}

function cleanCaption(value: unknown): string { return typeof value === 'string' ? value.trim().slice(0, MAX_CAPTION_LENGTH) : ''; }

function normalizeVisibility(value: unknown): string {
  const normalized = typeof value === 'string' ? value.trim().toLowerCase() : 'public';
  return SAFE_VISIBILITIES.has(normalized) ? normalized : 'public';
}

function finiteNumber(value: unknown): value is number { return typeof value === 'number' && Number.isFinite(value); }
function isBoundedString(value: unknown, maxLength: number): boolean { return typeof value === 'string' && value.length <= maxLength; }

function validEditGraph(value: unknown, ownerId?: string, projectId?: string): boolean {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const graph = value as Record<string, unknown>;
  if (graph.version !== 1 && graph.version !== 2) return false;
  const timeline = graph.timeline;
  const textLayers = graph.textLayers;
  const audio = graph.audio;
  const stickers = graph.stickerLayers;
  const effects = graph.effectLayers;
  const operations = graph.operations;
  if (!Array.isArray(timeline) || timeline.length === 0 || timeline.length > MAX_TIMELINE_CLIPS) return false;
  if (!Array.isArray(textLayers) || textLayers.length > MAX_TEXT_LAYERS) return false;
  if (!Array.isArray(audio) || audio.length > MAX_AUDIO_LAYERS) return false;
  if (!Array.isArray(stickers) || stickers.length > MAX_STICKER_LAYERS) return false;
  if (!Array.isArray(effects) || effects.length > MAX_EFFECT_LAYERS) return false;
  if (!Array.isArray(operations) || operations.length > MAX_OPERATIONS) return false;

  for (const clip of timeline) {
    if (!clip || typeof clip !== 'object' || Array.isArray(clip)) return false;
    const item = clip as Record<string, unknown>;
    if (!isBoundedString(item.clipId, 128) || !isBoundedString(item.sourceId, 128)) return false;
    if (!Number.isInteger(item.startMs) || !Number.isInteger(item.endMs) || Number(item.endMs) <= Number(item.startMs)) return false;
    if (!Number.isInteger(item.trimInMs) || Number(item.trimInMs) < 0) return false;
    if (item.trimOutMs != null && (!Number.isInteger(item.trimOutMs) || Number(item.trimOutMs) <= Number(item.trimInMs))) return false;
    if (!finiteNumber(item.speed) || item.speed < 0.25 || item.speed > 4) return false;
    if (!finiteNumber(item.opacity) || item.opacity < 0 || item.opacity > 1) return false;
    if (!finiteNumber(item.scale) || item.scale < 0.1 || item.scale > 5) return false;
    if (!finiteNumber(item.x) || item.x < -1 || item.x > 1) return false;
    if (!finiteNumber(item.y) || item.y < -1 || item.y > 1) return false;
    const rawRotation = Number(item.rotation);
    if (!Number.isFinite(rawRotation)) return false;
    const rotation = ((rawRotation % 360) + 360) % 360;
    if (![0, 90, 180, 270].some((angle) => Math.abs(rotation - angle) < 0.01)) return false;
    for (const key of ['cropLeft', 'cropTop', 'cropRight', 'cropBottom']) if (!finiteNumber(item[key]) || item[key] < 0 || item[key] >= 1) return false;
    if (Number(item.cropLeft) + Number(item.cropRight) >= 1 || Number(item.cropTop) + Number(item.cropBottom) >= 1) return false;
  }

  for (const layer of textLayers) {
    if (!layer || typeof layer !== 'object' || Array.isArray(layer)) return false;
    const item = layer as Record<string, unknown>;
    if (!isBoundedString(item.id, 128) || !isBoundedString(item.text, 5000)) return false;
    if (item.x != null && (!finiteNumber(item.x) || item.x < -0.4 || item.x > 1.4)) return false;
    if (item.y != null && (!finiteNumber(item.y) || item.y < -0.2 || item.y > 1.2)) return false;
    if (item.fontSize != null && (!finiteNumber(item.fontSize) || item.fontSize < 8 || item.fontSize > 120)) return false;
    if (item.startMs != null && !Number.isInteger(item.startMs)) return false;
    if (item.endMs != null && !Number.isInteger(item.endMs)) return false;
  }
  for (const layer of audio) {
    if (!layer || typeof layer !== 'object' || Array.isArray(layer)) return false;
    const item = layer as Record<string, unknown>;
    if (!isBoundedString(item.id, 128)) return false;
    const hasLocalUri = isBoundedString(item.uri, 2048) && String(item.uri).trim().length > 0;
    const storagePath = typeof item.storagePath === 'string' ? item.storagePath.trim() : '';
    const expectedPrefix = ownerId && projectId ? `creation-audio/${ownerId}/${projectId}/` : '';
    const hasSafeStoragePath = Boolean(expectedPrefix)
      && storagePath.startsWith(expectedPrefix)
      && storagePath.length <= 512
      && !storagePath.includes('..')
      && storagePath.split('/').length === 5;
    if (!hasLocalUri && !hasSafeStoragePath) return false;
    if (item.storageProvider != null && item.storageProvider !== 'azure') return false;
    if (item.volume != null && (!finiteNumber(item.volume) || item.volume < 0 || item.volume > 2)) return false;
    if (item.muted != null && typeof item.muted !== 'boolean') return false;
  }
  for (const layer of stickers) {
    if (!layer || typeof layer !== 'object' || Array.isArray(layer)) return false;
    const item = layer as Record<string, unknown>;
    if (!isBoundedString(item.id, 128) || !isBoundedString(item.stickerId, 256)) return false;
  }
  for (const layer of effects) {
    if (!layer || typeof layer !== 'object' || Array.isArray(layer)) return false;
    const item = layer as Record<string, unknown>;
    if (!isBoundedString(item.id, 128) || !isBoundedString(item.effectId, 128)) return false;
    if (!finiteNumber(item.intensity) || item.intensity < 0 || item.intensity > 1) return false;
  }
  return true;
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
  if (!validEditGraph(data.editGraph, creatorId, reelId)) problems.push('invalid_edit_graph');

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
  const fields = ['caption', 'creatorId', 'visibility', 'copyrightConfirmed', 'mediaHash', 'mediaProvider', 'mediaProcessingStatus', 'recommendationEligible', 'deletedAt', 'editGraph'];
  return fields.some((field) => JSON.stringify(before[field] ?? null) !== JSON.stringify(after[field] ?? null));
}
