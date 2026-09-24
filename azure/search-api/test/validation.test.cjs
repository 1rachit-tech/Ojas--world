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
      title: "OJAS Show",
      subtitle: "creator-1",
      text: "music #music",
      imageUrl: "",
      creatorId: "creator-1",
      contentUrl: "",
      audioTrackId: "sound-1",
      tags: ["#music"],
      topicIds: [],
      location: "",
      language: "en",
      region: "",
      visibility: "public",
      eligible: true,
      safetyStatus: "clean",
      isLive: false,
      views: 0,
      likes: 0,
      saves: 0,
      followers: 0,
      posts: 0,
      algorithmScore: 0,
      trendScore: 0,
      createdAt: null,
      updatedAt: null,
      searchIndexVersion: 2,
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
      title: "OJAS Show",
      subtitle: "creator-1",
      text: "music #music",
      imageUrl: "",
      creatorId: "creator-1",
      contentUrl: "",
      audioTrackId: "sound-1",
      tags: ["#music"],
      topicIds: [],
      location: "",
      language: "en",
      region: "",
      visibility: "public",
      eligible: true,
      safetyStatus: "clean",
      isLive: false,
      views: 0,
      likes: 0,
      saves: 0,
      followers: 0,
      posts: 0,
      algorithmScore: 0,
      trendScore: 0,
      createdAt: null,
      updatedAt: null,
      searchIndexVersion: 2,
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
