import { DefaultAzureCredential } from "@azure/identity";
import { config } from "./config";
import type { SearchIndexDocument, SearchResult } from "./types";
import {
  decodeSearchCursor,
  encodeSearchCursor,
  InvalidSearchCursorError,
} from "./validation";

let credential: DefaultAzureCredential | null = null;

function azureCredential(): DefaultAzureCredential {
  credential ??= new DefaultAzureCredential();
  return credential;
}

async function bearerToken(): Promise<string> {
  const token = await azureCredential().getToken(
    "https://search.azure.com/.default",
  );

  if (!token?.token) {
    throw new Error("Unable to obtain Azure AI Search token.");
  }

  return token.token;
}

async function requestSearch(
  body: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  if (!config.searchEndpoint) {
    throw new Error("AZURE_SEARCH_ENDPOINT is missing.");
  }

  const url =
    config.searchEndpoint +
    "/indexes('" +
    encodeURIComponent(config.searchIndex) +
    "')/docs/search?api-version=" +
    encodeURIComponent(config.searchApiVersion);

  const headers: Record<string, string> = {
    "content-type": "application/json",
  };

  if (config.searchAuthMode === "api_key") {
    if (!config.searchQueryKey) {
      throw new Error("AZURE_SEARCH_QUERY_KEY is missing.");
    }
    headers["api-key"] = config.searchQueryKey;
  } else {
    headers.authorization = "Bearer " + (await bearerToken());
  }

  const response = await fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });

  const text = await response.text();

  if (!response.ok) {
    throw new Error(
      "Azure AI Search returned " +
        response.status +
        ": " +
        text.slice(0, 1000),
    );
  }

  return text
    ? (JSON.parse(text) as Record<string, unknown>)
    : {};
}

function resultFromDocument(
  document: Record<string, unknown>,
): SearchResult {
  const score =
    typeof document["@search.rerankerScore"] === "number"
      ? document["@search.rerankerScore"]
      : typeof document["@search.score"] === "number"
        ? document["@search.score"]
        : 0;

  const queryScore =
    typeof document["@search.score"] === "number"
      ? document["@search.score"]
      : score;

  const entityType =
    typeof document.entityType === "string"
      ? document.entityType
      : "generic";

  return {
    id: String(document.id ?? ""),
    entityType: entityType as SearchResult["entityType"],
    title: String(document.title ?? ""),
    subtitle: String(document.subtitle ?? ""),
    score,
    queryScore,
    personalScore: Number(document.personalScore ?? 0),
    qualityScore: Number(document.algorithmScore ?? 0),
    popularityScore: Number(document.views ?? 0),
    freshnessScore: 0,
    trendScore: Number(document.trendScore ?? 0),
    imageUrl: String(document.imageUrl ?? ""),
    creatorId: String(document.creatorId ?? ""),
    contentUrl: String(document.contentUrl ?? ""),
    audioTrackId: String(document.audioTrackId ?? ""),
    createdAt:
      typeof document.createdAt === "string"
        ? document.createdAt
        : null,
    tags: Array.isArray(document.tags)
      ? document.tags.filter(
          (item): item is string => typeof item === "string",
        )
      : [],
    extra: {
      language: document.language ?? "",
      region: document.region ?? "",
      location: document.location ?? "",
      topicIds: document.topicIds ?? [],
      views: document.views ?? 0,
      likes: document.likes ?? 0,
      saves: document.saves ?? 0,
      followers: document.followers ?? 0,
      posts: document.posts ?? 0,
      algorithmScore: document.algorithmScore ?? 0,
      isLive: document.isLive === true,
      semanticScore: document["@search.rerankerScore"] ?? null,
    },
  };
}


function buildBody(args: {
  query: string;
  tab: string;
  pageSize: number;
  skip: number;
  filter: string;
  vector: boolean;
  semantic: boolean;
}): Record<string, unknown> {
  const requestedPageSize = Math.min(Math.max(args.pageSize, 1), 50);
  const semanticCandidateCount = args.semantic ? 50 : requestedPageSize + 1;

  const body: Record<string, unknown> = {
    search: args.query,
    top: semanticCandidateCount,
    skip: args.skip,
    filter: args.filter,
    select: [
      "id", "entityType", "title", "subtitle", "text",
      "imageUrl", "creatorId", "contentUrl", "audioTrackId",
      "tags", "topicIds", "location", "language", "region",
      "visibility", "eligible", "isLive", "views", "likes",
      "saves", "followers", "posts", "algorithmScore",
      "trendScore", "createdAt", "updatedAt",
    ].join(","),
  };

  if (args.semantic) {
    body.queryType = "semantic";
    body.semanticConfiguration = config.semanticConfiguration;
  } else {
    body.queryType = "simple";
  }

  if (args.vector) {
    body.vectorQueries = [
      {
        kind: "text",
        text: args.query,
        fields: config.vectorField,
        k: 50,
      },
    ];
  }

  return body;
}

