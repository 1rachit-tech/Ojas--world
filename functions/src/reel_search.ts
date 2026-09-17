import {getFirestore} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';

type SearchRequest = {auth?: {uid?: string} | null; data?: unknown};
const MAX_RESULTS = 30;

function tokensFromQuery(value: unknown): string[] {
  if (typeof value !== 'string') return [];
  return Array.from(new Set(value.toLowerCase().replace(/[^a-z0-9_#@\s]/g, ' ').split(/\s+/).map((token) => token.replace(/^#/, '').replace(/^@/, '')).filter((token) => token.length >= 2 && token.length <= 64))).slice(0, 8);
}

export async function searchPublicReels(request: SearchRequest) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Please sign in again.');
  const data = request.data && typeof request.data === 'object' && !Array.isArray(request.data) ? request.data as Record<string, unknown> : {};
  const tokens = tokensFromQuery(data.query);
  if (tokens.length === 0) return {results: []};

  const snapshot = await getFirestore().collection('searchIndex').where('tokens', 'array-contains', tokens[0]).limit(MAX_RESULTS).get();
  const results = snapshot.docs
    .map((doc) => doc.data())
    .filter((item) => item.moderationStatus === 'approved' && item.visibility === 'public')
    .filter((item) => {
      const indexed = Array.isArray(item.tokens) ? item.tokens.filter((token): token is string => typeof token === 'string') : [];
      return tokens.every((token) => indexed.includes(token));
    })
    .map((item) => ({
      postId: typeof item.postId === 'string' ? item.postId : '',
      creatorId: typeof item.creatorId === 'string' ? item.creatorId : '',
      caption: typeof item.caption === 'string' ? item.caption : '',
    }));

  return {results: results.slice(0, MAX_RESULTS)};
}
