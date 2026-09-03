import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {setGlobalOptions} from 'firebase-functions/v2';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';

initializeApp();

setGlobalOptions({
  region: 'asia-south1',
  maxInstances: 3,
});

interface ConversationData {
  participants?: unknown;
  participantProfiles?: unknown;
}

interface MessageData {
  senderId?: unknown;
  conversationId?: unknown;
  text?: unknown;
  type?: unknown;
}

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
        return displayName.trim();
      }
    }
  }
  return 'OJAS user';
}

function receiverIdFor(
  participants: unknown,
  senderId: string,
): string | null {
  if (!Array.isArray(participants)) {
    return null;
  }

  for (const participant of participants) {
    if (typeof participant === 'string' && participant !== senderId) {
      return participant;
    }
  }

  return null;
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

    if (!senderId) {
      return;
    }

    const conversationSnapshot = await getFirestore()
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

    const receiverSnapshot = await getFirestore()
      .doc(`users/${receiverId}`)
      .get();

    if (!receiverSnapshot.exists) {
      return;
    }

    const receiverData = receiverSnapshot.data() ?? {};
    const rawTokens = receiverData['fcmTokens'];
    const tokens = Array.isArray(rawTokens)
      ? rawTokens.filter((token): token is string =>
          typeof token === 'string' && token.trim().length > 0,
        )
      : [];

    if (tokens.length === 0) {
      return;
    }

    const senderName = profileName(conversation, senderId);
    const messageType = message.type === 'image' ? 'image' : 'text';
    const text = typeof message.text === 'string' ? message.text.trim() : '';
    const body = messageType === 'image'
      ? (text.isNotEmpty ? `📷 ${text}` : '📷 Photo')
      : (text.isNotEmpty ? text : 'New message');

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: senderName,
        body,
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
          channelId: 'ojas_messages',
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

    if (invalidTokens.length > 0) {
      await getFirestore().doc(`users/${receiverId}`).update({
        fcmTokens: invalidTokens.length === tokens.length
          ? []
          : tokens.filter((token) => !invalidTokens.includes(token)),
      });
    }
  },
);
