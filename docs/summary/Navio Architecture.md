# Navio Architecture

**Status:** Finalized target architecture
**Version:** v1.3
**Primary VM:** Ubuntu Server 24.04, 4 vCPU, 8 GB RAM, 60 GB storage
**Optional ML VM:** Ubuntu Server 24.04, 8 vCPU, 8 GB RAM, 80 GB storage, CPU only
**Expected load:** Approximately 10 concurrent users and fewer than 5 requests per second
**Backend:** Java 21+ and Spring Boot 3
**AI integration:** Spring AI with replaceable local or hosted model providers

## 1. Executive summary

Navio is an EV-aware trip-planning and community platform. Its core backend is divided into four Spring Boot domain services:

1. User Management Service
2. Trip Planning Service
3. Mobility & EV Service
4. Community Service

AI Planning is a fifth Spring Boot service. It is optional and provider-agnostic:

- In the self-hosted profile, AI Planning and Ollama run on the separate machine-learning VM.
- In the hosted-provider profile, AI Planning uses a commercial/model-provider API through Spring AI, runs on the application VM, and the ML VM and Ollama are not required.

Navio also has three mandatory Spring platform applications: Spring Cloud Gateway, Spring Cloud Config Server, and a Eureka Discovery Server. NGINX is the production edge proxy in front of Spring Cloud Gateway; it does not replace the gateway. Keycloak is the Identity Provider. PostgreSQL/PostGIS is the primary data store. Kafka is restricted to asynchronous integration events and runs as one KRaft broker without ZooKeeper.

The maximum project count is eight Spring Boot projects: five domain services when AI is enabled plus three platform applications. Without AI, seven Spring projects run. Centralized observability is mandatory. The constrained 8 GB application VM runs Grafana Alloy and exports logs, metrics, and sampled traces to a hosted observability backend instead of self-hosting the full Grafana/Loki/Prometheus/Tempo stack.

## 2. Goals and scope

### 2.1 Goals

- Build and manage detailed travel itineraries.
- Discover places, road routes, and EV chargers.
- Calculate basic EV feasibility and charging-stop recommendations.
- Publish and discover public trip templates.
- Copy a public/community trip as a private, independent trip.
- Support groups, discussions, votes, bookmarks, media, and in-app notifications.
- Manage Navio profiles, global roles, suspensions, and saved vehicles.
- Optionally provide AI-assisted planning without coupling business logic to one model provider.
- Operate safely within the two documented VM profiles.

### 2.2 In scope

- Keycloak registration/login and JWT authentication
- Navio user profiles, preferences, roles, bans, and user vehicles
- Trip CRUD, dates, blocks/lists, places, notes, checklists, reservations, attachments, budgets, expenses, and members
- Owner/editor/viewer trip authorization
- Revision history, visibility, share links, and copy-to-my-trips
- Public Explore catalogue and search
- Place discovery and map-provider adapters
- Route computation and EV charger intelligence
- Charger reviews, reports, suggestions, and verification
- Community groups, posts, threaded comments, votes, bookmarks, moderation, and search
- Community media and an embedded in-app notification module
- Transactional outbox and selected Kafka integration events
- Optional bounded AI agent workflows using schema-validated actions
- Centralized configuration through Spring Cloud Config Server
- Service registration and discovery through Eureka
- Consistent application routing through Spring Cloud Gateway in development and production
- Centralized structured logs, metrics, health signals, and sampled traces

### 2.3 Out of scope for v1

- Real-time collaborative editing
- Payments and subscriptions
- Multi-region or high-availability deployment
- Separate Notification, Media, Search, or IAM Spring services
- Redis, Elasticsearch, Vault, or Schema Registry
- A self-hosted Grafana/Loki/Prometheus/Tempo backend on the 8 GB application VM
- Autonomous AI writes without user confirmation
- High-concurrency local-model inference

## 3. System topology

### 3.1 Application VM

```text
Ubuntu Server 24.04
4 vCPU / 8 GB RAM / 60 GB storage

NGINX edge proxy :80/:443 (production)
Spring Cloud Gateway :8080
Spring Cloud Config Server :8888
Eureka Discovery Server :8761
Next.js frontend
Keycloak Identity Provider
User Management Service :8081
Trip Planning Service :8082
Mobility & EV Service :8083
Community Service :8084
PostgreSQL 16 + PostGIS
Kafka single KRaft broker
Grafana Alloy telemetry collector
```

