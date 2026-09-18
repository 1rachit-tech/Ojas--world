import {createHash} from 'crypto';
import {getFirestore} from 'firebase-admin/firestore';
import {onDocumentWritten} from 'firebase-functions/v2/firestore';

type SearchEntity = 'person' | 'content';

function db() {
  return getFirestore();
}

const synonymMap: Record<string, string[]> = {
  'गाना': ['song', 'music', 'audio'],
  'गाने': ['songs', 'song', 'music', 'audio'],
  'गीत': ['song', 'songs', 'music'],
  'संगीत': ['music', 'songs'],
  'बारिश': ['barish', 'baarish', 'rain'],
  'बारिस': ['barish', 'baarish', 'rain'],
  'क्रिकेट': ['cricket', 'kriket'],
  'प्यार': ['love', 'romance'],
  'प्रेम': ['love', 'romance'],
  'नृत्य': ['dance'],
  'डांस': ['dance'],
  'यात्रा': ['travel', 'trip'],
  'song': ['गाना', 'music'],
  'songs': ['गाने', 'music'],
  'rain': ['बारिश', 'barish', 'baarish'],
  'cricket': ['क्रिकेट'],
  'music': ['संगीत', 'गाना'],
};

const consonants: Record<string, string> = {
  'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ng',
  'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'ny',
  'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n',
  'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
  'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm',
  'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'श': 'sh',
  'ष': 'sh', 'स': 's', 'ह': 'h', 'ळ': 'l',
};
const matras: Record<string, string> = {
  'ा': 'aa', 'ि': 'i', 'ी': 'ee', 'ु': 'u', 'ू': 'oo',
  'ृ': 'ri', 'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au',
  'ं': 'n', 'ँ': 'n', 'ः': 'h', '्': '',
};
const vowels: Record<string, string> = {
  'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u',
  'ऊ': 'oo', 'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai', 'ओ': 'o',
  'औ': 'au',
};

function normalize(value: string): string {
  return value
    .normalize('NFKC')
    .trim()
    .toLowerCase()
    .replace(/[\u200b-\u200d\ufeff]/g, ' ')
    .replace(/\s+/g, ' ');
}

