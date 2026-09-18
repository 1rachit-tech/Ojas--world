# OJAS SEARCH V2 — IMPLEMENTATION MASTER PROMPT

You are implementing the OJAS Search subsystem in the existing Flutter repository.

Do not create a toy/demo search. Treat Search as a production discovery subsystem.

## Non-negotiable product rules

1. OJAS short-video terminology is "Show". Never introduce "Reels" or "Shorts" in user-facing Search UI.
2. Navigation/search surfaces use clean pure-white/light minimalist visual language. Video viewer remains AMOLED/dark.
3. Preserve existing imports, public APIs, navigation destinations, data models, and working features unless a migration explicitly requires a change.
4. Do not silently delete existing behavior.
5. Prefer low-end device performance, weak-network resilience, small memory footprint and zero-jank scrolling.
6. Never introduce a paid cloud dependency without an explicit deployment switch and a clear cost note.
7. Never place Azure Search keys, Service Bus secrets, Firebase Admin credentials, embedding secrets or other privileged credentials in Flutter.

## Final implementation target

The existing OJAS Search branch must be completed as one coherent subsystem. Do not leave UI, API, indexing, safety, analytics or deployment as disconnected stubs.

The production cloud choice is Azure.

Firebase may remain the transactional/source-data system and authentication provider during the migration, but Firebase Search indexing is not the production retrieval engine.

## Target production architecture

Flutter Search UI
→ SearchOrchestrator
→ Azure Functions Search API
→ authentication
→ query understanding
→ safety/eligibility
→ Azure AI Search retrieval
→ personalization/feature store
→ entity projection
→ rule/LTR reranker
→ cursor pagination
→ Flutter cache
→ destination UI

Canonical Firebase profile/Show writes
→ trusted bridge
→ Azure ingest API
→ Azure Service Bus
→ Azure indexing worker
→ Azure AI Search

Analytics:
Flutter event queue
→ batched Azure analytics endpoint
→ Service Bus
→ Blob archive
→ future offline training/evaluation

Correctness:
event pipeline is the fast path;
scheduled reconciliation is the correctness path.

## Query understanding

Implement and preserve:
- Unicode normalization
- script detection
- Devanagari/Latin mixed query support
- transliteration candidates
- typo/edit-distance tolerance
- aliases/synonyms
- language-aware tokenization
- intent detection
- hashtag and profile prefixes
- did-you-mean fallback

Keep the query processor behind a stable interface.

## Retrieval

Baseline:
- Azure AI Search lexical retrieval

Upgrade path:
- keyword + vector hybrid retrieval
- RRF fusion
- semantic reranking

Vector mode must remain feature-gated until:
- an embedding model is selected
- final output dimensions are verified
- index vector dimensions match the model
- vectorizer configuration is validated

Never assume the sample 384-dimensional contract is automatically compatible with every embedding model.

## Search index

Version the index name.

Core fields:
- id
- entityType
- title
- subtitle
- text
- imageUrl
- creatorId
- contentUrl
- audioTrackId
- tags
- topicIds
- location
- language
- region
- visibility
- eligible
- safetyStatus
- isLive
- views
- likes
- saves
- followers
- posts
- algorithmScore
- trendScore
- createdAt
- updatedAt
- optional vector field

Use a new index version for breaking schema/vector dimension changes.

## Entity types

Search must support:
- person
- content/Show
- hashtag
- sound
- topic
- place
- live

Entity-specific ranking/projection must be possible without rewriting the Search UI.

## Safety

Before user-visible output:
- reject deleted
- reject banned
- reject private content when viewer is unauthorized
- reject ineligible/unsafe content
- remove creators blocked by viewer
- preserve moderation restrictions
- fail closed when safety context cannot be established

Apply viewer-specific safety filters server-side. Client-side filtering is a secondary defense only.

## Personalization

Reuse OJAS interest graph:
- creator affinity
- topic affinity
- hashtag affinity
- sound affinity
- content type affinity
- negative affinity

Start with a rule-based reranker.

Keep a replaceable interface for:
- LambdaMART/GBDT
- neural reranker
- model registry
- shadow deployment
- canary rollout
- rollback

## Ranking

Support:
- query relevance
- entity relevance
- personalization
- quality
- popularity
- freshness
- trend
- safety/ineligibility penalties
- creator diversity

Do not let one creator dominate an entire page.

## Pagination

Use opaque cursors.

Never expose implementation-specific offsets as a UI contract.

Cursor formats must be versioned.

## Weak-network behavior

Failure order:
1. live Azure result
2. cached Search result
3. local recent-history/suggestion data
4. legacy migration fallback when Azure is not configured

Analytics failure must never block Search.

Safety failure must not silently return unsafe results.

## Indexing

Indexing events must be deterministic and idempotent.

Every event:
- eventId
- operation
- entityType
- entityId
- version
- occurredAt
- document if upsert

Upsert and delete/privacy/moderation changes must follow the same pipeline.

## Reconciliation

Run on a configurable timer.

Rebuild deterministic documents from canonical data.
Batch upload.
Log counts.
Repair stale/missing documents.

The event path gives freshness.
The reconciliation path gives correctness.

## Backend security

Preferred:
- Microsoft Entra ID
- managed identities
- Azure RBAC
- Key Vault or secure app settings

API keys may exist only as migration fallback.

Use least privilege:
- Search Index Data Reader for query service
- Search Index Data Contributor for index worker
- Service Bus Data Sender/Receiver as required
- Blob permissions scoped to the actual archive/deployment need

## Cost controls

