# OJAS Azure Search Production Layer

## Data flow

Flutter
→ Azure Functions Search API
→ Azure AI Search

Firebase canonical profile/Show writes
→ trusted Firebase trigger
→ Azure Search ingest endpoint
→ Service Bus queue
→ Azure Functions indexing worker
→ Azure AI Search

The Firebase trigger is only a source-data bridge. Azure owns search retrieval, indexing orchestration and future scale.

## Cost-safe rollout

1. Keep the Azure environment variables empty while developing. The Flutter client keeps its existing Firestore/local fallback.
2. Provision Azure AI Search only when you are ready to accept an Azure bill.
3. Start with vector and semantic switches off.
4. Enable the event bridge and Service Bus for near-real-time indexing.
5. Enable integrated vectorization only after a compatible embedding/vectorizer is configured.
6. Enable semantic reranking only after checking the current usage-based pricing.
7. Increase replicas/partitions only when latency or availability requires it.

Azure AI Search supports keyword, vector, hybrid retrieval and optional semantic reranking. Integrated query-time vectorization uses a vectorizer attached to the vector field; the vectorizer and embedding model must be compatible with the indexed vector dimensions.

## Security

Never put Azure Search admin/query keys in Flutter.

Preferred production authentication is Microsoft Entra ID/RBAC with managed identities. The Search API uses a managed identity to read/query the index and the indexing worker uses a write-capable identity. API keys remain an emergency/migration fallback.

Store Firebase Admin credentials, Service Bus connection strings and the Firebase-to-Azure ingest secret in Azure Key Vault or secure app settings. Never commit them.

## Index versioning

The index name is versioned as ojas-search-v1. For breaking schema changes:

new index → backfill/reconcile → shadow validation → switch environment variable → keep old index briefly → retire old index.

## Correctness

Events are the fast path. A scheduled reconciliation/backfill process must remain the correctness path:

- enumerate canonical public profiles and Shows,
- build deterministic documents,
- batch upsert,
- detect stale/missing documents,
- prioritize delete/privacy/moderation removals,
- record counts and checksums.

## Paid-scale path

The architecture is intentionally switchable:

- Azure AI Search replicas/partitions,
- Service Bus queue → topics/subscriptions if needed,
- Azure Functions Flex Consumption or Container Apps,
- Azure Cache for Redis only when feature/ranking latency proves it necessary,
- Azure-hosted feature store/ranker later,
- Application Insights for SLOs, errors and p50/p95/p99 latency.

Do not enable every service at once. Add paid components only when measurements show they are needed.


## Vector dimension warning

The sample OJAS schema keeps the v2 contract at 384 dimensions, but Azure OpenAI vectorizers are model-dependent. Before enabling AZURE_SEARCH_ENABLE_VECTOR, choose and verify the embedding path, deployment ID, model, and final output dimension. If the model outputs a different dimension, create a new versioned index instead of changing the live vector field in place.

The integrated vectorizer template is therefore intentionally a deployment template, not a claim that the current 384-dimensional sample is ready to enable without model validation.
