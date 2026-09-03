import {initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {setGlobalOptions} from 'firebase-functions/v2';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';

initializeApp();

setGlobalOptions({
  region: 'asia-south1',
  maxInstances: 3,
  minInstances: 0,
});

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
  const recent = (senderMessageTimes.get(senderId) ?? [])
    .filter((timestamp) => now - timestamp < RATE_WINDOW_MS);

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
    return rawTokens.filter((token): token is string =>
      typeof token === 'string' && token.trim().length > 0,
    );
  }

  return [];
}

export const sendMessagePush = onDocumentCreated(
  'conversations/{conversationId}/messages/{messageId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const message = snapshot.data() as MessageData;
    const senderId = typeof message.senderId === 'string'
      ? message.senderId
      : '';

    if (!senderId || message.isDeleted === true) {
      return;
    }

    if (isRateLimited(senderId)) {
      console.warn(`Skipping push for rate-limited sender ${senderId}.`);
      return;
    }

    const firestore = getFirestore();
    const conversationSnapshot = await firestore
      .doc(`conversations/${event.params.conversationId}`)
      .get();

    if (!conversationSnapshot.exists) {
      return;
    }

    const conversation = conversationSnapshot.data() as ConversationData;
    const receiverId = receiverIdFor(conversation.participants, senderId);

    if (!receiverId) {
      return;
    }

    const receiverSnapshot = await firestore
      .doc(`users/${receiverId}`)
      .get();

    if (!receiverSnapshot.exists) {
      return;
    }

    const receiverData = receiverSnapshot.data() ?? {};
    const tokens = tokenListFromUserData(receiverData);

    if (tokens.length === 0) {
      return;
    }

    const senderName = profileName(conversation, senderId);
    const messageType = message.type === 'image' ? 'image' : 'text';
    const text = typeof message.text === 'string' ? message.text.trim() : '';
    const body = messageType === 'image'
      ? (text.length > 0 ? `📷 ${text}` : '📷 Photo')
      : (text.length > 0 ? text : 'New message');

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
        notification: {
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
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

    if (invalidTokens.length === 0) {
      return;
    }

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
