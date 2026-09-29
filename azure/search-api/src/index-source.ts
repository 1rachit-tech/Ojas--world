import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { config } from "./config";
import type { SearchEntityType, SearchIndexDocument } from "./types";

function ensureFirebaseAdmin(): void {
  if (getApps().length > 0) return;

  if (!config.firebaseServiceAccountJson) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT_JSON is required for source-state index refresh.",
    );
  }

  const parsed = JSON.parse(config.firebaseServiceAccountJson);
  initializeApp({
    credential: cert(parsed),
    projectId: config.firebaseProjectId || parsed.project_id,
  });
}

function firestore() {
  ensureFirebaseAdmin();
  return getFirestore();
}

function iso(value: unknown): string | null {
  if (value instanceof Timestamp) return value.toDate().toISOString();

  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString();
  }

  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed.toISOString();
  }

  return null;
}

function list(value: unknown): string[] {
  return Array.isArray(value)
    ? value
        .filter((item): item is string => typeof item === "string")
        .map((item) => item.trim())
        .filter((item) => item.length > 0)
        .slice(0, 50)
    : [];
}

function numberValue(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function profileDocument(
  id: string,
  data: Record<string, unknown>,
): SearchIndexDocument {
  const displayName = typeof data.displayName === "string"
    ? data.displayName.trim()
    : "";
  const ojasId = typeof data.ojasId === "string"
    ? data.ojasId.trim()
    : "";
  const bio = typeof data.bio === "string"
    ? data.bio.trim()
    : "";

  const eligible =
    data.isPrivate !== true &&
    data.visibility !== "private" &&
    data.isBanned !== true &&
    data.isDeleted !== true;

  return {
    id: "person_" + id,
    entityType: "person",
    title: displayName || (ojasId ? "@" + ojasId : "OJAS User"),
    subtitle: ojasId ? "@" + ojasId : "",
    text: [displayName, ojasId, bio].filter(Boolean).join(" "),
    imageUrl: typeof data.photoUrl === "string" ? data.photoUrl : "",
    creatorId: id,
    contentUrl: "",
    audioTrackId: "",
    tags: list(data.tags),
    topicIds: list(data.topicIds),
    location: typeof data.location === "string" ? data.location : "",
    language: typeof data.language === "string" ? data.language : "en",
    region: typeof data.region === "string" ? data.region : "",
    visibility: eligible ? "public" : "restricted",
    eligible,
    safetyStatus: eligible ? "clean" : "restricted",
    isLive: false,
    views: 0,
    likes: numberValue(data.likesCount),
    saves: 0,
    followers: numberValue(data.followersCount),
    posts: numberValue(data.postsCount),
    algorithmScore: numberValue(data.algorithmScore),
    trendScore: numberValue(data.trendScore),
    createdAt: iso(data.createdAt),
    updatedAt: iso(data.updatedAt),
    searchIndexVersion: 2,
  };
}

function contentDocument(
  id: string,
  data: Record<string, unknown>,
): SearchIndexDocument {
  const caption = typeof data.caption === "string"
    ? data.caption.trim()
    : "";
  const creatorId = typeof data.creatorId === "string"
    ? data.creatorId.trim()
    : "";
  const visibility = typeof data.visibility === "string"
    ? data.visibility
    : "public";

  const eligible =
    data.isDeleted !== true &&
    data.isBanned !== true &&
    data.searchEligible !== false &&
    visibility === "public";

  return {
    id: "content_" + id,
    entityType: "content",
    title: caption || "OJAS Show",
    subtitle: creatorId,
    text: [
      caption,
      ...list(data.hashtags),
      typeof data.audioTrackId === "string" ? data.audioTrackId : "",
    ].filter(Boolean).join(" "),
    imageUrl: typeof data.thumbnailUrl === "string"
      ? data.thumbnailUrl
      : "",
    creatorId,
    contentUrl:
      typeof data.hlsUrl === "string"
        ? data.hlsUrl
        : (typeof data.videoUrl === "string" ? data.videoUrl : ""),
    audioTrackId: typeof data.audioTrackId === "string"
      ? data.audioTrackId
      : "",
    tags: list(data.hashtags),
    topicIds: list(data.topicIds),
    location: typeof data.location === "string" ? data.location : "",
    language: typeof data.language === "string" ? data.language : "en",
    region: typeof data.region === "string" ? data.region : "",
    visibility: eligible ? "public" : "restricted",
    eligible,
    safetyStatus: eligible ? "clean" : "restricted",
    isLive: data.isLive === true,
    views: numberValue(data.views),
    likes: numberValue(data.likes ?? data.likesCount),
    saves: numberValue(data.saves),
    followers: 0,
    posts: 0,
    algorithmScore: numberValue(data.algorithmScore),
    trendScore: numberValue(data.trendScore),
    createdAt: iso(data.createdAt),
    updatedAt: iso(data.updatedAt),
    searchIndexVersion: 2,
  };
}

function sourceCollection(entityType: SearchEntityType):
    "publicProfiles" | "reels" | null {
  if (entityType === "person") return "publicProfiles";
  if (entityType === "content") return "reels";
  return null;
}

/**
 * Rebuild the entity from the current Firestore source of truth.
 *
 * This intentionally ignores the snapshot carried by a retried queue event
 * for person/content entities. A retry can contain an old Firestore snapshot;
 * reading the current source state prevents that stale snapshot from restoring
 * private/deleted/older content to Azure AI Search.
 */
export async function refreshCurrentSourceDocument(
  entityType: SearchEntityType,
  entityId: string,
): Promise<SearchIndexDocument | null | undefined> {
  const collection = sourceCollection(entityType);
  if (!collection) return undefined;

  const snapshot = await firestore().collection(collection).doc(entityId).get();

  if (!snapshot.exists) return null;

  const data = snapshot.data() as Record<string, unknown>;

  return entityType === "person"
    ? profileDocument(entityId, data)
    : contentDocument(entityId, data);
}
