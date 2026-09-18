# OJAS Search v2 — Production Master Specification

## 1. Product contract

OJAS Search is the discovery subsystem for:
- creators
- Show/video content
- hashtags
- sounds
- topics
- places
- LIVE entities

The Flutter UI contract is stable. The retrieval backend is provider-based so Azure can replace the temporary Firestore path without rewriting the UI.

## 2. Runtime path

### Production
Flutter
→ Azure Functions Search API
→ safety/authentication
→ Azure AI Search
→ rule/LTR reranker
→ Flutter cache
→ destination viewer/profile/topic screen

### Development / migration fallback
Flutter
→ Azure Search API when configured
→ otherwise existing lexical Firestore path
→ local cache on weak network

The fallback is a migration/development path, not the target production search source.

## 3. Indexing pipeline

Canonical Firebase writes:
publicProfiles/{uid}
reels/{reelId}

→ Firebase trusted indexing trigger
→ deterministic OJAS Search document
→ Azure ingest endpoint
→ Service Bus queue
→ Azure Functions indexing worker
→ Azure AI Search

Delete/privacy/moderation changes use the same event route with delete/upsert semantics.

Every event contains:
- eventId
- operation
- entityType
- entityId
- version
- occurredAt
- document when applicable

## 4. Search retrieval

Azure AI Search is the production retrieval abstraction.

### Baseline
Full-text search with filters for:
- eligible
- public visibility
- viewer blocks

### Paid semantic stage
Hybrid keyword + vector retrieval can be enabled. Azure AI Search executes text and vector retrieval in parallel and merges the result sets with Reciprocal Rank Fusion.

### Paid semantic stage
Semantic ranker is enabled only after measured relevance improvement and pricing validation.

Do not enable vectorization until the configured embedding model and index vector dimensions exactly match.

## 5. Personalization

The current OJAS interest graph remains the personalization source:
- creator affinity
- topic affinity
- hashtag affinity
- sound affinity
- content type affinity
- negative affinity

Azure Search API applies a lightweight server-side reranker.

This is intentionally replaceable by:
1. LambdaMART/GBDT
2. shadow model
3. canary model
4. trained neural reranker

The Flutter contract does not change when the model changes.

## 6. Safety

Safety gates are applied before user-visible results:
- deleted
- banned
- private
- ineligible
- blocked creator
- unsafe moderation state

Safety failures fail closed.

## 7. Analytics pipeline

Flutter SearchEventQueue
→ batched Azure /v1/search/events
→ Service Bus analytics queue
→ Azure Blob NDJSON/JSON archive

The local queue is durable on-device. Analytics failure must never block search.

The archive is the offline training input for future:
- search CTR
- result success
- reformulation
- zero-result
- suggestion CTR
- profile/content open
- post-click watch/like/follow/save
- negative feedback

## 8. Reconciliation

Event delivery is the fast path.

Scheduled reconciliation is the correctness path:
- scan publicProfiles
- scan reels
- deterministically rebuild documents
- batch upload to Azure Search
- report counts

Deletion/privacy events remain priority events. A future full stale-document sweep can be enabled once corpus size justifies it.

## 9. Cursor model

The API uses opaque cursor pagination so the Flutter client never depends on backend-specific offset representation.

Cursor versioning is required for breaking pagination changes.

## 10. Infrastructure

### Search
Azure AI Search
- versioned index name
- lexical fields
- optional vector field
- semantic configuration
- managed-identity ready

### Compute
Azure Functions Flex Consumption template
- Node.js 20
- system-assigned identity
- Application Insights
- Service Bus trigger
- timer reconciliation

### Messaging
Azure Service Bus
- index queue
- analytics queue
- dead-letter support through Service Bus retry semantics

### Storage
Azure Blob Storage
- function deployment/runtime storage
- optional analytics event archive

### Security
Preferred:
- Microsoft Entra ID
- managed identities
- Azure RBAC
- Key Vault/app settings for secrets

The Firebase→Azure bridge uses a protected ingest secret until a dedicated workload identity bridge is introduced.

## 11. Paid-scale path

The architecture is prepared for:
- Search replicas and partitions
- larger hybrid candidate pools
- integrated vectorization
- semantic reranking
- dedicated feature store
- Redis only where measurement justifies it
- trained ranking service
- shadow/canary model rollout
- richer Application Insights SLOs
- Event Hubs/Data Explorer for large-scale analytics

Do not activate all services at once.

## 12. Cost safety

The Bicep templates default provisioning switches to false.

A code merge does not provision:
- Azure AI Search
- Service Bus
- Functions hosting
- Blob storage
- Application Insights

Paid provisioning must be an explicit deployment action.

## 13. Launch gates

### Gate A — zero/near-zero development
- local history
- local cache
- Firestore lexical fallback
- query understanding
- rule ranker

### Gate B — Azure lexical production
- Azure Search
- API authentication
- safety trimming
- event indexing
- reconciliation
- managed identity

### Gate C — hybrid relevance
- vectors
- query-time vectorization
- hybrid retrieval
- measured NDCG/MRR improvement

### Gate D — semantic quality
- semantic ranker
- captions/answers only where useful
- cost measurement

### Gate E — ML ranking
- feature store
- offline training
- shadow
- canary 1 → 5 → 25%
- rollback

## 14. SLO targets

Architecture target:
- query understanding p50 <= 5 ms
- suggestions p50 <= 40 ms
- lexical retrieval p50 <= 30 ms
- semantic retrieval p50 <= 40 ms when enabled
- ranking p50 <= 30 ms
- overall p50 around 170 ms
- p99 target 350–500 ms

These are engineering targets, not measured production claims.

## 15. Failure behavior

- Azure Search unavailable → Flutter cache / migration fallback
- semantic unavailable → lexical/hybrid without semantic
- ranker unavailable → rule ranker
- feature store unavailable → query relevance
- analytics unavailable → local queue
- safety unavailable → fail closed
