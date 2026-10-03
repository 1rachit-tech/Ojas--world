export {syncPublicProfileSearchIndex, syncReelSearchIndex} from './search_indexer';

import {initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {setGlobalOptions} from 'firebase-functions/v2';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {defineSecret} from 'firebase-functions/params';
import {AccessToken} from 'livekit-server-sdk';

initializeApp();

setGlobalOptions({
  region: 'asia-south1',
  maxInstances: 3,
  minInstances: 0,
});

const livekitApiKey = defineSecret('LIVEKIT_API_KEY');
const livekitApiSecret = defineSecret('LIVEKIT_API_SECRET');
const livekitUrl = defineSecret('LIVEKIT_URL');

interface ConversationData {
  participants?: unknown;
  participantProfiles?: unknown;
}

interface MessageData {
  senderId?: unknown;
  text?: unknown;
  type?: unknown;
  isDeleted?: unknown;
}

const RATE_WINDOW_MS = 60_000;
const MAX_MESSAGES_PER_INSTANCE_PER_MINUTE = 30;
const senderMessageTimes = new Map<string, number[]>();

function profileName(
  conversation: ConversationData,
  uid: string,
): string {
  const profiles = conversation.participantProfiles;
  if (profiles && typeof profiles === 'object') {
    const value = (profiles as Record<string, unknown>)[uid];
    if (value && typeof value === 'object') {
      const displayName = (value as Record<string, unknown>)['displayName'];
      if (typeof displayName === 'string' && displayName.trim().length > 0) {
        return displayName.trim().slice(0, 80);
      }
    }
  }
  return 'OJAS user';
}

function receiverIdFor(
  participants: unknown,
  senderId: string,
): string | null {
  if (!Array.isArray(participants) || participants.length !== 2) {
    return null;
  }
  for (const participant of participants) {
    if (typeof participant === 'string' && participant !== senderId) {
      return participant;
    }
  }
  return null;
}

function isRateLimited(senderId: string): boolean {
  const now = Date.now();
  const recent = (senderMessageTimes.get(senderId) ?? []).filter(
    (timestamp) => now - timestamp < RATE_WINDOW_MS,
  );
  if (recent.length >= MAX_MESSAGES_PER_INSTANCE_PER_MINUTE) {
    senderMessageTimes.set(senderId, recent);
    return true;
  }
  recent.push(now);
  senderMessageTimes.set(senderId, recent);
  return false;
}

function tokenListFromUserData(data: Record<string, unknown>): string[] {
  const rawTokens = data['fcmTokens'];
  if (rawTokens && typeof rawTokens === 'object' && !Array.isArray(rawTokens)) {
    return Object.keys(rawTokens).filter((token) => token.trim().length > 0);
  }
  if (Array.isArray(rawTokens)) {
    return rawTokens.filter(
      (token): token is string =>
        typeof token === 'string' && token.trim().length > 0,
    );
  }
  return [];
}

function previewBody(message: MessageData): string {
  const type = typeof message.type === 'string' ? message.type : 'text';
  const text = typeof message.text === 'string' ? message.text.trim() : '';
  switch (type) {
    case 'image':
      return text.length > 0 ? `📷 ${text}` : '📷 Photo';
    case 'video':
      return text.length > 0 ? `🎬 ${text}` : '🎬 Video';
    case 'audio':
      return '🎤 Voice note';
    default:
      return text.length > 0 ? text : 'New message';
  }
}

export const sendMessagePush = onDocumentCreated(
  'conversations/{conversationId}/messages/{messageId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const message = snapshot.data() as MessageData;
    const senderId =
      typeof message.senderId === 'string' ? message.senderId.trim() : '';

    if (!senderId || message.isDeleted === true) return;
    if (isRateLimited(senderId)) {
      console.warn(`Skipping push for rate-limited sender ${senderId}.`);
      return;
    }

    const firestore = getFirestore();
    const conversationSnapshot = await firestore
      .doc(`conversations/${event.params.conversationId}`)
      .get();
    if (!conversationSnapshot.exists) return;

    const conversation = conversationSnapshot.data() as ConversationData;
    const receiverId = receiverIdFor(conversation.participants, senderId);
    if (!receiverId) return;

    const [blockedByReceiver, blockedBySender] = await Promise.all([
      firestore.doc(`userBlocks/${receiverId}/blocked/${senderId}`).get(),
      firestore.doc(`userBlocks/${senderId}/blocked/${receiverId}`).get(),
    ]);
    if (blockedByReceiver.exists || blockedBySender.exists) return;

    const receiverSnapshot = await firestore.doc(`users/${receiverId}`).get();
    if (!receiverSnapshot.exists) return;

    const tokens = tokenListFromUserData(receiverSnapshot.data() ?? {}).slice(
      0,
      10,
    );
    if (tokens.length === 0) return;

    const senderName = profileName(conversation, senderId);
    const body = previewBody(message);

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: senderName,
        body: body.slice(0, 300),
      },
      data: {
        type: 'message',
        conversationId: event.params.conversationId,
        messageId: event.params.messageId,
        senderId,
      },
      android: {
        priority: 'high',
        notification: {sound: 'default', channelId: 'messages'},
      },
      apns: {
        payload: {aps: {sound: 'default', badge: 1}},
      },
    });

    const invalidTokens: string[] = [];
    response.responses.forEach((result, index) => {
      const errorCode = result.error?.code;
      if (
        errorCode === 'messaging/registration-token-not-registered' ||
        errorCode === 'messaging/invalid-registration-token'
      ) {
        invalidTokens.push(tokens[index]);
      }
    });

    if (invalidTokens.length === 0) return;

    const userRef = firestore.doc(`users/${receiverId}`);
    const current = (await userRef.get()).data() ?? {};
    const raw = current['fcmTokens'];

    if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
      const updates: Record<string, FieldValue> = {};
      for (const token of invalidTokens) {
        updates[`fcmTokens.${token}`] = FieldValue.delete();
      }
      await userRef.update(updates);
      return;
    }

    await userRef.update({
      fcmTokens: tokens.filter((token) => !invalidTokens.includes(token)),
    });
  },
);