All Azure provisioning must be explicitly opt-in.

Defaults:
- no Search provisioning
- no Service Bus provisioning
- no paid Function infrastructure
- no vectorization
- no semantic reranking

Provide manual deployment workflow only.

## UI requirements

The Search experience is a first-class OJAS discovery page, not a debug list.

### App surfaces
- Discover landing/search entry
- dedicated Search screen
- typed-query suggestions
- recent-search surface
- tabbed results
- creator result destination
- Show result destination
- hashtag destination
- sound destination
- topic destination
- place destination
- LIVE destination
- immersive Search Show viewer

### Visual system
- pure-white/minimal navigation language
- very light grey content surfaces
- rounded 16–22px cards where appropriate
- soft borders and restrained elevation
- high-contrast black typography
- compact premium metadata
- no visual clutter
- no placeholder picsum/mock content in production Search results
- no "Reels" or "Shorts" user-facing terminology
- Show is the OJAS short-video term

### Interaction
- debounce suggestions
- stale-request cancellation
- haptic selection feedback where already supported
- keyboard-safe scrolling
- pull/scroll pagination without duplicate requests
- loading, empty, offline and error states
- cached-result indicator
- retry action
- safe accessibility hit targets

### Result hierarchy
Creator:
avatar → display name → @OJAS ID → follower metadata

Show:
thumbnail → title/caption → creator → views/quality metadata → Show destination

Hashtag/topic/place:
entity icon → canonical name → supporting metadata

Sound:
audio icon → sound title → creator/usage context

LIVE:
live badge → creator/title → current live destination



Search screen must look premium and modern:
- generous spacing
- rounded search field
- subtle focus elevation
- modern dark selected chips
- clean entity hierarchy
- avatar/thumbnail treatment
- creator metadata
- Show metadata
- LIVE badge
- polished empty/recent/suggestion states
- smooth transitions
- responsive layouts
- accessible text contrast
- no excessive borders
- no clutter

The Search page must support:
- recent searches
- suggestions while typing
- All
- Top
- People
- Videos/Show
- Posts
- Hashtags
- Sounds
- Topics
- LIVE
- Places

Content results must open the existing OJAS Show viewer.
People open the existing creator profile.
Hashtags/sounds use the existing destination screens.

## Performance budgets

Target:
- query understanding p50 ≤ 5ms
- suggestions p50 ≤ 40ms
- lexical retrieval p50 ≤ 30ms
- semantic retrieval p50 ≤ 40ms when enabled
- ranking p50 ≤ 30ms
- overall p50 around 170ms
- p99 target 350–500ms

These are targets, not claims, until production telemetry verifies them.

## Graceful degradation

If semantic/vector retrieval fails:
→ continue with lexical retrieval.

If ranker fails:
→ rule ranker.

If feature store fails:
→ neutral defaults.

If analytics fails:
→ local event queue.

If suggestion service fails:
→ typed query still works.

If safety fails:
→ fail closed.

## Testing gates

Required checks are not optional. Do not merge while any required Search check is red.

Before declaring the subsystem ready:
1. Flutter query processor tests
2. Flutter ranking tests
3. Azure API TypeScript check
4. Firebase bridge TypeScript build
5. Azure Bicep validation
6. Search index JSON validation
7. weak-network/cache behavior
8. block/privacy safety cases
9. pagination/cursor cases
10. zero-result and suggestion behavior

A failing CI job must be fixed from its actual compiler/test output. Do not bypass required checks or merge with red Search validation.



Before declaring the subsystem ready:
1. Flutter query processor tests
2. Flutter ranking tests
3. Azure API TypeScript check
4. Firebase bridge TypeScript build
5. Azure Bicep validation
6. Search index JSON validation
7. weak-network/cache behavior
8. block/privacy safety cases
9. pagination/cursor cases
10. zero-result and suggestion behavior

Never report success unless CI or an equivalent reproducible validation actually passed.

## Definition of done

The implementation is complete only when all of the following are true:
- Azure is the declared production Search cloud
- Flutter Search UI uses a stable backend abstraction
- Azure Search API is wired
- Azure authentication boundary is wired
- safety is enforced server-side and fail-closed
- Firebase Profile/Show writes can reach the Azure indexing pipeline
- Service Bus index event path is wired
- Service Bus analytics path is wired
- scheduled reconciliation is wired
- local analytics retry queue is wired
- Search cache fallback is wired
- personalization is wired
- entity-specific result projection is wired
- cursor pagination is wired
- modern Search UI is wired to existing OJAS destinations
- schema/index versioning exists
- semantic/vector upgrades are feature-gated
- managed identity/RBAC path exists
- paid infrastructure provisioning is explicit opt-in
- secrets are not committed
- CI validates code and infrastructure
- all required CI checks are green before merge

## Current delivery gate

The latest known Search CI run exposed Flutter-only compile/test failures caused by:
- one incorrect relative import in query_processor.dart
- one duplicate synonym-map key

Those two issues have been corrected on the branch.

The branch must now receive a fresh CI run and remain unmerged until the Flutter Search test job is green.



Done means:
- UI is connected to the production abstraction
- Azure API exists
- indexing bridge exists
- Service Bus path exists
- safety is fail-closed
- personalization is wired
- reconciliation exists
- analytics queue exists
- cache fallback exists
- deployment is explicit and cost-gated
- vector/semantic upgrades are switchable
- schema/index versioning exists
- CI validates code and infrastructure
- no secrets are committed
- existing OJAS destinations remain functional
- all known validation failures are fixed or explicitly documented
