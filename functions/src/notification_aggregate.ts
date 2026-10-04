import {getFirestore, FieldValue} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';

/**
 * Aggregates like/comment activity into batched notifications.
 * Example: "A, B and 12 others liked your post"
 */
export const aggregateEngagementNotifications = onDocumentCreated(
  'users/{userId}/activity/{activityId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() as Record<string, unknown>;
    const action = typeof data['action'] === 'string' ? data['action'] : '';
    const targetType = typeof data['targetType'] === 'string' ? data['targetType'] : '';
    const targetId = typeof data['targetId'] === 'string' ? data['targetId'] : '';
    const actorId = event.params.userId;

    if (!targetId || actorId.length === 0) return;

    // Only positive social signals that should notify content owners
    const notifiable = new Set(['like', 'comment', 'reply', 'comment_like', 'follow', 'follow_request']);
    if (!notifiable.has(action)) return;

    const firestore = getFirestore();

    // Resolve recipient (content owner or profile target)
    let recipientId = '';
    if (targetType === 'content') {
      const reel = await firestore.doc(`reels/${targetId}`).get();
      recipientId = (reel.data()?.creatorId as string) || '';
    } else if (targetType === 'profile') {
      recipientId = targetId;
    } else if (targetType === 'comment') {
      const meta = data['metadata'];
      const contentId =
        meta && typeof meta === 'object'
          ? ((meta as Record<string, unknown>)['contentId'] as string) || ''
          : '';
      if (contentId) {
        const comment = await firestore
          .doc(`reels/${contentId}/comments/${targetId}`)
          .get();
        recipientId = (comment.data()?.authorId as string) || '';
      }
    }

    if (!recipientId || recipientId === actorId) return;

    // Rate window bucket: 10-minute aggregation key
    const bucket = Math.floor(Date.now() / (10 * 60 * 1000));
    const aggId = `${recipientId}_${action}_${targetId}_${bucket}`;
    const aggRef = firestore.collection('notificationAggregates').doc(aggId);

    await firestore.runTransaction(async (tx) => {
      const existing = await tx.get(aggRef);
      if (!existing.exists) {
        tx.set(aggRef, {
          recipientId,
          action,
          targetId,
          targetType,
          actorIds: [actorId],
          count: 1,
          bucket,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          pushed: false,
        });
        return;
      }
      const actors = (existing.data()?.actorIds as string[]) || [];
      if (actors.includes(actorId)) return;
      actors.push(actorId);
      // Cap stored actors for cost
      const trimmed = actors.slice(-20);
      tx.update(aggRef, {
        actorIds: trimmed,
        count: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    // Debounced push: only first event in bucket sends immediately;
    // subsequent stay aggregated for client inbox.
    const agg = await aggRef.get();
    const aggData = agg.data();
    if (!aggData || aggData.pushed === true) return;
    if ((aggData.count as number) > 1) return;

    const userSnap = await firestore.doc(`users/${recipientId}`).get();
    const tokensRaw = userSnap.data()?.fcmTokens;
    let tokens: string[] = [];
    if (tokensRaw && typeof tokensRaw === 'object' && !Array.isArray(tokensRaw)) {
      tokens = Object.keys(tokensRaw).filter((t) => t.trim().length > 0).slice(0, 10);
    }
    if (tokens.length === 0) return;

    let actorName = 'Someone';
    try {
      const p = await firestore.doc(`publicProfiles/${actorId}`).get();
      const dn = p.data()?.displayName;
      if (typeof dn === 'string' && dn.trim()) actorName = dn.trim().slice(0, 40);
    } catch (_) {}

    const bodyByAction: Record<string, string> = {
      like: `${actorName} liked your post`,
      comment: `${actorName} commented on your post`,
      reply: `${actorName} replied to a comment`,
      comment_like: `${actorName} liked your comment`,
      follow: `${actorName} started following you`,
      follow_request: `${actorName} requested to follow you`,
    };

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: 'OJAS',
        body: bodyByAction[action] || `${actorName} interacted with you`,
      },
      data: {
        type: 'social',
        action,
        targetId,
        targetType,
        actorId,
      },
      android: {priority: 'high'},
    });

    await aggRef.set({pushed: true}, {merge: true});
  },
);
