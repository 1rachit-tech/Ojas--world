const test = require("node:test");
const assert = require("node:assert/strict");
const {
  decodeSearchCursor,
  encodeSearchCursor,
  InvalidSearchCursorError,
  validateSearchIndexEvent,
} = require("../dist/src/validation.js");

test("cursor is opaque, versioned and bounded", () => {
  const cursor = encodeSearchCursor(25);
  assert.equal(decodeSearchCursor(cursor), 25);
  assert.throws(
    () => decodeSearchCursor(
      Buffer.from(JSON.stringify({version: 2, offset: 25}), "utf8").toString("base64url"),
    ),
    InvalidSearchCursorError,
  );
  assert.throws(
    () => decodeSearchCursor(
      Buffer.from(JSON.stringify({version: 1, offset: 100001}), "utf8").toString("base64url"),
    ),
    InvalidSearchCursorError,
  );
});

test("index upsert event requires a deterministic matching document", () => {
  const valid = validateSearchIndexEvent({
    eventId: "event-1",
    operation: "upsert",
    entityType: "content",
    entityId: "show-1",
    version: 2,
    occurredAt: new Date().toISOString(),
    document: {
      id: "content_show-1",
      entityType: "content",
      eligible: true,
      visibility: "public",
      safetyStatus: "clean",
    },
  });
  assert.ok(valid);

  const invalid = validateSearchIndexEvent({
    eventId: "event-1",
    operation: "upsert",
    entityType: "content",
    entityId: "show-1",
    version: 2,
    occurredAt: new Date().toISOString(),
    document: {
      id: "person_show-1",
      entityType: "content",
      eligible: true,
      visibility: "public",
      safetyStatus: "clean",
    },
  });
  assert.equal(invalid, null);
});

test("delete events cannot carry a document", () => {
  const result = validateSearchIndexEvent({
    eventId: "event-2",
    operation: "delete",
    entityType: "person",
    entityId: "user-1",
    version: 3,
    occurredAt: new Date().toISOString(),
    document: {},
  });
  assert.equal(result, null);
});