export const createLiveKitToken = onCall(
  {
    secrets: [livekitApiKey, livekitApiSecret, livekitUrl],
    maxInstances: 5,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }

    const uid = request.auth.uid;
    const conversationId =
      typeof request.data?.conversationId === 'string'
        ? request.data.conversationId.trim()
        : '';
    const isVideo = request.data?.isVideo === true;

    if (!conversationId || conversationId.length > 128) {
      throw new HttpsError('invalid-argument', 'Invalid conversation.');
    }
    if (!/^[a-zA-Z0-9_\-]+$/.test(conversationId)) {
      throw new HttpsError('invalid-argument', 'Invalid conversation id.');
    }

    const firestore = getFirestore();
    const convSnap = await firestore
      .doc(`conversations/${conversationId}`)
      .get();
    if (!convSnap.exists) {
      throw new HttpsError('not-found', 'Conversation not found.');
    }

    const participants = convSnap.data()?.participants;
    if (!Array.isArray(participants) || !participants.includes(uid)) {
      throw new HttpsError(
        'permission-denied',
        'Not a participant of this conversation.',
      );
    }

    const otherId = (participants as string[]).find((p) => p !== uid);
    if (otherId) {
      const [a, b] = await Promise.all([
        firestore.doc(`userBlocks/${uid}/blocked/${otherId}`).get(),
        firestore.doc(`userBlocks/${otherId}/blocked/${uid}`).get(),
      ]);
      if (a.exists || b.exists) {
        throw new HttpsError('permission-denied', 'Call not allowed.');
      }
    }

    const apiKey = livekitApiKey.value();
    const apiSecret = livekitApiSecret.value();
    const url = livekitUrl.value();
    if (!apiKey || !apiSecret || !url) {
      throw new HttpsError(
        'failed-precondition',
        'LiveKit is not configured on the server.',
      );
    }

    const roomName = `ojas_${conversationId}`;
    const at = new AccessToken(apiKey, apiSecret, {
      identity: uid,
      ttl: '2h',
      name: uid,
    });
    at.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    const token = await at.toJwt();
    return {
      token,
      url,
      roomName,
      identity: uid,
      isVideo,
    };
  },
);

/** Incoming call FCM when callInvites/{callId} is created. */
export const sendCallInvitePush = onDocumentCreated(
  'conversations/{conversationId}/callInvites/{callId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data() as Record<string, unknown>;
    if (data['status'] !== 'ringing') return;

    const callerId =
      typeof data['callerId'] === 'string' ? data['callerId'] : '';
    const calleeId =
      typeof data['calleeId'] === 'string' ? data['calleeId'] : '';
    const isVideo = data['isVideo'] === true;

    if (!callerId || !calleeId || callerId === calleeId) return;

    const firestore = getFirestore();
    const [a, b] = await Promise.all([
      firestore.doc(`userBlocks/${calleeId}/blocked/${callerId}`).get(),
      firestore.doc(`userBlocks/${callerId}/blocked/${calleeId}`).get(),
    ]);
    if (a.exists || b.exists) return;

    const calleeSnap = await firestore.doc(`users/${calleeId}`).get();
    if (!calleeSnap.exists) return;
    const tokens = tokenListFromUserData(calleeSnap.data() ?? {}).slice(0, 10);
    if (tokens.length === 0) return;

    let title = 'Incoming call';
    try {
      const conv = await firestore
        .doc(`conversations/${event.params.conversationId}`)
        .get();
      const profiles = conv.data()?.participantProfiles;
      if (profiles && typeof profiles === 'object') {
        const p = (profiles as Record<string, unknown>)[callerId];
        if (p && typeof p === 'object') {
          const dn = (p as Record<string, unknown>)['displayName'];
          if (typeof dn === 'string' && dn.trim()) {
            title = dn.trim().slice(0, 80);
          }
        }
      }
    } catch (_) {}

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title,
        body: isVideo ? 'Video call' : 'Audio call',
      },
      data: {
        type: 'call',
        conversationId: event.params.conversationId,
        callId: event.params.callId,
        senderId: callerId,
        isVideo: isVideo ? 'true' : 'false',
      },
      android: {
        priority: 'high',
        notification: {sound: 'default', channelId: 'calls'},
      },
      apns: {
        payload: {aps: {sound: 'default'}},
      },
    });
  },
);