Development clients call Spring Cloud Gateway directly on port 8080. Production traffic enters through NGINX, which forwards application API traffic to the same gateway. Config Server starts independently, Eureka loads its configuration, and the gateway and domain services then load configuration and register with Eureka.

### 3.2 AI deployment profile A: self-hosted Ollama

```text
Machine-learning VM
Ubuntu Server 24.04
8 vCPU / 8 GB RAM / 80 GB storage / no GPU

AI Planning Service :8085
Ollama :11434 (localhost only)
One small quantized model loaded at a time
One active generation initially
```

Spring Cloud Gateway resolves AI Planning through Eureka and forwards `/v1/ai/**` over the private network. AI Planning calls Ollama on loopback and calls allow-listed Trip Planning and Mobility & EV APIs through discovery-aware clients over the private network.

### 3.3 AI deployment profile B: hosted model API

If local inference is removed, retain the same AI Planning Service and agent contract but configure Spring AI for a hosted provider:

```text
Application VM
└── AI Planning Service :8085
      └── HTTPS → hosted model provider API

No machine-learning VM
No Ollama
```

The hosted-provider profile trades provider cost and external dependency for better model quality, lower local resource usage, higher throughput, and simpler infrastructure. Provider API keys remain server-side environment secrets. The frontend never calls a model provider directly.

### 3.4 Provider portability rule

AI Planning depends on Spring AI's `ChatModel`/`StreamingChatModel` abstractions rather than Ollama-specific types in domain code. Provider-specific configuration stays in adapter/configuration modules.

```text
AiPlanningUseCase
      │
      ├── ChatModel / StreamingChatModel
      │       ├── Ollama provider adapter
      │       └── Hosted provider adapter
      │
      └── Navio tool registry
              ├── Trip Planning tools
              └── Mobility & EV tools
```

Switching provider must not change public `/v1/ai/**` contracts, tool schemas, authorization rules, stored conversation format, or trip-action validation.

## 4. Runtime components

### 4.1 NGINX edge proxy

Responsibilities:

- Single public entry point on ports 80/443
- TLS termination
- Forwarding `/v1/**` to Spring Cloud Gateway
- Forwarding the configured authentication path to Keycloak
- Basic IP/request rate limiting
- Upload/body-size limits
- Request/correlation ID propagation

NGINX is used in production and production-like integration environments. It does not discover services or implement business authorization. In local development it is optional because clients may call Spring Cloud Gateway directly.

### 4.2 Spring Cloud Gateway

**Port:** 8080

Responsibilities:

- The consistent application API entry point in development and production
- Route `/v1/**` requests to Eureka service IDs using Spring Cloud LoadBalancer
- Preserve `Authorization`, `X-Request-Id`, trace context, and client metadata
- Apply shared CORS, response-header, timeout, and gateway rate-limit policies
- Publish gateway health, route, latency, and error metrics

The gateway has no domain schema and contains no business authorization. Every domain service still validates the Keycloak JWT and enforces resource permissions. Production uses `NGINX -> Spring Cloud Gateway`; NGINX never replaces the gateway.

### 4.3 Spring Cloud Config Server

**Port:** 8888

Responsibilities:

- Serve versioned, environment-specific non-secret configuration from a private Git repository
- Centralize service ports, provider endpoints, Kafka settings, timeouts, feature flags, and gateway route definitions
- Expose health and configuration-repository status only on the private network

Config Server starts without depending on Eureka. Secrets, passwords, signing material, database credentials, and hosted-provider API keys are injected with environment variables or protected mounted secrets and are never committed to the configuration repository.

### 4.4 Eureka Discovery Server

**Port:** 8761

Responsibilities:

- Register the gateway and all running domain-service instances
- Publish service instance host, port, and health metadata
- Support discovery-aware internal clients and gateway load balancing

The single-node capstone Eureka server is private and not highly available. It does not register with itself. Config Server remains reachable through a fixed private address so the platform can bootstrap in a deterministic order.

