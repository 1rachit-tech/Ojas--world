import {getFirestore, FieldValue} from 'firebase-admin/firestore';
import {onDocumentWritten} from 'firebase-functions/v2/firestore';

/**
 * Keeps publicProfiles followers/following counts in sync when socialEdges change.
 * Clients write edges; this CF owns the counter mutations for anti-abuse.
 */
export const onSocialEdgeWritten = onDocumentWritten(
  'socialEdges/{edgeId}',
  async (event) => {
    const before = event.data?.before?.data() as Record<string, unknown> | undefined;
    const after = event.data?.after?.data() as Record<string, unknown> | undefined;

    const beforeActive = before?.state === 'active';
    const afterActive = after?.state === 'active';
    if (beforeActive === afterActive) return;

    const followerId =
      (typeof after?.followerId === 'string'
        ? after.followerId
        : typeof before?.followerId === 'string'
          ? before.followerId
          : '') || '';
    const followingId =
      (typeof after?.followingId === 'string'
        ? after.followingId
        : typeof before?.followingId === 'string'
          ? before.followingId
          : '') || '';

    if (!followerId || !followingId || followerId === followingId) return;

    const delta = afterActive && !beforeActive ? 1 : !afterActive && beforeActive ? -1 : 0;
    if (delta === 0) return;

    const db = getFirestore();
    const batch = db.batch();
    const followerRef = db.doc(`publicProfiles/${followerId}`);
    const followingRef = db.doc(`publicProfiles/${followingId}`);

    if (delta > 0) {
      batch.set(
        followerRef,
        {
          following: FieldValue.arrayUnion(followingId),
          followingCount: FieldValue.increment(1),
        },
        {merge: true},
      );
      batch.set(
        followingRef,
        {
          followers: FieldValue.arrayUnion(followerId),
          followersCount: FieldValue.increment(1),
        },
        {merge: true},
      );
    } else {
      batch.set(
        followerRef,
        {
          following: FieldValue.arrayRemove(followingId),
          followingCount: FieldValue.increment(-1),
        },
        {merge: true},
      );
      batch.set(
        followingRef,
        {
          followers: FieldValue.arrayRemove(followerId),
          followersCount: FieldValue.increment(-1),
        },
        {merge: true},
      );
    }

    await batch.commit();
  },
);
