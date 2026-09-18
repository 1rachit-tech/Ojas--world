import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { app, type InvocationContext } from "@azure/functions";
import { config } from "./config";
import { deleteDocuments, upsertDocuments } from "./search-client";
import type { SearchIndexDocument } from "./types";

function ensureFirebaseAdmin() {
  if (getApps().length > 0) return;

  if (!config.firebaseServiceAccountJson) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON is not configured.");
  }

  const parsed = JSON.parse(config.firebaseServiceAccountJson);
  initializeApp({
    credential: cert(parsed),
    projectId: config.firebaseProjectId || parsed.project_id,
  });
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
    ? value.filter((item): item is string => typeof item === "string")
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
    updatedAt: iso(data.updatedAt) || new Date().toISOString(),
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

  const hashtags = list(data.hashtags);
  const topicIds = list(data.topicIds);

  return {
    id: "content_" + id,
    entityType: "content",
    title: caption || "OJAS Show",
    subtitle: creatorId,
    text: [caption, ...hashtags, typeof data.audioTrackId === "string" ? data.audioTrackId : ""]
      .filter(Boolean)
      .join(" "),
    imageUrl: typeof data.thumbnailUrl === "string" ? data.thumbnailUrl : "",
    creatorId,
    contentUrl: typeof data.hlsUrl === "string"
      ? data.hlsUrl
      : (typeof data.videoUrl === "string" ? data.videoUrl : ""),
    audioTrackId: typeof data.audioTrackId === "string"
      ? data.audioTrackId
      : "",
    tags: hashtags,
    topicIds,
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
    updatedAt: iso(data.updatedAt) || new Date().toISOString(),
    searchIndexVersion: 2,
  };
}

async function scanCollection(
  collection: "publicProfiles" | "reels",
  build: (id: string, data: Record<string, unknown>) => SearchIndexDocument,
  activeIds: Set<string>,
  context: InvocationContext,
): Promise<number> {
  ensureFirebaseAdmin();

  let lastId = "";
  let count = 0;

  while (count < config.reconcileMaxIndexDocs) {
    let query = getFirestore()
      .collection(collection)
      .orderBy("__name__")
      .limit(config.reconcileBatchSize);

    if (lastId) {
      query = query.startAfter(lastId);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch: SearchIndexDocument[] = [];

    for (const doc of snapshot.docs) {
      lastId = doc.id;
      activeIds.add(
        collection === "publicProfiles"
          ? "person_" + doc.id
          : "content_" + doc.id,
      );
      batch.push(
        build(
          doc.id,
          doc.data() as Record<string, unknown>,
        ),
      );
    }

    await upsertDocuments(batch);
    count += batch.length;

    context.info(
      "OJAS Search reconciliation batch: " +
        collection +
        " " +
        batch.length +
        " docs",
    );

    if (snapshot.docs.length < config.reconcileBatchSize) break;
  }

  return count;
}

export async function runSearchReconciliation(
  context: InvocationContext,
): Promise<void> {
  if (!config.reconcileEnabled) {
    context.info("OJAS Search reconciliation is disabled.");
    return;
  }

  ensureFirebaseAdmin();
  const activeIds = new Set<string>();

  const profiles = await scanCollection(
    "publicProfiles",
    profileDocument,
    activeIds,
    context,
  );

  const reels = await scanCollection(
    "reels",
    contentDocument,
    activeIds,
    context,
  );

  context.info(
    "OJAS Search reconciliation indexed " +
      profiles +
      " profiles and " +
      reels +
      " Shows.",
  );

  // Deletions are primarily handled by the event path. A future full
  // stale-document sweep can be enabled once corpus size requires it.
}

app.timer("searchReconciliation", {
  schedule: config.reconcileCron,
  runOnStartup: false,
  handler: async (_timer, context) => {
    await runSearchReconciliation(context);
  },
});
