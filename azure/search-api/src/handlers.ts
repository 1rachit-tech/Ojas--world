import { app, type HttpRequest, type HttpResponseInit, type InvocationContext } from "@azure/functions";
import { serviceBusClient } from "./service-bus";
import { randomUUID } from "node:crypto";
import { authenticate } from "./auth";
import { config } from "./config";
import {
  ensureSafetyConfiguration,
  loadSafetyContext,
  odataFilterForSafety,
} from "./safety";
import {
  deleteDocuments,
  searchAzureIndex,
  suggestAzureIndex,
  upsertDocuments,
} from "./search-client";
import { projectEntityTab } from "./entity-projection";
import { RuleBasedSearchReranker, loadInterestContext } from "./ranker";
import type {
  SearchIndexEvent,
  SearchRequest,
} from "./types";

function json(status: number, body: unknown): HttpResponseInit {
  return {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
    },
    jsonBody: body,
  };
}

function boundedPageSize(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return 20;
  }

  return Math.min(Math.max(Math.floor(value), 1), 50);
}

function validTab(value: unknown): NonNullable<SearchRequest["tab"]> {
  const allowed = new Set([
    "all",
    "top",
    "people",
    "videos",
    "posts",
    "hashtags",
    "sounds",
    "topics",
    "live",
    "places",
  ]);

  if (typeof value !== "string" || !allowed.has(value)) {
    return "all";
  }

  return value as NonNullable<SearchRequest["tab"]>;
}

function safeQuery(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, 256);
}

async function readJson<T>(request: HttpRequest): Promise<T> {
  const body = await request.json();
  return body as T;
}

export async function searchHttp(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  const user = await authenticate(
    request.headers.get("authorization") ?? undefined,
    request.headers.get("x-firebase-appcheck") ?? undefined,
  );

  if (!user) return json(401, { error: "unauthorized" });

  try {
    ensureSafetyConfiguration();

    const body = await readJson<SearchRequest>(request);
    const query = safeQuery(body.query);
    const tab: NonNullable<SearchRequest["tab"]> = validTab(body.tab);

    if (!query) {
      return json(400, { error: "query_required" });
    }

    const safety = await loadSafetyContext(user);
    const filter = odataFilterForSafety(
      safety.blockedCreatorIds,
      tab,
    );

    const result = await searchAzureIndex({
      query,
      tab,
      pageSize: boundedPageSize(body.pageSize),
      cursor: body.cursor,
      filter,
    });

    const projected = projectEntityTab(
      result.results,
      tab,
      query,
    );

    const interestContext = await loadInterestContext(user.uid);
    const reranker = new RuleBasedSearchReranker();
    const reranked = reranker.rerank(
      projected,
      interestContext,
    ).slice(0, boundedPageSize(body.pageSize));

    return json(200, {
      results: reranked,
      query,
      sessionId: randomUUID(),
      cursor: result.nextCursor,
      hasMore: result.hasMore,
      fromCache: false,
      offline: false,
      didYouMean: null,
    });
  } catch (error) {
    context.error("OJAS Search request failed.", error);
    return json(503, { error: "search_unavailable" });
  }
}

export async function suggestionsHttp(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  const user = await authenticate(
    request.headers.get("authorization") ?? undefined,
    request.headers.get("x-firebase-appcheck") ?? undefined,
  );

  if (!user) return json(401, { error: "unauthorized" });

  try {
    ensureSafetyConfiguration();

    const body = await readJson<{
      query?: string;
      limit?: number;
    }>(request);

    const query = safeQuery(body.query);

    if (!query) {
      return json(200, { suggestions: [] });
    }

    // Suggestions are intentionally filtered to eligible public content.
    // The final search endpoint applies viewer-specific block filtering.
    const safety = await loadSafetyContext(user);
    const filter = odataFilterForSafety(
      safety.blockedCreatorIds,
      "all",
    );

    const values = await suggestAzureIndex(
      query,
      Math.min(boundedPageSize(body.limit ?? 8), 20),
      filter,
    );

    return json(200, { suggestions: values });
  } catch (error) {
    context.error("OJAS Search suggestions failed.", error);
    return json(503, { error: "suggestions_unavailable" });
  }
}

