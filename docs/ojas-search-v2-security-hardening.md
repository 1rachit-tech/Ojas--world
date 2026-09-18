# OJAS Search v2 — Security Boundary

## Server-only secret rule

The Flutter application must never contain:
- Azure AI Search admin/query keys.
- Azure Service Bus keys or connection strings.
- The Firebase Admin service-account JSON/private key.
- The Firebase-to-Azure ingest secret.
- Any Azure subscription/service-principal client secret.

The mobile client may contain public Firebase configuration identifiers and the public OJAS Search API base URL. Those are not substitutes for server authorization.

## Request authentication

The Azure Search API requires both a valid Firebase Authentication ID token and a valid Firebase App Check token.

Android release builds use Firebase App Check with Play Integrity. Debug builds use the App Check debug provider so local development does not require production attestation.

The App Check token is sent in the X-Firebase-AppCheck header, never in a URL or query string.

Firebase documents App Check specifically for protecting custom backend resources and recommends verifying the token on the backend. See the Firebase custom-backend App Check documentation. 

## Azure authentication

Azure AI Search is configured for Microsoft Entra ID/RBAC and local API-key authentication is disabled.

Runtime roles:
- Search Index Data Reader for query traffic.
- Search Index Data Contributor for the trusted indexing worker.

The deployment identity receives Search Service Contributor only for deployment-time search-object management.

Microsoft recommends Entra ID/RBAC for production Search workloads and documents these role boundaries.

## Deployment credentials

GitHub Actions uses Azure OIDC instead of storing an Azure client secret in GitHub.

Required GitHub environment secrets:
- AZURE_CLIENT_ID
- AZURE_TENANT_ID
- AZURE_SUBSCRIPTION_ID
- AZURE_RESOURCE_GROUP
- AZURE_LOCATION
- FIREBASE_SERVICE_ACCOUNT_JSON
- FIREBASE_PROJECT_ID
- FIREBASE_APP_CHECK_APP_ID
- AZURE_SEARCH_INGEST_SECRET

The deployment workflow never puts these values into Flutter source.

## Network model

For the low-cost starter deployment, the public Function endpoint remains reachable over HTTPS because the mobile application must call it. Authorization occurs at the application layer through Firebase Auth + App Check.

Azure AI Search itself accepts only Entra ID/RBAC authentication. Private Link can be introduced later when traffic or cost justifies the extra network infrastructure.

## Abuse controls

The API validates authenticated user identity, App Check attestation, maximum query length, allowed search tabs, bounded page size, bounded analytics batch size and per-event payload size, and fail-closed safety configuration.

A future high-scale deployment can add Azure API Management or a distributed rate-limit store when request volume demonstrates the need. Do not add a paid component merely for theoretical scale.

## Important limitation

No mobile application can be made literally impossible to reverse-engineer or attack. The security goal is to ensure that compromise of the APK does not reveal server credentials or directly grant privileged access to Azure resources.

The trust boundary is:

 OJAS APK -> Firebase Auth + App Check -> Azure Search API -> Azure AI Search

not direct APK access to Azure Search.