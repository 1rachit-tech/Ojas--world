import {getFirestore} from 'firebase-admin/firestore';

const MAX_RESULTS = 30;

function tokensFromQuery(value: unknown): string[] {
  if (typeof value !== 'string') return [];
  return Array.from(new Set(
    value
      .toLowerCase()
      .replace(/[^a-z0-9_#@\s]/g, ' ')
      .split(/\s+/)
      .map((token) => token.replace(/^#/, '').replace(/^@/, ''))
      .filter((token) => token.length >= 2 && token.length <= 64),
  )).slice(0, 8);
}

export async function searchPublicReels(request: {auth?: {uid?: string} | null; data?: Record<string, unknown>}) {
  if (!request.auth?.uid) throw new Error('unauthenticated');
  const tokens = tokensFromQuery(request.data?.query);
  if (tokens.length === 0) return {results: []};

  const snapshot = await getFirestore()
    .collection('searchIndex')
    .where('moderationStatus', '==', 'approved')
    .where('visibility', '==', 'public')
    .where('tokens', 'array-contains', tokens[0])
    .orderBy('createdAt', 'desc')
    .limit(MAX_RESULTS)
    .get();

  const results = snapshot.docs
    .map((doc) => doc.data())
    .filter((item) => {
      const indexed = Array.isArray(item.tokens) ? item.tokens.filter((token): token is string => typeof token === 'string') : [];
      return tokens.every((token) => indexed.includes(token));
    })
    .slice(0, MAX_RESULTS)
    .map((item) => ({
      postId: typeof item.postId === 'string' ? item.postId : '',
      creatorId: typeof item.creatorId === 'string' ? item.creatorId : '',
      caption: typeof item.caption === 'string' ? item.caption : '',
    }));

  return {results};
}
