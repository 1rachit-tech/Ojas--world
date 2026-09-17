import {QueueServiceClient} from '@azure/storage-queue';
import {initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {setGlobalOptions} from 'firebase-functions/v2';
import {onCall} from 'firebase-functions/v2/https';
import {onDocumentCreated, onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {defineSecret} from 'firebase-functions/params';
import {manageReelLifecycle, moderateAndIndexReel, shouldReprocessReel} from './reel_lifecycle';
import {searchPublicReels} from './reel_search';

initializeApp();
setGlobalOptions({region: 'asia-south1', maxInstances: 3, minInstances: 0});

const azureQueueConnectionString = defineSecret('AZURE_STORAGE_QUEUE_CONNECTION_STRING');
const AZURE_PROCESSING_QUEUE = 'ojas-media-processing';

interface ConversationData { participants?: unknown; participantProfiles?: unknown; }
interface MessageData { senderId?: unknown; text?: unknown; type?: unknown; isDeleted?: unknown; }
interface CreationMediaData { assetId?: unknown; projectId?: unknown; ownerId?: unknown; storagePath?: unknown; contentLength?: unknown; contentType?: unknown; processingStatus?: unknown; }

const RATE_WINDOW_MS = 60_000;
const MAX_MESSAGES_PER_INSTANCE_PER_MINUTE = 30;
const senderMessageTimes = new Map<string, number[]>();

function profileName(conversation: ConversationData, uid: string): string {
  const profiles = conversation.participantProfiles;
  if (profiles && typeof profiles === 'object') {
    const value = (profiles as Record<string, unknown>)[uid];
    if (value && typeof value === 'object') {
      const displayName = (value as Record<string, unknown>)['displayName'];
      if (typeof displayName === 'string' && displayName.trim().length > 0) return displayName.trim().slice(0, 80);
    }
  }
  return 'OJAS user';
}

function receiverIdFor(participants: unknown, senderId: string): string | null {
  if (!Array.isArray(participants) || participants.length !== 2) return null;
  for (const participant of participants) if (typeof participant === 'string' && participant !== senderId) return participant;
  return null;
}

function isRateLimited(senderId: string): boolean {
  const now = Date.now();
  const recent = (senderMessageTimes.get(senderId) ?? []).filter((timestamp) => now - timestamp < RATE_WINDOW_MS);
  if (recent.length >= MAX_MESSAGES_PER_INSTANCE_PER_MINUTE) { senderMessageTimes.set(senderId, recent); return true; }
  recent.push(now);
  senderMessageTimes.set(senderId, recent);
  return false;
}

function tokenListFromUserData(data: Record<string, unknown>): string[] {
  const rawTokens = data['fcmTokens'];
  if (rawTokens && typeof rawTokens === 'object' && !Array.isArray(rawTokens)) return Object.keys(rawTokens).filter((token) => token.trim().length > 0);
  if (Array.isArray(rawTokens)) return rawTokens.filter((token): token is string => typeof token === 'string' && token.trim().length > 0);
  return [];
}

function getMediaQueueClient(connectionString: string) {
  const trimmed = connectionString.trim();
  if (!trimmed) return null;
  const service = QueueServiceClient.fromConnectionString(trimmed);
  return service.getQueueClient(AZURE_PROCESSING_QUEUE);
}

export const sendMessagePush = onDocumentCreated('conversations/{conversationId}/messages/{messageId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const message = snapshot.data() as MessageData;
  const senderId = typeof message.senderId === 'string' ? message.senderId : '';
  if (!senderId || message.isDeleted === true) return;
  if (isRateLimited(senderId)) { console.warn(`Skipping push for rate-limited sender ${senderId}.`); return; }
  const firestore = getFirestore();
  const conversationSnapshot = await firestore.doc(`conversations/${event.params.conversationId}`).get();
  if (!conversationSnapshot.exists) return;
  const conversation = conversationSnapshot.data() as ConversationData;
  const receiverId = receiverIdFor(conversation.participants, senderId);
  if (!receiverId) return;
  const receiverSnapshot = await firestore.doc(`users/${receiverId}`).get();
  if (!receiverSnapshot.exists) return;
  const receiverData = receiverSnapshot.data() ?? {};
  const tokens = tokenListFromUserData(receiverData);
  if (tokens.length === 0) return;
  const senderName = profileName(conversation, senderId);
  const messageType = message.type === 'image' ? 'image' : 'text';
  const text = typeof message.text === 'string' ? message.text.trim() : '';
  const body = messageType === 'image' ? (text.length > 0 ? `📷 ${text}` : '📷 Photo') : (text.length > 0 ? text : 'New message');
  const response = await getMessaging().sendEachForMulticast({tokens, notification: {title: senderName, body: body.slice(0, 300)}, data: {type: 'message', conversationId: event.params.conversationId, messageId: event.params.messageId, senderId}, android: {priority: 'high', notification: {sound: 'default'}}, apns: {payload: {aps: {sound: 'default', badge: 1}}}});
  const invalidTokens: string[] = [];
  response.responses.forEach((result, index) => {
    const errorCode = result.error?.code;
    if (errorCode === 'messaging/registration-token-not-registered' || errorCode === 'messaging/invalid-registration-token') invalidTokens.push(tokens[index]);
  });
  if (invalidTokens.length === 0) return;
  const userRef = firestore.doc(`users/${receiverId}`);
  const current = (await userRef.get()).data() ?? {};
  const raw = current['fcmTokens'];
  if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
    const updates: Record<string, FieldValue> = {};
    for (const token of invalidTokens) updates[`fcmTokens.${token}`] = FieldValue.delete();
    await userRef.update(updates);
    return;
  }
  await userRef.update({fcmTokens: tokens.filter((token) => !invalidTokens.includes(token))});
});

