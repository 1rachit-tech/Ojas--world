export type SearchEventOperation = "upsert" | "delete";
import type { SearchIndexDocument } from "./types";

export type SearchEventEntity =
  | "person"
  | "content"
  | "hashtag"
  | "sound"
  | "topic"
  | "place"
  | "live"
  | "generic";


function isFiniteNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) &&
    value.every((item) => typeof item === "string");
}

function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}

function isSearchIndexDocument(
  input: unknown,
): input is SearchIndexDocument {
  if (
    !input ||
    typeof input !== "object" ||
    Array.isArray(input)
  ) {
    return false;
  }

  const value = input as Record<string, unknown>;

  return (
    typeof value.id === "string" &&
    typeof value.entityType === "string" &&
    typeof value.title === "string" &&
    typeof value.subtitle === "string" &&
    typeof value.text === "string" &&
    typeof value.imageUrl === "string" &&
    typeof value.creatorId === "string" &&
    typeof value.contentUrl === "string" &&
    typeof value.audioTrackId === "string" &&
    isStringArray(value.tags) &&
    isStringArray(value.topicIds) &&
    typeof value.location === "string" &&
    typeof value.language === "string" &&
    typeof value.region === "string" &&
    typeof value.visibility === "string" &&
    typeof value.eligible === "boolean" &&
    typeof value.safetyStatus === "string" &&
    typeof value.isLive === "boolean" &&
    isFiniteNumber(value.views) &&
    isFiniteNumber(value.likes) &&
    isFiniteNumber(value.saves) &&
    isFiniteNumber(value.followers) &&
    isFiniteNumber(value.posts) &&
    isFiniteNumber(value.algorithmScore) &&
    isFiniteNumber(value.trendScore) &&
    isNullableString(value.createdAt) &&
    isNullableString(value.updatedAt) &&
    (
      value.searchIndexVersion === undefined ||
      (
        typeof value.searchIndexVersion === "number" &&
        Number.isSafeInteger(value.searchIndexVersion) &&
        value.searchIndexVersion > 0
      )
    ) &&
    (value.textVector === undefined ||
      (Array.isArray(value.textVector) &&
        value.textVector.every((item) => isFiniteNumber(item))))
  );
}

const ENTITY_TYPES = new Set<SearchEventEntity>([
  "person",
  "content",
  "hashtag",
  "sound",
  "topic",
  "place",
  "live",
  "generic",
]);

export class InvalidSearchCursorError extends Error {
  constructor() {
    super("Invalid search cursor.");
    this.name = "InvalidSearchCursorError";
  }
}

export function decodeSearchCursor(cursor: string | null | undefined): number {
  if (!cursor) return 0;
  if (cursor.length > 512) throw new InvalidSearchCursorError();

  try {
    const json = Buffer.from(cursor, "base64url").toString("utf8");
    const value = JSON.parse(json) as {
      version?: unknown;
      offset?: unknown;
    };

    if (
      value.version !== 1 ||
      typeof value.offset !== "number" ||
      !Number.isSafeInteger(value.offset) ||
      value.offset < 0 ||
      value.offset > 100000
    ) {
      throw new InvalidSearchCursorError();
    }

    return value.offset;
  } catch (error) {
    if (error instanceof InvalidSearchCursorError) throw error;
    throw new InvalidSearchCursorError();
  }
}

export function encodeSearchCursor(offset: number): string {
  if (
    !Number.isSafeInteger(offset) ||
    offset < 0 ||
    offset > 100000
  ) {
    throw new RangeError("Invalid search cursor offset.");
  }

  return Buffer.from(
    JSON.stringify({version: 1, offset}),
    "utf8",
  ).toString("base64url");
}

export function validateSearchIndexEvent(
  event: unknown,
): {
  eventId: string;
  operation: SearchEventOperation;
  entityType: SearchEventEntity;
  entityId: string;
  version: number;
  occurredAt: string;
  document?: SearchIndexDocument;
} | null {
  if (!event || typeof event !== "object" || Array.isArray(event)) {
    return null;
  }

  const value = event as Record<string, unknown>;
  const eventId = typeof value.eventId === "string"
    ? value.eventId.trim()
    : "";
  const entityId = typeof value.entityId === "string"
    ? value.entityId.trim()
    : "";
  const operation = value.operation;
  const entityType = value.entityType;
  const version = value.version;
  const occurredAt = value.occurredAt;

  if (
    eventId.length === 0 ||
    eventId.length > 256 ||
    entityId.length === 0 ||
    entityId.length > 256 ||
    !ENTITY_TYPES.has(entityType as SearchEventEntity) ||
    (operation !== "upsert" && operation !== "delete") ||
    typeof version !== "number" ||
    !Number.isSafeInteger(version) ||
    version <= 0 ||
    version > Number.MAX_SAFE_INTEGER ||
    typeof occurredAt !== "string" ||
    Number.isNaN(Date.parse(occurredAt))
  ) {
    return null;
  }

  const document = value.document;
  if (operation === "upsert") {
    if (!document || typeof document !== "object" || Array.isArray(document)) {
      return null;
    }

    const doc = document as Record<string, unknown>;
    if (
      doc.id !== entityType + "_" + entityId ||
      doc.entityType !== entityType ||
      !isSearchIndexDocument(doc)
    ) {
      return null;
    }
  } else if (document !== undefined) {
    return null;
  }

  return {
    eventId,
    operation,
    entityType: entityType as SearchEventEntity,
    entityId,
    version,
    occurredAt,
    ...(document
      ? {document: document as SearchIndexDocument}
      : {}),
  };
}
