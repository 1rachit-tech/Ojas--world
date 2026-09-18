export function env(name: string, fallback = ""): string {
  return (process.env[name] ?? fallback).trim();
}

export const config = {
  searchEndpoint: env("AZURE_SEARCH_ENDPOINT").replace(/\/$/, ""),
  searchIndex: env("AZURE_SEARCH_INDEX_NAME", "ojas-search-v1"),
  searchApiVersion: env("AZURE_SEARCH_API_VERSION", "2026-04-01"),
  searchAuthMode: env("AZURE_SEARCH_AUTH_MODE", "managed_identity"),
  searchQueryKey: env("AZURE_SEARCH_QUERY_KEY"),
  enableVector: env("AZURE_SEARCH_ENABLE_VECTOR", "false") === "true",
  enableSemantic: env("AZURE_SEARCH_ENABLE_SEMANTIC", "false") === "true",
  vectorField: env("AZURE_SEARCH_VECTOR_FIELD", "textVector"),
  semanticConfiguration: env("AZURE_SEARCH_SEMANTIC_CONFIGURATION", "ojas-semantic"),
  serviceBusConnection: env("SEARCH_SERVICE_BUS_CONNECTION"),
  serviceBusQueue: env("SEARCH_SERVICE_BUS_QUEUE", "ojas-search-index-events"),
  analyticsQueue: env("SEARCH_ANALYTICS_QUEUE", "ojas-search-events"),
  eventMode: env("AZURE_SEARCH_EVENT_MODE", "servicebus"),
  ingestSecret: env("AZURE_SEARCH_INGEST_SECRET"),
  firebaseServiceAccountJson: env("FIREBASE_SERVICE_ACCOUNT_JSON"),
  firebaseProjectId: env("FIREBASE_PROJECT_ID"),
  allowAnonymousDev: env("ALLOW_ANONYMOUS_DEV", "false") === "true",
  reconcileEnabled: env("SEARCH_RECONCILE_ENABLED", "false") === "true",
  reconcileCron: env("SEARCH_RECONCILE_CRON", "0 0 */6 * * *"),
  reconcileBatchSize: Math.min(
    Math.max(Number(env("SEARCH_RECONCILE_BATCH_SIZE", "250")) || 250, 25),
    500,
  ),
  reconcileMaxIndexDocs: Math.min(
    Math.max(Number(env("SEARCH_RECONCILE_MAX_INDEX_DOCS", "100000")) || 100000, 1000),
    1000000,
  ),
};
