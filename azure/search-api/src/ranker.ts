import { getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import type { SearchResult } from "./types";

interface InterestContext {
  creatorAffinity: Map<string, number>;
  topicAffinity: Map<string, number>;
  hashtagAffinity: Map<string, number>;
  soundAffinity: Map<string, number>;
  contentTypeAffinity: Map<string, number>;
  negativeAffinity: Map<string, number>;
}

interface CacheEntry {
  expiresAt: number;
  context: InterestContext;
}

const CACHE_TTL_MS = 30_000;
const contextCache = new Map<string, CacheEntry>();

function mapValue(value: unknown): Map<string, number> {
  const output = new Map<string, number>();
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return output;
  }

  for (const [key, raw] of Object.entries(value as Record<string, unknown>)) {
    if (typeof raw === "number" && Number.isFinite(raw)) {
      output.set(key, Math.max(-5, Math.min(5, raw)));
    }
  }
  return output;
}

function emptyContext(): InterestContext {
  return {
    creatorAffinity: new Map(),
    topicAffinity: new Map(),
    hashtagAffinity: new Map(),
    soundAffinity: new Map(),
    contentTypeAffinity: new Map(),
    negativeAffinity: new Map(),
  };
}

export async function loadInterestContext(
  uid: string,
): Promise<InterestContext> {
  if (!uid || uid === "anonymous-dev") {
    return emptyContext();
  }

  const cached = contextCache.get(uid);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.context;
  }

  if (getApps().length === 0) {
    return emptyContext();
  }

  try {
    const snapshot = await getFirestore()
      .collection("users")
      .doc(uid)
      .collection("feedProfile")
      .doc("interest")
      .get();

    const data = snapshot.data() ?? {};
    const context: InterestContext = {
      creatorAffinity: mapValue(data.creatorAffinity),
      topicAffinity: mapValue(data.topicAffinity),
      hashtagAffinity: mapValue(data.hashtagAffinity),
      soundAffinity: mapValue(data.soundAffinity),
      contentTypeAffinity: mapValue(data.contentTypeAffinity),
      negativeAffinity: mapValue(data.negativeAffinity),
    };

    contextCache.set(uid, {
      expiresAt: Date.now() + CACHE_TTL_MS,
      context,
    });

    return context;
  } catch {
    return emptyContext();
  }
}

function affinityForResult(
  result: SearchResult,
  context: InterestContext,
): number {
  let value = 0;

  if (result.creatorId) {
    value += context.creatorAffinity.get(result.creatorId) ?? 0;
  }

  value += context.contentTypeAffinity.get(result.entityType) ?? 0;

  for (const tag of result.tags) {
    value += context.hashtagAffinity.get(tag) ?? 0;
    value += context.negativeAffinity.has(tag)
      ? -(context.negativeAffinity.get(tag) ?? 0)
      : 0;
  }

  const topics = result.extra.topicIds;
  if (Array.isArray(topics)) {
    for (const topic of topics) {
      if (typeof topic === "string") {
        value += context.topicAffinity.get(topic) ?? 0;
      }
    }
  }

  if (result.audioTrackId) {
    value += context.soundAffinity.get(result.audioTrackId) ?? 0;
  }

  return Math.max(-10, Math.min(10, value));
}

export function rerankWithInterest(
  results: SearchResult[],
  context: InterestContext,
): SearchResult[] {
  return results
    .map((result) => {
      const rawAffinity = affinityForResult(result, context);
      const personalScore = rawAffinity / 10;

      return {
        ...result,
        personalScore,
        score: result.score + personalScore * 0.25,
      };
    })
    .sort((a, b) => b.score - a.score);
}

export interface SearchReranker {
  rerank(
    results: SearchResult[],
    context: InterestContext,
  ): SearchResult[];
}

export class RuleBasedSearchReranker implements SearchReranker {
  rerank(
    results: SearchResult[],
    context: InterestContext,
  ): SearchResult[] {
    return rerankWithInterest(results, context);
  }
}