function tokenize(value: string): string[] {
  return normalize(value)
    .split(/\s+/)
    .map((token) => token.replace(/^[.,!?;:()[\]{}"']+|[.,!?;:()[\]{}"']+$/g, ''))
    .filter((token) => token.length > 0)
    .slice(0, 80);
}

function transliterate(value: string): string {
  const chars = Array.from(value);
  let output = '';

  for (let i = 0; i < chars.length; i += 1) {
    const char = chars[i];
    if (consonants[char]) {
      let next = consonants[char];
      const nextChar = chars[i + 1];
      if (!nextChar || !matras[nextChar]) next += 'a';
      output += next;
      continue;
    }
    if (matras[char]) {
      output += matras[char];
      continue;
    }
    if (vowels[char]) {
      output += vowels[char];
      continue;
    }
    output += char;
  }

  return output
    .replace(/[^a-z0-9_#@]+/g, '')
    .replace(/aaai/g, 'ai')
    .replace(/aau/g, 'au')
    .replace(/aaa/g, 'aa');
}

function detectLanguage(value: string): string {
  let devanagari = 0;
  let latin = 0;
  let regional = 0;

  for (const rune of value) {
    const code = rune.codePointAt(0) ?? 0;
    if (code >= 0x0900 && code <= 0x097f) {
      devanagari += 1;
    } else if (
      (code >= 0x0041 && code <= 0x007a) ||
      (code >= 0x00c0 && code <= 0x024f)
    ) {
      latin += 1;
    } else if (
      (code >= 0x0980 && code <= 0x0cff) ||
      (code >= 0x0d00 && code <= 0x0d7f)
    ) {
      regional += 1;
    }
  }

  if (devanagari > 0 && latin > 0) return 'hi-Latn-mixed';
  if (devanagari > 0) return 'hi';
  if (regional > 0) return 'regional';
  return 'en';
}

function buildIndexTerms(text: string): {
  tokens: string[];
  prefixes: string[];
} {
  const baseTokens = tokenize(text);
  const expanded = new Set<string>();

  for (const token of baseTokens) {
    expanded.add(token);
    const romanized = transliterate(token);
    if (romanized) expanded.add(romanized);
    for (const synonym of synonymMap[token] ?? []) {
      expanded.add(normalize(synonym));
    }
  }

  const tokens = Array.from(expanded).slice(0, 180);
  const prefixes = new Set<string>();

  for (const token of tokens) {
    const clean = token.replace(/^[@#]/, '');
    if (!clean) continue;
    const max = Math.min(clean.length, 12);
    for (let length = 1; length <= max; length += 1) {
      prefixes.add(clean.slice(0, length));
    }
  }

  return {
    tokens,
    prefixes: Array.from(prefixes).slice(0, 180),
  };
}

function extractHashtags(caption: string): string[] {
  const values: string[] = [];
  for (const match of caption.matchAll(/#[A-Za-z0-9_\u0900-\u097F]+/gu)) {
    if (match[0]) values.push(match[0].toLowerCase());
  }
  return Array.from(new Set(values)).slice(0, 50);
}

function shardFor(id: string): string {
  return createHash('sha1').update(id).digest('hex').slice(0, 2);
}

function safeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function numberValue(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

const AZURE_SEARCH_INGEST_URL = (process.env.AZURE_SEARCH_INGEST_URL ?? '')
  .trim()
  .replace(/\\/$/, '');
const AZURE_SEARCH_INGEST_SECRET = (process.env.AZURE_SEARCH_INGEST_SECRET ?? '').trim();
const MIRROR_FIRESTORE_SEARCH_INDEX =
  (process.env.SEARCH_INDEX_MIRROR_FIRESTORE ?? 'false').toLowerCase() === 'true';

function isoDate(value: unknown): string | null {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString();
  }

  if (value && typeof value === 'object') {
    const maybeTimestamp = value as {toDate?: unknown};
    if (typeof maybeTimestamp.toDate === 'function') {
      const date = maybeTimestamp.toDate() as Date;
      if (date instanceof Date && !Number.isNaN(date.getTime())) {
        return date.toISOString();
      }
    }
  }

  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed.toISOString();
  }

  return null;
}

function toAzureDocument(
  entityType: SearchEntity,
  entityId: string,
  payload: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: entityType + '_' + entityId,
    entityType,
    title: safeString(payload.title),
    subtitle: safeString(payload.subtitle),
    text: safeString(payload.text),
    imageUrl: safeString(payload.imageUrl),
    creatorId: safeString(payload.creatorId),
    contentUrl: safeString(payload.contentUrl),
    audioTrackId: safeString(payload.audioTrackId),
    tags: Array.isArray(payload.tags)
      ? payload.tags.filter((value): value is string => typeof value === 'string')
      : [],
    topicIds: Array.isArray(payload.topicIds)
      ? payload.topicIds.filter((value): value is string => typeof value === 'string')
      : [],
    location: safeString(payload.location),
    language: safeString(payload.language),
    region: safeString(payload.region),
    visibility: safeString(payload.visibility) || 'public',
    eligible: payload.eligible !== false,
    safetyStatus: safeString(payload.safetyStatus) || 'clean',
    isLive: payload.isLive === true,
    views: numberValue(payload.views),
    likes: numberValue(payload.likes),
    saves: numberValue(payload.saves),
    followers: numberValue(payload.followers),
    posts: numberValue(payload.posts),
    algorithmScore: numberValue(payload.algorithmScore),
    trendScore: numberValue(payload.trendScore),
    createdAt: isoDate(payload.createdAt),
    updatedAt: isoDate(payload.updatedAt) ?? new Date().toISOString(),
  };
}

function eventId(
  operation: string,
  entityType: SearchEntity,
  entityId: string,
  version: number,
): string {
  return createHash('sha1')
    .update(operation + '|' + entityType + '|' + entityId + '|' + version)
    .digest('hex');
}

async function publishSearchIndexEvent(
  operation: 'upsert' | 'delete',
  entityType: SearchEntity,
  entityId: string,
  payload?: Record<string, unknown>,
): Promise<void> {
  const document = payload
    ? toAzureDocument(entityType, entityId, payload)
    : undefined;

  if (AZURE_SEARCH_INGEST_URL) {
    if (!AZURE_SEARCH_INGEST_SECRET) {
      throw new Error(
        'AZURE_SEARCH_INGEST_SECRET is required when Azure Search ingest is enabled.',
      );
    }

    const event = {
      eventId: eventId(operation, entityType, entityId, 2),
      operation,
      entityType,
      entityId,
      version: 2,
      occurredAt: new Date().toISOString(),
      ...(document ? {document} : {}),
    };

    const response = await fetch(
      AZURE_SEARCH_INGEST_URL + '/v1/search/index/events',
      {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-ojas-index-secret': AZURE_SEARCH_INGEST_SECRET,
        },
        body: JSON.stringify(event),
      },
    );

    if (!response.ok) {
      throw new Error(
        'Azure Search ingest returned ' +
          response.status +
          ': ' +
          (await response.text()).slice(0, 500),
      );
    }
  }

  const shouldMirror =
    !AZURE_SEARCH_INGEST_URL || MIRROR_FIRESTORE_SEARCH_INDEX;

  const ref = db()
    .collection('searchIndex')
    .doc(entityType + '_' + entityId);

  if (operation === 'delete') {
    await ref.delete();
    return;
  }

  if (shouldMirror) {
    await ref.set(
      {
        ...(payload ?? {}),
        entityId,
        entityType,
        updatedAt: new Date().toISOString(),
      },
      {merge: true},
    );
  }
}


async function writeProfileIndex(
  userId: string,
  data: Record<string, unknown>,
): Promise<void> {
  const displayName = safeString(data.displayName);
  const ojasId = safeString(data.ojasId);
  const bio = safeString(data.bio);
  const category = safeString(data.creatorCategory);
  const text = [displayName, ojasId, bio, category].filter(Boolean).join(' ');
  const terms = buildIndexTerms(text);
  const isPrivate = data.isPrivate === true || data.visibility === 'private';

  const payload = {
    entityId: userId,
    entityType: 'person' as SearchEntity,
    title: displayName || (ojasId ? '@' + ojasId : 'OJAS User'),
    subtitle: ojasId ? '@' + ojasId : '',
    text,
    imageUrl: safeString(data.photoUrl),
    creatorId: userId,
    contentUrl: '',
    audioTrackId: '',
    tokens: terms.tokens,
    prefixes: terms.prefixes,
    tags: [],
    createdAt: isoDate(data.createdAt) ?? new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    followers: numberValue(data.followersCount),
    posts: numberValue(data.postsCount),
    likes: numberValue(data.likesCount),
    views: 0,
    saves: 0,
    algorithmScore: 0,
    trendScore: 0,
    language: detectLanguage(text),
    region: safeString(data.region),
    eligible: !isPrivate && data.isBanned !== true && data.isDeleted !== true,
    visibility: isPrivate ? 'private' : 'public',
    shardKey: shardFor(userId),
    sourceCollection: 'publicProfiles',
    sourceId: userId,
    searchIndexVersion: 2,
  };

  await publishSearchIndexEvent('upsert', 'person', userId, payload);
}

async function writeReelIndex(
  reelId: string,
  data: Record<string, unknown>,
): Promise<void> {
  const caption = safeString(data.caption);
  const audioTrackId = safeString(data.audioTrackId);
  const hashtags = extractHashtags(caption);
  const rawText = [caption, audioTrackId, ...hashtags].filter(Boolean).join(' ');
  const terms = buildIndexTerms(rawText);

  const visibility = safeString(data.visibility);
  const eligible =
    data.isDeleted !== true &&
    data.isBanned !== true &&
    data.searchEligible !== false &&
    visibility !== 'private';

  await publishSearchIndexEvent(
    'upsert',
    'content',
    reelId,
    {
      entityId: reelId,
      entityType: 'content',
      title: caption || 'OJAS Show',
      subtitle: safeString(data.creatorId),
      text: rawText,
      imageUrl: safeString(data.thumbnailUrl),
      creatorId: safeString(data.creatorId),
      contentUrl: safeString(data.hlsUrl) || safeString(data.videoUrl),
      audioTrackId,
      tokens: terms.tokens,
      prefixes: terms.prefixes,
      tags: hashtags,
      createdAt: isoDate(data.createdAt) ?? new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      views: numberValue(data.views),
      likes: numberValue(data.likes ?? data.likesCount),
      saves: numberValue(data.saves),
      followers: 0,
      posts: 0,
      algorithmScore: numberValue(data.algorithmScore),
      trendScore: numberValue(data.trendScore),
      language: detectLanguage(rawText),
      region: safeString(data.region),
      location: typeof data.location === 'string' ? data.location.trim() : '',
      topicIds: Array.isArray(data.topicIds)
        ? data.topicIds
            .filter((value): value is string => typeof value === 'string')
            .map((value) => value.trim())
            .filter((value) => value.length > 0)
            .slice(0, 30)
        : [],
      isLive: data.isLive === true,
      eligible,
      visibility: eligible ? 'public' : 'restricted',
      safetyStatus:
        safeString(data.safetyStatus) ||
        (eligible ? 'clean' : 'restricted'),
      shardKey: shardFor(reelId),
      contentType: 'video',
      sourceCollection: 'reels',
      sourceId: reelId,
      searchIndexVersion: 2,
    },
  );
}

export const syncPublicProfileSearchIndex = onDocumentWritten(
  'publicProfiles/{userId}',
  async (event) => {
    const after = event.data?.after;
    const userId = event.params.userId;
    if (!after || !after.exists) {
      await publishSearchIndexEvent('delete', 'person', userId);
      return;
    }
    await writeProfileIndex(userId, after.data() ?? {});
  },
);

export const syncReelSearchIndex = onDocumentWritten(
  'reels/{reelId}',
  async (event) => {
    const after = event.data?.after;
    const reelId = event.params.reelId;
    if (!after || !after.exists) {
      await publishSearchIndexEvent('delete', 'content', reelId);
      return;
    }
    await writeReelIndex(reelId, after.data() ?? {});
  },
);