async function publishIndexEvent(
  event: SearchIndexEvent,
): Promise<void> {
  if (config.eventMode === "direct") {
    if (event.operation === "upsert" && event.document) {
      await upsertDocuments([event.document]);
      return;
    }

    await deleteDocuments([
      event.entityType + "_" + event.entityId,
    ]);
    return;
  }

  if (
    config.serviceBusAuthMode === "connection_string" &&
    !config.serviceBusConnection
  ) {
    throw new Error("SEARCH_SERVICE_BUS_CONNECTION is missing.");
  }

  if (
    config.serviceBusAuthMode === "managed_identity" &&
    !config.serviceBusFqdn
  ) {
    throw new Error("SEARCH_SERVICE_BUS_FQDN is missing.");
  }

  const client = serviceBusClient();
  const sender = client.createSender(config.serviceBusQueue);

  try {
    await sender.sendMessages({
      body: event,
      messageId: event.eventId,
    });
  } finally {
    await sender.close();
    await client.close();
  }
}


export async function eventsHttp(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  const user = await authenticate(
    request.headers.get("authorization") ?? undefined,
    request.headers.get("x-firebase-appcheck") ?? undefined,
  );

  if (!user) return json(401, { error: "unauthorized" });

  try {
    const body = await readJson<{
      events?: Array<Record<string, unknown>>;
    }>(request);

    const events = Array.isArray(body.events)
      ? body.events
          .slice(0, 100)
          .filter((event) => JSON.stringify(event).length <= 8192)
      : [];

    if (events.length === 0) {
      return json(202, { accepted: 0 });
    }

    if (
      (config.serviceBusAuthMode === "connection_string" &&
        !config.serviceBusConnection) ||
      (config.serviceBusAuthMode === "managed_identity" &&
        !config.serviceBusFqdn)
    ) {
      // Analytics is deliberately best-effort. Search must not depend on it.
      return json(202, { accepted: 0, stored: false });
    }

    const client = serviceBusClient();
    const sender = client.createSender(config.analyticsQueue);

    try {
      await sender.sendMessages(
        events.map((event) => ({
          body: {
            ...event,
            uid: user.uid,
            receivedAt: new Date().toISOString(),
          },
        })),
      );
    } finally {
      await sender.close();
      await client.close();
    }

    return json(202, {
      accepted: events.length,
      stored: true,
    });
  } catch (error) {
    context.error("OJAS Search analytics ingest failed.", error);
    return json(202, { accepted: 0, stored: false });
  }
}

export async function ingestHttp(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  const secret =
    request.headers.get("x-ojas-index-secret") ?? "";

  if (
    !config.ingestSecret ||
    secret !== config.ingestSecret
  ) {
    return json(401, { error: "unauthorized" });
  }

  try {
    const event = await readJson<SearchIndexEvent>(request);

    if (
      !event.eventId ||
      !event.entityId ||
      !event.entityType ||
      !event.operation
    ) {
      return json(400, { error: "invalid_event" });
    }

    await publishIndexEvent(event);

    return json(202, {
      accepted: true,
      eventId: event.eventId,
    });
  } catch (error) {
    context.error("OJAS Search index ingest failed.", error);
    return json(503, { error: "index_ingest_unavailable" });
  }
}

export async function indexWorker(
  message: unknown,
  context: InvocationContext,
): Promise<void> {
  const event = message as SearchIndexEvent;

  if (!event?.eventId || !event?.entityId) {
    throw new Error("Invalid search index event.");
  }

  if (event.operation === "upsert" && event.document) {
    await upsertDocuments([event.document]);
    return;
  }

  if (event.operation === "delete") {
    await deleteDocuments([
      event.entityType + "_" + event.entityId,
    ]);
    return;
  }

  context.error("Unsupported OJAS Search index operation.");
  throw new Error("Unsupported search index operation.");
}

app.http("search", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "v1/search",
  handler: searchHttp,
});

app.http("searchSuggestions", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "v1/search/suggestions",
  handler: suggestionsHttp,
});

app.http("searchEvents", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "v1/search/events",
  handler: eventsHttp,
});

app.http("searchIndexIngest", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "v1/search/index/events",
  handler: ingestHttp,
});

app.serviceBusQueue("searchIndexWorker", {
  connection: "SEARCH_SERVICE_BUS_CONNECTION",
  queueName: config.serviceBusQueue,
  handler: indexWorker,
});