export const enqueueCreationMediaProcessing = onDocumentCreated({document: 'creationMedia/{assetId}', secrets: [azureQueueConnectionString]}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const media = snapshot.data() as CreationMediaData;
  const assetId = typeof media.assetId === 'string' ? media.assetId.trim() : event.params.assetId;
  const projectId = typeof media.projectId === 'string' ? media.projectId.trim() : '';
  const ownerId = typeof media.ownerId === 'string' ? media.ownerId.trim() : '';
  const storagePath = typeof media.storagePath === 'string' ? media.storagePath.trim() : '';
  const contentType = typeof media.contentType === 'string' ? media.contentType.trim() : '';
  const contentLength = typeof media.contentLength === 'number' ? media.contentLength : 0;
  const processingStatus = typeof media.processingStatus === 'string' ? media.processingStatus.trim().toLowerCase() : '';
  if (!assetId || !projectId || !ownerId || !storagePath || !contentType || contentLength <= 0 || (processingStatus && processingStatus !== 'queued')) { console.warn(`Ignoring invalid creationMedia job ${event.params.assetId}.`); return; }
  const queue = getMediaQueueClient(azureQueueConnectionString.value());
  if (!queue) throw new Error('AZURE_STORAGE_QUEUE_CONNECTION_STRING is not configured.');
  const job = {schemaVersion: 1, kind: 'creation-video-transcode', assetId, projectId, ownerId, storagePath, contentLength, contentType};
  try {
    await queue.createIfNotExists();
    await queue.sendMessage(Buffer.from(JSON.stringify(job), 'utf8').toString('base64'));
    await snapshot.ref.set({processingStatus: 'queued', queueEnqueuedAt: FieldValue.serverTimestamp(), queueName: AZURE_PROCESSING_QUEUE}, {merge: true});
  } catch (error) {
    console.error(`Failed to enqueue creation media ${assetId}.`, error);
    await snapshot.ref.set({processingStatus: 'enqueue_failed', enqueueError: String(error).slice(0, 500), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    throw error;
  }
});

export const enqueueDeletedReelMediaCleanup = onDocumentUpdated({document: 'reels/{reelId}', secrets: [azureQueueConnectionString]}, async (event) => {
  const before = event.data.before.data() as Record<string, unknown>;
  const after = event.data.after.data() as Record<string, unknown>;
  const wasDeleted = before.deletedAt != null || before.moderationStatus === 'deleted';
  const isDeleted = after.deletedAt != null || after.moderationStatus === 'deleted';
  if (wasDeleted || !isDeleted) return;

  const ownerId = typeof after.creatorId === 'string' ? after.creatorId.trim() : '';
  const mediaProvider = typeof after.mediaProvider === 'string' ? after.mediaProvider.trim().toLowerCase() : '';
  if (!ownerId || mediaProvider !== 'azure') return;

  const queue = getMediaQueueClient(azureQueueConnectionString.value());
  if (!queue) throw new Error('AZURE_STORAGE_QUEUE_CONNECTION_STRING is not configured.');
  const mediaAssetId = typeof after.mediaAssetId === 'string' ? after.mediaAssetId.trim() : '';
  const job = {
    schemaVersion: 1,
    kind: 'creation-media-cleanup',
    reelId: event.params.reelId,
    ownerId,
    assetId: mediaAssetId || event.params.reelId,
    cleanupPrefix: `creation/${ownerId}/${event.params.reelId}/`,
    audioCleanupPrefix: `creation-audio/${ownerId}/${event.params.reelId}/`,
    mediaStoragePath: typeof after.mediaStoragePath === 'string' ? after.mediaStoragePath.trim() : '',
  };

  await queue.createIfNotExists();
  await queue.sendMessage(Buffer.from(JSON.stringify(job), 'utf8').toString('base64'));
  await event.data.after.ref.set({mediaCleanupStatus: 'queued', mediaCleanupQueuedAt: FieldValue.serverTimestamp()}, {merge: true});
});

export const manageReel = onCall(async (request) => manageReelLifecycle(request));
export const searchReels = onCall(async (request) => searchPublicReels(request));

export const moderateAndIndexReelOnCreate = onDocumentCreated('reels/{reelId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  await moderateAndIndexReel({data: () => snapshot.data() as Record<string, unknown>, ref: snapshot.ref, params: event.params});
});

export const moderateAndIndexReelOnUpdate = onDocumentUpdated('reels/{reelId}', async (event) => {
  if (!shouldReprocessReel(event.data.before.data() as Record<string, unknown>, event.data.after.data() as Record<string, unknown>)) return;
  const snapshot = event.data.after;
  await moderateAndIndexReel({data: () => snapshot.data() as Record<string, unknown>, ref: snapshot.ref, params: event.params});
});