### 4.5 Keycloak Identity Provider

Responsibilities:

- Registration, login, logout, password reset, and email verification
- OIDC/OAuth2 sessions
- Access and refresh token issuance
- Global `USER`, `MODERATOR`, and `ADMIN` roles
- Global account enablement/disablement

Keycloak is the source of truth for credentials and global roles. It uses durable PostgreSQL storage in production. `start-dev` and in-memory H2 are development-only.

### 4.6 User Management Service

**Port:** 8081
**Schema:** `iam`

Responsibilities:

- Create a Navio profile from the Keycloak subject on first login
- Profile, handle, avatar, bio, location, privacy, and preferences
- Saved vehicles and default vehicle
- User administration, suspension history, and audit logging
- Global role grant/revoke facade over the Keycloak Admin API
- Read-only local role snapshots for display/audit, never role authority
- User lifecycle outbox events

It never stores passwords, authenticates credentials, or issues JWTs.

### 4.7 Trip Planning Service

**Port:** 8082
**Schema:** `trip`

Responsibilities:

- Trip metadata and date range
- Itinerary/list blocks and ordered items
- Places, notes, checklists, reservations, attachments, budget, and expenses
- Trip member permissions: owner/editor/viewer
- Per-trip selected vehicle snapshot
- Revision history and rollback
- Private, unlisted, and public visibility
- Public Explore catalogue and trip full-text search
- Share-link lifecycle
- Copy public/community trips as independent private trips
- Persist route and EV-result snapshots supplied by Mobility & EV
- Trip integration events through a transactional outbox

Copy rules:

- The source must be copyable at request time.
- The new trip is private and owned by the copying user.
- Later source changes or deletion do not affect existing copies.
- Only lightweight source attribution is retained.
- Community never writes the `trip` schema.

### 4.8 Mobility & EV Service

**Port:** 8083
**Schema:** `ev`

Responsibilities:

- Destination/place autocomplete, search, details, nearby discovery, and geocoding
- Google Maps Platform adapter for v1
- Optional Mapbox/provider adapters behind internal interfaces
- Road route geometry, distance, duration, and ETA
- EV energy feasibility and recommended charging stops
- Local PostGIS charger read model
- Geo-tile refresh, provider quotas, and Caffeine hot cache
- Lazy provider detail loading
- Connector compatibility and charging-time estimates
- Charger reviews, comments, reports, suggested edits, and administrator verification
- Provider failure degradation using cached/stale data

Provider calls occur only on cache miss, stale/low-confidence coverage, explicit refresh, or lazy detail load. The frontend must not freely call billable providers.

### 4.9 Community Service

**Port:** 8084
**Schemas:** `social`, `notif`, `media`

Responsibilities:

- Groups, membership, rules, flairs, moderators, and discovery
- Posts, threaded comments, votes, bookmarks, reports, and feed ranking
- Community-local full-text search
- Community post attachments referencing public `tripId` values
- Denormalized public-trip snapshots consumed from Trip events
- Media upload sessions, metadata, validation status, and safe rendering URLs
- Embedded notification inbox, unread count, preferences, mark-read, and delivery jobs
- Idempotent consumption of user/trip/mobility integration events

There is no standalone Notification Service. Community writes same-domain notifications in its own transaction and consumes cross-domain events asynchronously.

### 4.10 AI Planning Service

**Port:** 8085
**Schema:** `ai`
**Deployment:** ML VM with Ollama, or application VM with hosted provider

Responsibilities:

- Validate Keycloak JWTs and AI entitlement/quota
- Store prompt versions, sessions, messages, usage, and tool audit
- Build compact authorized trip context
- Execute a bounded agent/tool loop
- Stream responses using SSE
- Validate structured output against server-owned schemas
- Return proposed trip actions and warnings
- Require explicit confirmation before mutation
- Call Trip Planning and Mobility & EV through allow-listed APIs
- Apply provider-specific timeouts, retries, circuit breakers, and cost limits

Initial tools:

```text
get_trip
get_trip_itinerary
get_trip_budget
search_places
get_place_details
calculate_route
find_ev_chargers
estimate_ev_feasibility
propose_trip_changes
```