export async function searchAzureIndex(args: {
  query: string;
  tab: string;
  pageSize: number;
  cursor?: string | null;
  filter: string;
}): Promise<{
  results: SearchResult[];
  nextCursor: string | null;
  hasMore: boolean;
}> {
  let skip: number;
  try {
    skip = decodeSearchCursor(args.cursor);
  } catch (error) {
    if (error instanceof InvalidSearchCursorError) throw error;
    throw new InvalidSearchCursorError();
  }

  const modes = [
    { vector: config.enableVector, semantic: config.enableSemantic },
    { vector: false, semantic: false },
  ];

  let lastError: unknown = null;

  for (const mode of modes) {
    if (
      mode.vector === false &&
      mode.semantic === false &&
      !config.enableVector &&
      !config.enableSemantic
    ) {
      // Still run the baseline request once.
    }

    try {
      const payload = await requestSearch(
        buildBody({
          query: args.query,
          tab: args.tab,
          pageSize: args.pageSize,
          skip,
          filter: args.filter,
          vector: mode.vector,
          semantic: mode.semantic,
        }),
      );

      const values = Array.isArray(payload.value)
        ? payload.value
        : [];

      const results = values
        .filter(
          (item): item is Record<string, unknown> =>
            !!item && typeof item === "object",
        )
        .map(resultFromDocument);

      const pageSize = Math.min(Math.max(args.pageSize, 1), 50);
      const page = results.slice(0, pageSize);
      const hasMore = results.length > page.length;

      return {
        results: page,
        nextCursor: hasMore
          ? encodeSearchCursor(skip + page.length)
          : null,
        hasMore,
      };
    } catch (error) {
      lastError = error;
    }
  }

  throw lastError instanceof Error
    ? lastError
    : new Error("Azure search failed.");
}

export async function suggestAzureIndex(
  query: string,
  limit = 8,
  filter = "eligible eq true and visibility eq 'public'",
): Promise<Array<{
  text: string;
  subtitle: string;
  entityType: string;
  id: string;
  imageUrl: string;
}>> {
  if (!query.trim()) return [];

  const payload = await requestSearch({
    search: query,
    top: Math.min(Math.max(limit, 1), 20),
    select: "id,entityType,title,subtitle,imageUrl",
    filter,
  });

  const values = Array.isArray(payload.value)
    ? payload.value
    : [];

  return values
    .filter(
      (item): item is Record<string, unknown> =>
        !!item && typeof item === "object",
    )
    .map((item) => ({
      text: String(item.title ?? ""),
      subtitle: String(item.subtitle ?? ""),
      entityType: String(item.entityType ?? "generic"),
      id: String(item.id ?? ""),
      imageUrl: String(item.imageUrl ?? ""),
    }))
    .filter((item) => item.text.trim().length > 0);
}

function dataPlaneHeaders(): Promise<Record<string, string>> {
  if (config.searchAuthMode === "api_key") {
    if (!config.searchQueryKey) {
      throw new Error("AZURE_SEARCH_QUERY_KEY is missing.");
    }
    return Promise.resolve({
      "content-type": "application/json",
      "api-key": config.searchQueryKey,
    });
  }

  return bearerToken().then((token) => ({
    "content-type": "application/json",
    authorization: "Bearer " + token,
  }));
}

async function sendIndexBatch(
  actions: Record<string, unknown>[],
): Promise<void> {
  if (!config.searchEndpoint) {
    throw new Error("AZURE_SEARCH_ENDPOINT is missing.");
  }

  const url =
    config.searchEndpoint +
    "/indexes('" +
    encodeURIComponent(config.searchIndex) +
    "')/docs/index?api-version=" +
    encodeURIComponent(config.searchApiVersion);

  const response = await fetch(url, {
    method: "POST",
    headers: await dataPlaneHeaders(),
    body: JSON.stringify({ value: actions }),
  });

  const text = await response.text();

  if (!response.ok) {
    throw new Error(
      "Azure AI Search indexing returned " +
        response.status +
        ": " +
        text.slice(0, 1000),
    );
  }

  const payload = text
    ? (JSON.parse(text) as Record<string, unknown>)
    : {};

  if (payload.errors === true) {
    throw new Error(
      "Azure AI Search rejected one or more indexing actions.",
    );
  }
}

export async function listIndexedDocumentIds(
  maxDocuments: number,
): Promise<Set<string>> {
  const limit = Math.min(
    Math.max(Math.floor(maxDocuments), 1),
    100000,
  );
  const ids = new Set<string>();
  const pageSize = 1000;
  let skip = 0;

  while (ids.size < limit) {
    const payload = await requestSearch({
      search: "*",
      top: Math.min(pageSize, limit - ids.size),
      skip,
      select: "id",
      queryType: "simple",
    });

    const values = Array.isArray(payload.value)
      ? payload.value
      : [];

    if (values.length === 0) break;

    for (const item of values) {
      if (!item || typeof item !== "object") continue;
      const id = (item as Record<string, unknown>).id;
      if (typeof id === "string" && id.length > 0) {
        ids.add(id);
      }
    }

    skip += values.length;
    if (values.length < pageSize) break;
  }

  return ids;
}

export async function upsertDocuments(
  documents: SearchIndexDocument[],
): Promise<void> {
  if (!documents.length) return;

  await sendIndexBatch(
    documents.map((document) => ({
      ...document,
      "@search.action": "mergeOrUpload",
    })),
  );
}

export async function deleteDocuments(ids: string[]): Promise<void> {
  if (!ids.length) return;

  await sendIndexBatch(
    ids.map((id) => ({
      id,
      "@search.action": "delete",
    })),
  );
}
