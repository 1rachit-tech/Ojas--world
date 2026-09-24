export type SearchEventOperation = "upsert" | "delete";
export type SearchEventEntity =
  | "person"
  | "content"
  | "hashtag"
  | "sound"
  | "topic"
  | "place"
  | "live"
  | "generic";

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
  document?: Record<string, unknown>;
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
      typeof doc.id !== "string" ||
      doc.id !== entityType + "_" + entityId ||
      doc.entityType !== entityType ||
      typeof doc.eligible !== "boolean" ||
      typeof doc.visibility !== "string" ||
      typeof doc.safetyStatus !== "string"
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
      ? {document: document as Record<string, unknown>}
      : {}),
  };
}