AI has no direct access to another service's schema. Prompt instructions never override authorization checks.

## 5. API routing and discovery

Production request flow is `Client -> NGINX :443 -> Spring Cloud Gateway :8080 -> Eureka-resolved service`. Development uses the same Spring Cloud Gateway routes and may omit only the NGINX edge hop.

| Public prefix | Spring Cloud Gateway target |
| --- | --- |
| `/v1/users/**`, `/v1/admin/users/**` | User Management :8081 |
| `/v1/trips/**`, `/v1/public-trips/**`, `/v1/share/**` | Trip Planning :8082 |
| `/v1/places/**`, `/v1/routes/**`, `/v1/geo/**`, `/v1/ev/**`, `/v1/chargers/**` | Mobility & EV :8083 |
| `/v1/community/**`, `/v1/groups/**`, `/v1/posts/**`, `/v1/feed/**`, `/v1/notifications/**`, `/v1/media/**` | Community :8084 |
| `/v1/ai/**` | AI Planning :8085 |
| `/auth/**` | Keycloak through the configured edge/auth route |

Gateway routes use stable public paths and explicit Eureka service IDs; raw default `/serviceId/**` discovery routes are not exposed. All public APIs use `/v1`. The public share-token resolver may be anonymous; all other endpoints require a Keycloak bearer token unless explicitly documented.

## 6. Authorization model

| Permission | Owner |
| --- | --- |
| Login, credentials, global roles | Keycloak |
| Role administration facade and audit | User Management |
| Trip owner/editor/viewer | Trip Planning |
| Group owner/moderator/member | Community |
| Post/comment author permissions | Community |
| Charger reviewer/submitter/admin checks | Mobility & EV |
| AI quota, model access, tool authorization | AI Planning |

Do not create Keycloak roles for individual resources. A `trip-123-editor` realm role would be unbounded and couples identity infrastructure to domain data.

## 7. Data architecture

### 7.1 Ownership

| Schema | Owner | Purpose |
| --- | --- | --- |
| `iam` | User Management | Profiles, preferences, vehicles, suspensions, role/audit snapshots, outbox |
| `trip` | Trip Planning | Trips, planning modules, permissions, revisions, share/copy, outbox |
| `ev` | Mobility & EV | Chargers, geo tiles, provider data, reviews, moderation, outbox |
| `social` | Community | Groups, posts, comments, votes, bookmarks, reports, outbox |
| `notif` | Community | Preferences, notifications, delivery log, consumed events |
| `media` | Community | Media assets and upload sessions |
| `ai` | AI Planning | Prompts, sessions, messages, usage, quotas, tool calls |

Keycloak uses a separate database/schema not owned by a Navio service.

### 7.2 Boundary rules

1. Each service uses a database role limited to owned schemas.
2. Cross-schema joins and foreign keys are prohibited.
3. Cross-domain IDs are soft references validated through APIs or events.
4. Consumer projections are disposable copies, not alternate authorities.
5. AI session data may live in the application PostgreSQL instance while being owned exclusively by AI Planning on the other VM.

### 7.3 Search

- Trip Planning owns public-trip search for Explore.
- Community owns group/post/comment search.
- Mobility & EV owns charger and geo search.
- No dedicated Search Service or Elasticsearch is used for v1.

## 8. Messaging and events

### 8.1 Kafka decision

Kafka is retained for asynchronous cross-service propagation. It is not used for synchronous commands, queries, login, route calculation, or AI streaming.

The application VM runs one KRaft broker with short retention. ZooKeeper and Schema Registry are not deployed. A single broker is not highly available; PostgreSQL outbox rows remain the recoverable source until publishing succeeds.

For local development, the root Compose stack runs Confluent Platform 8.x with a single process in combined `broker,controller` mode. Host processes connect to `localhost:29092`, while containers on `navio-network` connect to `kafka:9092`. Kafka metadata and topic data persist in the named `kafka-data` volume, and the configured KRaft cluster ID must remain stable for that volume.

