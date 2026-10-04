import {getFirestore, FieldValue} from 'firebase-admin/firestore';
import {onDocumentWritten} from 'firebase-functions/v2/firestore';

/**
 * Private-follow accept cannot update the requester profile from the client.
 * Public follows already update both counts in EngagementService, so this
 * function only fills the requester following side for follow_request edges.
 */
export const onSocialEdgeWritten = onDocumentWritten(
  'socialEdges/{edgeId}',
  async (event) => {
    const before = event.data?.before?.data() as Record<string, unknown> | undefined;
    const after = event.data?.after?.data() as Record<string, unknown> | undefined;

    const beforeActive = before?.state === 'active';
    const afterActive = after?.state === 'active';
    if (beforeActive || !afterActive) return;
    if (after?.source !== 'follow_request') return;

    const followerId = typeof after.followerId === 'string' ? after.followerId : '';
    const followingId = typeof after.followingId === 'string' ? after.followingId : '';
    if (!followerId || !followingId || followerId === followingId) return;

    const db = getFirestore();
    await db.doc(`publicProfiles/${followerId}`).set(
      {
        following: FieldValue.arrayUnion(followingId),
        followingCount: FieldValue.increment(1),
      },
      {merge: true},
    );
  },
);