Combined mode is a development and capstone resource compromise, not a highly available production topology. A production deployment requiring Kafka availability must separate broker and controller roles and use an odd controller quorum of at least three nodes. An existing ZooKeeper-backed cluster with valuable data must be migrated through a supported bridge release before upgrading to Kafka 4.x or Confluent Platform 8.x; its ZooKeeper data directory cannot be mounted directly as KRaft storage.

Operational configuration follows the [Confluent KRaft Docker reference](https://docs.confluent.io/platform/current/installation/docker/config-reference.html) and the [Apache Kafka KRaft deployment guidance](https://kafka.apache.org/40/operations/kraft/).

### 8.2 Topics

| Topic | Producer | Consumers | Examples |
| --- | --- | --- | --- |
| `user.events.v1` | User Management | Trip, Community, Mobility & EV | `UserRegistered`, `UserProfileUpdated`, `UserRoleChanged`, `UserSuspended` |
| `trip.events.v1` | Trip Planning | Community | `TripPublished`, `TripUpdated`, `TripDeleted`, `TripCopied` |
| `community.events.v1` | Community | Notification/audit module | `PostCreated`, `CommentCreated`, `ReplyCreated`, `PostReported` |
| `mobility.events.v1` | Mobility & EV | Community/admin consumers | `ChargerSubmitted`, `ChargerVerified`, `ChargerStatusChanged` |

Do not emit one event per post/comment vote. Publish aggregate score snapshots only when another bounded context needs them.

### 8.3 Event envelope

```json
{
  "eventId": "01J...",
  "eventType": "TripPublished.v1",
  "occurredAt": "2026-08-22T12:34:56Z",
  "producer": "trip-planning-service",
  "partitionKey": "trip-id",
  "traceId": "request-trace-id",
  "payload": {}
}
```

### 8.4 Transactional outbox

1. The service writes domain state and an outbox row in one transaction.
2. An embedded publisher sends unpublished rows to Kafka.
3. It marks the row published only after broker acknowledgement.
4. Consumers record `eventId` and ignore duplicates.
5. Domain operations still complete if Kafka is temporarily unavailable.

## 9. AI workflow

### 9.1 Request flow

```text
1. Frontend calls POST /v1/ai/plan/chat through Spring Cloud Gateway; NGINX is the production edge hop.
2. AI Planning validates the Keycloak JWT and quota.
3. AI Planning calls Trip Planning for authorized compact context.
4. Spring AI invokes the configured ChatModel.
5. The model may request an allow-listed tool.
6. AI Planning authorizes, executes, and records the tool call.
7. The model returns a schema-constrained proposal.
8. AI Planning validates and streams the proposal.
9. The frontend displays a preview.
10. User confirmation triggers a version-checked Trip Planning command.
```

### 9.2 Provider profiles

| Concern | Ollama profile | Hosted-provider profile |
| --- | --- | --- |
| AI service location | ML VM | Application VM |
| Model runtime | Ollama, localhost | Provider HTTPS API |
| Extra VM | Required | Not required |
| Local inference cost | No per-token bill | Provider pricing applies |
| Latency/quality | CPU-bound small model | Provider-dependent, generally stronger |
| Data handling | Remains on Navio VM except tools | Prompt/context sent to provider |
| Capacity | One generation initially | Provider/account limits |

### 9.3 Guardrails

- Maximum agent/tool iterations per request
- Maximum prompt and response size
- Tool allow list and typed parameters
- Schema validation with bounded retries
- Per-user daily/monthly quotas
- Cancellation and provider timeouts
- Sensitive-data minimization and log redaction
- Optimistic version check before applying trip changes
- No automatic destructive actions

## 10. Caching and external providers

- Use Caffeine per service for short-lived hot data.
- Store durable EV charger cache and tile freshness in Postgres/PostGIS.
- Do not cache authorization decisions longer than token/resource changes permit.
- Apply circuit breakers and strict timeouts to maps, charger providers, Keycloak administration, Ollama, and hosted AI APIs.
- Non-secret provider endpoints, timeouts, and feature flags come from Config Server.
- Provider API keys and credentials come from environment variables or mounted secrets, never the Config repository.

## 11. Security

### 11.1 North-south

- Only NGINX is publicly reachable in production.
- TLS is mandatory outside local development.
- NGINX forwards application API traffic to Spring Cloud Gateway.
- The gateway preserves `Authorization`, `X-Request-Id`, W3C trace context, and applies shared routing policies.
- Each service validates issuer, audience, expiry, and signature.

### 11.2 East-west

- Both VMs communicate over a private network.
- Internal endpoints require a service credential in addition to network restrictions.
- PostgreSQL permits the AI VM only for the AI-owned database role/schema.
- Gateway, Config Server, Eureka, Kafka, Actuator, telemetry, and domain-service ports are not internet-facing.
- Ollama listens on loopback only.

### 11.3 Secrets

- Environment variables or protected mounted files for v1
- No secrets in Git, images, frontend bundles, or logs
- Config Server Git repositories contain non-secret configuration only
- Separate database credentials per service
- Hosted AI provider keys available only to AI Planning

## 12. Observability

Observability is mandatory and covers logs, metrics, and traces. The 8 GB deployment profile uses a lightweight collector on each VM and a hosted centralized backend.

```text
Spring services / NGINX / Keycloak / Kafka / PostgreSQL / Ollama
                         |
                         v
               Grafana Alloy collector
                         |
                         v
       hosted logs / metrics / sampled traces
                         |
                         v
                    Grafana UI
```

- Spring Boot Actuator health, liveness, readiness, and Prometheus-compatible metrics
- Micrometer Observation/Tracing with OpenTelemetry/OTLP export
- Structured JSON logs to standard output
- Required fields: timestamp, level, service, environment, instance, request ID, trace ID, span ID, event, and safe error summary
- Correlation context propagated through NGINX, Gateway, REST, Kafka headers, and AI tool calls
- Grafana Alloy collects container/system logs, scrapes or receives metrics, and exports sampled traces
- Dashboards and alerts for HTTP latency/error rate, JVM/container resources, gateway failures, Config repository health, Eureka registrations, outbox backlog, Kafka consumer lag, provider failures, AI usage/latency, disk space, and Ollama queue length
- Logs redact bearer tokens, passwords, cookies, database credentials, model-provider keys, prompt secrets, and unnecessary personal data
- Local files are rotated and retained only as a short outage buffer; the hosted backend is the centralized retention/search system

Self-hosting Grafana, Loki, Prometheus, and Tempo is not approved on the current 8 GB application VM. It requires a separate observability VM or an application-server upgrade to at least 16 GB.

## 13. Resource plan

### 13.1 Application VM budget

| Component | Expected RAM |
| --- | ---: |
| Ubuntu and system processes | 0.8–1.1 GB |
| Docker, NGINX, and Grafana Alloy | 0.25–0.45 GB |
| Next.js production server | 0.25–0.45 GB |
| PostgreSQL/PostGIS | 0.7–1.0 GB |
| Keycloak | 0.5–0.7 GB |
| Four core Spring services | 1.4–1.8 GB combined |
| Gateway, Config Server, and Eureka | 0.7–1.0 GB combined |
| Kafka KRaft broker | 0.5–0.8 GB |
| Headroom/page cache | Approximately 1.0–1.8 GB |

This is a tight capstone budget, not a high-availability production profile. Build artifacts in CI, configure explicit JVM/container limits, keep telemetry sampling/queues bounded, and use a small emergency swap file. When the hosted-provider AI profile adds AI Planning to this VM, 8 GB has little safe headroom; 16 GB is the recommended upgrade before sustained production use.

### 13.2 ML VM budget

| Component | Expected RAM |
| --- | ---: |
| Ubuntu and system processes | 0.8–1.2 GB |
| AI Planning Service | 0.35–0.55 GB |
| Ollama plus small quantized model/context | Approximately 3–5.5 GB |
| Headroom | Approximately 1–3 GB |

Use one small quantized model, constrained context, and one active generation until measurement proves a higher limit safe.

### 13.3 Storage

- Keep at least 10 GB free on each VM.
- Rotate application, Gateway, Config Server, Eureka, NGINX, Keycloak, Kafka, PostgreSQL, Alloy, and Ollama local logs.
- Keep Kafka retention short because PostgreSQL outboxes are the recovery source.
- Cap local media uploads or use external object storage.
- Keep database backups off-host.
- Pre-download approved Ollama models; do not allow unbounded runtime model pulling.

## 14. Deployment and failure behavior

| Failure | Expected behavior |
| --- | --- |
| NGINX unavailable | Production ingress fails; private gateway health remains available |
| Spring Cloud Gateway unavailable | Public application APIs fail; domain services remain running but private |
| Config Server unavailable | Running services retain loaded configuration; new starts and centralized refresh may fail and alert |
| Eureka unavailable | Existing cached discovery may work briefly; new registrations/discovery updates fail and alert |
| Keycloak unavailable | Existing unexpired JWTs may continue; new login/refresh and role administration fail |
| Kafka unavailable | Core transactions commit with outbox backlog; asynchronous projections/notifications lag |
| Maps/provider unavailable | Serve cached/stale data or return a controlled partial result |
| ML VM/Ollama unavailable | AI endpoints degrade; all four core domains remain available |
| Hosted AI provider unavailable | AI endpoints degrade through circuit breaker; core domains remain available |
| AI Planning unavailable | No effect on manual planning or community workflows |
| PostgreSQL unavailable | Stateful application operations are unavailable; alert and restore |
| Hosted observability backend unavailable | Core traffic continues; Alloy and bounded local buffers retry without blocking requests |

Startup order is: PostgreSQL/Kafka/Keycloak dependencies, Config Server, Eureka, domain services, Spring Cloud Gateway, NGINX, and telemetry verification. Config Server uses a fixed private address and never depends on Eureka. Deploy domain services with stop/start rolling by service, keep previous artifacts and migration compatibility for rollback, and deploy AI independently.

## 15. Non-negotiable rules

1. Five domain Spring Boot services exist only when AI is enabled; four are core.
2. Gateway, Config Server, and Eureka are three mandatory Spring platform applications, bringing the maximum total to eight Spring projects.
3. Spring Cloud Gateway is used in development and production; NGINX is the production edge and never replaces it.
4. Config Server contains versioned non-secret configuration only and starts independently of Eureka.
5. Gateway and domain services register with Eureka; the registry is private.
6. Centralized structured logging, metrics, and sampled traces are mandatory.
7. Keycloak is authoritative for credentials and global roles.
8. User Management is the administration facade and audit owner for global role changes.
9. Resource-level authorization belongs to the resource-owning service.
10. No cross-schema reads, joins, writes, or foreign keys.
11. Kafka is for asynchronous integration events only.
12. Notification remains inside Community for v1.
13. AI proposes typed actions; Trip Planning validates and applies after confirmation.
14. AI provider selection is configuration, not a public API or domain-model change.
15. Ollama is never internet-facing.
16. Failure of AI or observability must never disable core Navio workflows.

## 16. Implementation order

1. Private networking, PostgreSQL/PostGIS, Kafka, Keycloak, and secrets
2. Config Server with private versioned configuration and deterministic bootstrap
3. Eureka Discovery Server and service registration
4. Spring Cloud Gateway routes, shared filters, and NGINX production edge
5. Grafana Alloy, structured logging, metrics, sampled tracing, dashboards, and alerts
6. User Management and Keycloak integration
7. Trip Planning, permissions, public Explore, sharing, and copy
8. Mobility & EV provider adapters, routing, charger cache, and EV calculations
9. Community, media, search, and notification module
10. Transactional outbox events and operational hardening
11. AI Planning with Spring AI
12. Choose either Ollama/ML-VM profile or hosted-provider/no-ML-VM profile for the deployment environment

## 17. Future extraction criteria

- Extract Notification only after multiple delivery channels and independent scaling/retry needs appear.
- Extract Media only after processing volume or ownership becomes operationally independent.
- Add a dedicated Search Service only when cross-domain scale exceeds PostgreSQL projections.
- Add Redis only for multi-instance shared-cache requirements.
- Scale Kafka beyond one broker only when durability/availability requirements justify it.
- Move from CPU-only Ollama to a GPU host when local-model latency or model size becomes a product constraint.

---

This document is the authoritative architecture contract. The API, OpenAPI, database, root README, and server README must use these component names, ports, ownership boundaries, and deployment profiles.
