**Project:** TripPlanner + EV Charger Integration + Community Sharing + Forking + (Bonus) AI Planning Assistance
**Deployment Model:** Single University VM (8 GB RAM)
**Status:** Approved for Implementation
**Date:** 2026-02-07
**Revised:** 2026-02-12 — Consolidated for 8 GB single-VM deployment (~10 users)

---

## 0) Executive Summary

This system is a **microservices + event-driven** trip planning platform with built-in **EV charging intelligence**, a **Reddit-like community layer** for posting and discussing travel plans, and a **forking model** to remix itineraries with attribution. It is consolidated into **4 domain-aligned Spring Boot services** behind an **NGINX reverse proxy**, running on a **single 8 GB university VM**. Async processing (notifications, EV refresh) uses a **Kafka single-broker** setup. All data is stored in a **single PostgreSQL instance** with schema-per-service isolation (7 schemas). Full-text search uses Postgres `tsvector` + `pg_trgm` (no Elasticsearch). Caching is handled by **Caffeine** in-process caches (no Redis). Centralized non-secret configuration is managed by **Spring Cloud Config Server**. A bonus AI capability provides planning assistance via a dedicated AI Orchestrator that calls domain service APIs (never cross-service database reads).

---

## 1) Goals, Scope, Assumptions

### 1.1 Goals

- Fast, reliable trip planning UX with map routing + EV charging stops.
- Social layer for publishing, commenting, voting, bookmarking.
- Sharing and forking with lineage and attribution.
- Lean operational footprint on a single university VM (8 GB RAM, ~10 users).

### 1.2 In Scope

- Trip CRUD + revisions + publish/unpublish + share links + fork lineage
- EV charger discovery + route/charge-stop computation + caching + refresh workers
- Community posts + comments (threaded) + moderation basics + bookmarks + voting/scoring
- Search across trips/posts via Postgres full-text search
- Notifications (in-app + optional email/push)
- Media uploads (safe pipeline: signed upload + scanning + thumbnails)
- AI planning assistance (structured edits + quota/budget enforcement)

### 1.3 Out of Scope (for v1.0)

- Real-time collaborative editing (explicitly removed)
- Payments/subscriptions
- Full-blown analytics warehouse (optional later)
- High availability / multi-instance (single-instance deployment)

### 1.4 Assumptions

- Frontend: Next.js + Keycloak (OIDC/JWT)
- Backend: Spring Boot (4 consolidated services), Kafka single broker
- **Database:** Single PostgreSQL instance (with PostGIS extension), 7 schemas (`trip`, `iam`, `media`, `ev`, `social`, `notif`, `ai`) — schema-per-service isolation on one physical instance
- **Messaging:** Kafka single broker, JSON serialization (no Schema Registry)
- **Caching:** Caffeine in-process JVM caches (no Redis)
- **Search:** Postgres `tsvector` generated columns + `pg_trgm` extension (no Elasticsearch)
- **Trips:** Postgres + JSONB columns for nested structures (no MongoDB)
- **Gateway:** NGINX reverse proxy with static routing to `localhost` ports (no Spring Cloud Gateway)
- **Service Discovery:** Static routing via NGINX config (no Eureka)
- **Configuration:** Spring Cloud Config Server (Git-backed, single node) for centralized non-secret config (feature flags, timeouts, Kafka topic names, external API URLs)
- **Secrets:** Environment variables or encrypted local files (no Vault — acceptable for university project)
- **Observability:** Spring Boot Actuator + structured JSON log files (lightweight; no dedicated OTel/Prometheus/Grafana stack unless RAM permits)
- **Scale:** ~10 concurrent users, < 5 RPS total
- External Providers:
  - Maps/Routing/Geocoding: Google Maps or Mapbox (or equivalent)
  - EV Charger data: OCPI/network APIs/aggregator
  - Messaging: SendGrid/Twilio/FCM/APNs (as needed)
  - LLM: Gemini (via AI SDK in UI, orchestrated on server)

---

## 2) Requirements

### 2.1 Functional Requirements

**Trips**

- Create/edit/delete trips with stops, notes, dates
- Revision history and rollback to a specific revision
- Publish/unpublish and visibility transitions (private/unlisted/public)
- Share links (create/revoke, expiry optional)
- Fork trips with attribution chain (origin + derived forks)
- On original trip deletion, forks retain a snapshot of origin metadata (title, author display name) but mark the origin reference as deleted; no cascading deletion of forks

**EV Integration**

- Vehicle profiles (connector, battery, consumption model)
- Charger lookup near stop with filters (connector, power, network)
- EV route feasibility and charge-stop recommendations
- Cached charger data in Postgres with scheduled refresh and graceful degradation

**Community**

- Create posts (manual "Share to Community" flow)
- Feed views (new/top, tags)
- Threaded comments (top-level + replies via optional `parentCommentId`)
- Votes with upsert semantics (one vote per user per post; +1 / -1 / 0 to retract)
- Bookmarks
- Moderation: report, delete post/comment, ban/unban users (via IAM)

**Search**

- Search trips/posts with visibility enforcement via Postgres full-text search
- Incrementally maintained via `tsvector` generated columns

**Notifications**

- In-app inbox and preferences
- Dispatch worker for email/push/SMS (optional)
- Notifications from: comments, replies, forks, moderation actions, etc.

**Media**

- Signed upload URLs
- Scan/validate + thumbnails via embedded worker
- Store metadata and safe rendering URLs

**AI (Bonus)**

- Suggest itinerary changes and EV improvements
- Chat-with-plan grounded on plan context
- Outputs structured actions; server validates and applies
- Cost/budget quota enforcement

---

### 2.2 Non-Functional Requirements (NFRs)

**Availability Targets**

- Best-effort single-instance availability (no HA target)
- Fast restart via `systemd Restart=always`
- Degradation when providers fail (maps/EV/LLM): serve cached or partial where possible

**Latency Targets (P95)**

- Trip load: **< 500ms**
- Feed/search: **< 500ms**
- EV compute: **< 2–5s typical** (async if heavy)
- AI: "first token" best-effort < 1s; streaming supported

**Throughput (sizing assumptions)**

- Peak concurrency: **~10** users
- Peak reads: **< 5 RPS**
- Trip writes: **< 5 writes/min peak**
- Search queries: **< 5 RPS peak**
- EV compute: **< 1 RPS peak**
- AI: **< 0.5 RPS peak** (expensive; must be throttled)

**Security**

- OIDC/JWT auth (Keycloak)
- Resource-level authorization (plan ACL)
- Service-to-service auth: shared secret header (all services on localhost)
- Secrets in environment variables (acceptable for university project)
- Audit logs for sensitive operations

**Data Retention**

- Kafka retention: domain events 7–14d, commands 3–7d, DLQ 14–30d
- Notifications: 90d (configurable)
- Trip revisions: capped (last 100 or 90d) with pinned snapshots allowed

---

## 3) Architecture Overview

### 3.1 Architectural Style

- **Microservices** (4 consolidated services) with **schema-per-service** isolation on a single PostgreSQL instance
- **Event-driven** pipelines via Kafka single broker for async tasks
- **NGINX reverse proxy** for routing and TLS termination
- **Workers embedded** as `@Scheduled` background tasks within parent services (no separate worker processes)

### 3.2 High-Level Components

**Frontend**

- Next.js client
- Keycloak auth
- Zod validation
- Arcjet for app-level rate limiting (fine-grained, auth-aware)

**Core Backend**

- NGINX reverse proxy (static routing to localhost ports)
- Spring Cloud Config Server (centralized non-secret config, Git-backed)
- 4 Spring Boot services (Trip & Media, EV Intelligence, Community, AI Orchestrator)
- Kafka single broker + DLQ topics (JSON serialization)
- Single PostgreSQL instance (7 schemas)
- Caffeine in-process caches (per JVM)
- MinIO or local filesystem for object storage

**Observability**

- Spring Boot Actuator endpoints (`/actuator/health`, `/actuator/metrics`)
- Structured JSON logs (logback) with correlation ID propagation
- Optional: lightweight Prometheus + Grafana if RAM permits (~300 MB)

---

## 4) Service Inventory (Responsibilities, Data, Integrations)

### 4.1 NGINX (Reverse Proxy)

**Responsibilities**

- Static routing by URL prefix to service `localhost` ports
- TLS termination (if HTTPS configured)
- Basic rate limiting (connection/request limits)
- Public route exception: `GET /v1/share/{token}` forwarded without JWT validation
- Serves Next.js static assets (optional)

**Data**

- Stateless

**Routing Table**

| Path Prefix                                                               | Target                              |
| ------------------------------------------------------------------------- | ----------------------------------- |
| `/v1/trips/**`, `/v1/share/**`, `/v1/media/**`, `/v1/mod/**`, `/v1/me/**` | Trip & Media Service (port 8081)    |
| `/v1/ev/**`                                                               | EV Intelligence Service (port 8082) |
| `/v1/posts/**`, `/v1/feed/**`, `/v1/search/**`, `/v1/notifications/**`    | Community Service (port 8083)       |
| `/v1/ai/**`                                                               | AI Orchestrator Service (port 8084) |

---

### 4.2 Spring Cloud Config Server

**Responsibilities**

- Centralized externalized configuration for all 4 services
- Git-backed config repo: stores feature flags, timeouts, Kafka topic names, external API URLs, retry settings, EV refresh intervals
- Profile-based config: `application-{profile}.yml` for dev/staging/prod
- Runtime config refresh via `/actuator/refresh` (Spring Cloud Bus optional)

**Data**

- Stateless (config stored in Git repo)

**RAM**

- Single node, `-Xmx128m` (~192 MB total)

---

### 4.3 Trip & Media Service (Postgres schemas: `trip`, `iam`, `media`)

**Responsibilities**

- **Trip domain:** Trip CRUD + revisions + rollback to specific revision. Trips stored as Postgres rows with JSONB columns for `stops[]`, `routeLegs[]`, `evProfile`. Full-text search via `tsvector` generated column.
- **Visibility transitions:** private/unlisted/public
- **Share link** create/revoke
- **Forking** and lineage/origin queries. On original trip deletion: forks retain origin metadata snapshot, `originTripId` marked as tombstone.
- **Routing/ETA** integration with Maps provider
- **IAM domain:** App user profile mirror + preferences, roles (user/mod/admin), ban/unban users, ACL engine (generic resource ACL storage and evaluation)
- **Media domain:** Issues pre-signed upload URLs, stores metadata in `media` schema, returns safe rendering URLs
- **Embedded Media Worker** (`@Scheduled`): polls for uploaded files, runs virus scan + mime/size validation, generates thumbnails, updates metadata status (ready/blocked)
- **Embedded Outbox Publisher** (`@Scheduled`): polls `trip.outbox` and `iam.outbox` tables, publishes events to Kafka, marks rows as published
- Enforces trip access authorization (ACL checks in-process via IAM schema, same JVM)
- Fetches config from Config Server on startup

**Data Ownership**

- `trip` schema: trips, revisions, share tokens, fork graph, outbox
- `iam` schema: users, roles, bans, ACL entries, audit log, outbox
- `media` schema: media metadata

**Events Produced**

- `TripCreated.v1`, `TripUpdated.v1`, `TripDeleted.v1`
- `TripVisibilityChanged.v1`, `TripForked.v1`
- `TripShareLinkCreated.v1`, `TripShareLinkRevoked.v1`
- `UserRegistered.v1`, `UserProfileUpdated.v1`, `UserDeactivated.v1`
- `UserBanned.v1`, `UserUnbanned.v1`, `UserNotificationPrefsUpdated.v1`

**Event Publishing**

- **Transactional Outbox Pattern** (see §8) — domain events written to outbox tables within the same DB transaction as the domain write, then published by embedded poller

---

### 4.4 EV Intelligence Service (Postgres schema: `ev`)

**Responsibilities**

- Charger provider integrations (OCPI/aggregator APIs)
- Charger search near geo point + filters using PostGIS (`ST_DWithin`)
- EV leg feasibility + charge-stop recommendation
- Charger data stored in Postgres `ev.chargers` table with `expires_at` column + Caffeine in-process cache overlay (30–60s TTL)
- **Embedded EV Refresh Worker** (`@Scheduled`): periodic charger data pulls per geo-tile and provider, updates `ev.chargers` table, publishes `ChargerCacheRefreshed.v1` to Kafka
- Fetches config from Config Server on startup (refresh intervals, provider URLs, tile settings)

**Data Ownership**

- `ev` schema: chargers (durable geo-indexed cache), provider metadata, outbox

**Events Produced**

- `ChargerCacheRefreshed.v1`
- `ChargerStatusUpdated.v1` (if provider supports)

**Degradation**

- Provider down → serve stale Postgres data + mark "stale"

---

### 4.5 Community Service (Postgres schemas: `social`, `notif`)

**Responsibilities**

- **Social domain:** Posts, threaded comments, tags, bookmarks, moderation (reports, deletes by mods/admin), vote handling (upsert per user per post) and ranking/score. **Manual "Share to Community"** creates a post linked to `tripId`.
- **Search domain:** Full-text search via Postgres `tsvector` columns on `social.posts`. For trip search, queries Trip & Media Service API or maintains a denormalized search materialized view.
- **Notification domain:** Notification inbox, preferences, mark-read. Stores in-app notifications in `notif` schema.
- **Embedded Notification Dispatcher** (`@Scheduled` Kafka consumer): consumes domain events from `trip.events.v1`, `community.events.v1`, `iam.events.v1` topics. Applies notification rules (determines who to notify and via which channels). Writes to `notif.notifications`. Sends via email/push/SMS providers (optional). Also consumes `notification.commands.v1` for system/admin-triggered notifications.
- **Embedded Outbox Publisher** (`@Scheduled`): polls `social.outbox` table, publishes events to Kafka
- Fetches config from Config Server on startup

**Data Ownership**

- `social` schema: posts (with `search_vector` tsvector column), comments (with `parentCommentId` for threading), bookmarks, reports, vote records/aggregates, outbox
- `notif` schema: notification preferences, notifications, delivery log

**Events Produced**

- `PostCreated.v1`, `CommentCreated.v1`, `PostReported.v1`, `PostDeleted.v1`
- `PostScoreUpdated.v1` (aggregated snapshot — avoid per-vote Kafka hot partitions)

---

### 4.6 AI Orchestrator Service (Postgres schema: `ai`)

**Responsibilities**

- Calls LLM provider (Gemini)
- Maintains prompt versions and tool schemas
- Produces **structured plan edit actions**, validates, and applies by calling:
  - Trip & Media Service API
  - EV Intelligence Service API
- **Quota/budget enforcement**: Postgres `ai.quota_counters` is the **source of truth** for per-user quota counters (tokens used/month, cost/month). Caffeine in-process cache for hot-path rate checks (30s TTL, backed by Postgres).
- Logging with redaction (no raw secrets/PII in logs)
- Fetches config from Config Server on startup (LLM model, temperature, quota limits)

**Data Ownership**

- `ai` schema: prompt configs, sessions, usage logs, quota counters

**DB**

- Postgres: configs, logs, quota counters (durable)
- Caffeine: quota fast-path cache (ephemeral, in-process)

**Hard Rule**

- **No cross-service DB access** — AI uses APIs only

---

## 5) API Design (REST, Versioned)

### 5.1 Versioning

- All public endpoints: `/v1/...`
- Internal service-to-service endpoints are also versioned

### 5.2 Authentication Model

- Default: JWT required (each service validates via `spring-security-oauth2-resource-server`)
- Explicit public allowlist:
  - `GET /v1/share/{token}` — no JWT, routed to Trip & Media Service

### 5.3 Key Endpoints (by domain)

**Trip & Media Service**

- `POST /v1/trips` — create trip
- `GET /v1/trips/{tripId}` — get trip
- `PATCH /v1/trips/{tripId}` — update trip
- `DELETE /v1/trips/{tripId}` — delete trip
- `GET /v1/trips/{tripId}/revisions` — list revision history
- `POST /v1/trips/{tripId}/rollback` — rollback to specific revision; body: `{ "revisionId": "..." }`
- `POST /v1/trips/{tripId}/visibility` — change visibility (private/unlisted/public)
- `POST /v1/trips/{tripId}/fork` — fork trip
- `GET /v1/trips/{tripId}/forks` — list forks of this trip
- `GET /v1/trips/{tripId}/origin` — get fork origin/lineage
- `POST /v1/trips/{tripId}/share-links` — create share link
- `DELETE /v1/trips/{tripId}/share-links/{tokenId}` — revoke share link
- `GET /v1/share/{token}` — resolve share link _(public, no JWT)_
- `POST /v1/trips/{tripId}/permissions` — manage ACL _(delegates to IAM logic internally)_
- `GET /v1/trips/{tripId}/permissions` — view ACL
- `GET /v1/me` — current user profile
- `PATCH /v1/me/preferences` — update preferences
- `POST /v1/mod/users/{userId}/ban` — ban user _(mod/admin)_
- `POST /v1/mod/users/{userId}/unban` — unban user _(mod/admin)_
- `POST /v1/media/upload-url` — request pre-signed upload URL
- `POST /v1/media/complete` — signal upload complete (triggers embedded worker)
- `GET /v1/media/{mediaId}` — get media metadata + safe URL

**EV Intelligence**

- `POST /v1/ev/route/compute` — compute EV-aware route feasibility + charge stops
- `GET /v1/ev/chargers/near?lat=...&lng=...&radiusKm=...&connector=...&minKw=...` — charger search

**Community Service**

- `POST /v1/posts` — create post (manual share to community; may reference `tripId`)
- `GET /v1/feed?sort=new|top&tag=...` — feed
- `GET /v1/posts/{postId}` — get post
- `GET /v1/posts/{postId}/comments?parentId=...` — list comments; omit `parentId` for top-level, provide for replies
- `POST /v1/posts/{postId}/comments` — create comment; body includes optional `parentCommentId` for threading
- `PUT /v1/posts/{postId}/vote` — cast or update vote; body: `{ "direction": 1 | -1 | 0 }`; upsert semantics (one vote per user per post; `0` retracts)
- `POST /v1/posts/{postId}/report` — report post
- `DELETE /v1/posts/{postId}` — delete post _(mods/admin)_
- `POST /v1/posts/{postId}/bookmark` — bookmark
- `DELETE /v1/posts/{postId}/bookmark` — remove bookmark
- `GET /v1/me/bookmarks` — list bookmarks
- `GET /v1/search?q=...&type=trips|posts` — search (Postgres full-text)
- `GET /v1/notifications` — inbox
- `POST /v1/notifications/{id}/read` — mark read

**AI (Bonus)**

- `POST /v1/ai/plan/suggest` — request structured suggestions
- `POST /v1/ai/plan/chat` — conversational plan assistance _(streaming)_

---

## 6) Data Architecture

### 6.1 Stores and Ownership

All schemas reside on a **single PostgreSQL instance** (`pg-primary`). Each service owns its schemas exclusively — **no cross-schema joins or foreign keys**.

| Schema         | Owner Service           | Purpose                                                      |
| -------------- | ----------------------- | ------------------------------------------------------------ |
| `trip`         | Trip & Media Service    | Trips (JSONB), revisions, share tokens, fork graph, outbox   |
| `iam`          | Trip & Media Service    | Users, roles, bans, ACL entries, audit log, outbox           |
| `media`        | Trip & Media Service    | Media metadata, upload tracking                              |
| `ev`           | EV Intelligence Service | Charger cache (PostGIS), provider metadata, outbox           |
| `social`       | Community Service       | Posts, comments, votes, bookmarks, reports, outbox           |
| `notif`        | Community Service       | Notification preferences, in-app notifications, delivery log |
| `ai`           | AI Orchestrator         | Prompt configs, sessions, usage logs, quota counters         |
| Object Storage | Trip & Media Service    | MinIO or local filesystem                                    |

### 6.2 Backup/Restore

- **Postgres**: `pg_dump` nightly (cron job) + WAL archiving to external storage. Single instance — no replication in v1.
- **Kafka**: single broker, RF=1. Topic retention is the only recovery mechanism. Snapshot critical topic configs separately.
- **Object Storage**: local filesystem backup or MinIO replication (if used).

---

## 7) Messaging & Events (Kafka)

### 7.1 Event Envelope Standard

All events must include:

```json
{
  "eventId": "evt_01J...ulid",
  "eventType": "TripPublished.v1",
  "occurredAt": "2026-02-07T12:34:56Z",
  "producer": "trip-media-service",
  "partitionKey": "trip_8b1f2c",
  "trace": { "traceId": "...", "spanId": "..." },
  "payload": {}
}
```

### 7.2 Schema Strategy

- **JSON** serialization for all events (no Protobuf, no Schema Registry)
- Schema evolution: backward-compatible (add optional fields only, never remove or rename)
- Schemas documented in a shared Git repo alongside Config Server config

### 7.3 Topics

| Topic                      | Partition Key           | Producers                         | Consumers                                                     |
| -------------------------- | ----------------------- | --------------------------------- | ------------------------------------------------------------- |
| `trip.events.v1`           | `tripId`                | Trip & Media Service (via Outbox) | Community Service (Notification Dispatcher, search denorm)    |
| `community.events.v1`      | `postId`                | Community Service (via Outbox)    | Community Service (Notification Dispatcher)                   |
| `iam.events.v1`            | `userId`                | Trip & Media Service (via Outbox) | Community Service (author name sync, Notification Dispatcher) |
| `ev.events.v1`             | `tileKey` / `chargerId` | EV Intelligence Service           | Observability (optional)                                      |
| `notification.commands.v1` | `userId`                | Admin tools, system jobs          | Community Service (Notification Dispatcher)                   |
| `*.retry.*`                | (same as source)        | Consumer retry logic              | Same consumer                                                 |
| `*.dlq.*`                  | (same as source)        | Consumer error handler            | Ops replay tooling                                            |

### 7.4 Retention

- Domain events: 7–14 days
- Commands: 3–7 days
- DLQ: 14–30 days

### 7.5 Vote Hot Partition Mitigation

- Do **not** emit per-vote events to Kafka.
- Community Service emits `PostScoreUpdated.v1` as periodic snapshots (threshold-based or time-based, e.g., every 30s if changed). This keeps the partition load bounded regardless of vote volume.

### 7.6 Kafka Broker Configuration (Single Broker)

- Single broker: `kafka-0` with `-Xmx256m`
- `default.replication.factor=1`, `min.insync.replicas=1`
- Partitions per topic: 1–3 (sufficient for < 5 RPS)
- Log directory on data disk with retention enforced
- **Limitation:** no replication — broker failure = temporary event loss until restart. Outbox tables provide source-of-truth recovery.

---

## 8) Transactional Outbox Pattern (Trip & Community Events)

**Replaces:** MongoDB Change Streams Relay from original design

**How It Works**

- Each service writes domain events to its `outbox` table within the **same database transaction** as the domain write (e.g., trip update + outbox insert in one transaction)
- An **embedded `@Scheduled` Outbox Publisher** in each service polls the outbox table every 500ms–1s for unpublished rows
- Publisher sends events to Kafka, then marks rows as `published = TRUE` and sets `published_at` timestamp
- Published rows are cleaned up periodically (delete rows older than 24h where `published = TRUE`)

**Idempotency**

- Each outbox row has a deterministic `event_id` (ULID)
- Kafka producer uses `event_id` as idempotency key
- All consumers deduplicate on `eventId`

**Advantages over Change Streams**

- Native to Postgres — no separate relay process, no resume tokens
- Exactly-once semantics within the database transaction boundary
- Simpler ops: no leader election for relay, no oplog concerns

**Services Using Outbox**

| Service                 | Outbox Table    | Kafka Topic           |
| ----------------------- | --------------- | --------------------- |
| Trip & Media Service    | `trip.outbox`   | `trip.events.v1`      |
| Trip & Media Service    | `iam.outbox`    | `iam.events.v1`       |
| Community Service       | `social.outbox` | `community.events.v1` |
| EV Intelligence Service | `ev.outbox`     | `ev.events.v1`        |

---

## 9) Caching Strategy

### 9.1 Caffeine In-Process Caches (per JVM)

All caching uses **Caffeine** (in-process, zero network overhead). No Redis.

| Cache             | Service         | Max Entries | TTL    | Eviction |
| ----------------- | --------------- | ----------- | ------ | -------- |
| Hot trips         | Trip & Media    | 200         | 60s    | LRU      |
| ACL lookups       | Trip & Media    | 500         | 10s    | LRU      |
| User profiles     | Trip & Media    | 100         | 60s    | LRU      |
| Charger data      | EV Intelligence | 500         | 30–60s | LRU      |
| AI quota counters | AI Orchestrator | 50          | 30s    | LRU      |
| Search results    | Community       | 100         | 15s    | LRU      |

### 9.2 ACL Cache (sensitive)

- TTL: **10 seconds** maximum
- Explicit cache bust on any ACL mutation (same JVM, so immediate invalidation on write)
- Conservative: if cache miss, fall through to `iam` schema query (never serve stale permissions as a grant)

### 9.3 EV Cache

- Postgres `ev.chargers` table with `expires_at` column acts as durable cache
- Caffeine overlay for hot-path reads (30–60s TTL)
- Embedded EV Refresh Worker updates Postgres table on schedule
- Mark stale on provider failure; serve stale rather than error where safe

### 9.4 Share Pages

- No CDN (10 users, not needed)
- Serve directly from Trip & Media Service

---

## 10) Security

### 10.1 North–South (Client → NGINX)

- Keycloak OIDC tokens (JWT)
- Each service validates JWT via JWKS with TTL caching (`spring-security-oauth2-resource-server`)
- Graceful degradation: valid JWTs continue to work during transient Keycloak outages (cached JWKS)

### 10.2 Authorization

- Trip & Media Service enforces permissions (owner/editor/viewer) via in-process IAM ACL queries (same JVM, same Postgres instance, but separate schema)
- Community moderation actions require mod/admin role (checked via IAM internal API call to Trip & Media Service)
- Public share tokens validated by Trip & Media Service (no JWT needed)

### 10.3 East–West (Service-to-Service)

- All services on **localhost** — no network exposure for internal calls
- Shared secret header (`X-Internal-Auth`) validated on internal endpoints
- No mTLS needed (single VM, loopback traffic only)

### 10.4 Secrets

- Stored in **environment variables** or **encrypted local files** (acceptable for university project)
- Config Server carries only non-secret configuration
- For production scale-up: migrate to Vault

### 10.5 Audit Logging

Record the following to a durable, append-only audit log (`iam.audit_log`):

- Visibility changes (trip publish/unpublish)
- Share link create/revoke
- ACL changes (add/remove collaborators)
- Bans/unbans
- Moderation deletions (post/comment removal by mod)
- Admin role grants/revocations
- AI quota overrides (if any admin action)

---

## 11) Resilience & External Dependencies

### 11.1 Patterns (services calling external APIs)

- Hard timeouts (connect + read)
- Circuit breakers (Resilience4j)
- Retries only on safe/idempotent calls, with jitter
- Fallback responses where possible

### 11.2 Degradation Policies

| Dependency                | Degradation Behavior                                               |
| ------------------------- | ------------------------------------------------------------------ |
| Maps provider down        | Show "route unavailable" or cached last-known route                |
| EV charger provider down  | Serve stale Postgres data marked "stale"                           |
| LLM provider down         | AI endpoints return 503; core product fully unaffected             |
| Keycloak down (transient) | Cached JWKS continues validating existing JWTs; new logins blocked |

### 11.3 AI Traffic Isolation

- AI traffic must not degrade core trip/community reads
- Separate rate limits and thread pools for AI Orchestrator
- AI endpoints shed load first under system pressure

### 11.4 Single-Instance Recovery

- All services configured with `systemd Restart=always`
- PostgreSQL: WAL recovery on crash
- Kafka: log-based recovery on restart
- No failover — focus on fast restart (< 30s to full service)

---

## 12) Observability & Alerting

### 12.1 Telemetry

- All services expose **Spring Boot Actuator** endpoints:
  - `/actuator/health` (liveness, readiness)
  - `/actuator/metrics` (JVM, HTTP, Kafka consumer lag)
  - `/actuator/prometheus` (optional, if Prometheus is deployed)
- **Structured JSON logs** (logback) written to rotating log files
- **Correlation IDs** propagated via MDC: frontend → NGINX (`X-Request-Id`) → services → Kafka headers

### 12.2 Alerting (Lightweight)

For a university project with ~10 users, full Alertmanager is optional. Recommended minimum:

- **Log monitoring**: grep/tail structured JSON logs for `level: ERROR` patterns
- **Health checks**: NGINX upstream health checks auto-remove unhealthy backends
- **Disk usage**: cron job alerting at 80% disk usage
- **systemd notifications**: email/webhook on service restart events

**Optional (if RAM permits ~300 MB for Prometheus + Grafana):**

| Alert                    | Condition                             |
| ------------------------ | ------------------------------------- |
| Service error rate spike | Error rate > 5% sustained 5min        |
| Kafka consumer lag       | Lag > 1000 messages sustained 10min   |
| DLQ growth               | DLQ message count > 0 sustained 15min |
| DB storage pressure      | Disk usage > 80%                      |
| Outbox backlog           | Unpublished rows > 100 sustained 5min |

---

## 13) Single-VM Deployment Blueprint

### 13.1 RAM Budget

| Component                               | Estimated RAM   |
| --------------------------------------- | --------------- |
| Linux OS + buffers                      | ~512 MB         |
| PostgreSQL (single instance, 7 schemas) | ~400 MB         |
| Kafka (single broker, `-Xmx256m`)       | ~400 MB         |
| Keycloak                                | ~512 MB         |
| Spring Cloud Config Server (`-Xmx128m`) | ~192 MB         |
| MinIO (or local filesystem)             | ~200 MB         |
| NGINX (reverse proxy)                   | ~50 MB          |
| Trip & Media Service (`-Xmx256m`)       | ~384 MB         |
| EV Intelligence Service (`-Xmx192m`)    | ~320 MB         |
| Community Service (`-Xmx256m`)          | ~384 MB         |
| AI Orchestrator (`-Xmx192m`)            | ~320 MB         |
| **Total**                               | **~3.7–4.2 GB** |
| **Remaining headroom**                  | **~3.8–4.3 GB** |

### 13.2 Process Management

- All components run as **systemd services** with `Restart=always`
- Startup order enforced via systemd dependencies:
  1. PostgreSQL → Kafka → Config Server → Keycloak → NGINX
  2. Services start after Config Server and Kafka are healthy

### 13.3 Single-Instance Deployment

| Component               | Instances | Notes                                                        |
| ----------------------- | --------- | ------------------------------------------------------------ |
| NGINX                   | 1         | Reverse proxy + static assets                                |
| Config Server           | 1         | Git-backed, centralized config                               |
| Trip & Media Service    | 1         | Includes embedded outbox publisher + media worker            |
| EV Intelligence Service | 1         | Includes embedded EV refresh worker                          |
| Community Service       | 1         | Includes embedded notification dispatcher + outbox publisher |
| AI Orchestrator         | 1         | Includes embedded quota cache refresh                        |
| PostgreSQL              | 1         | Single instance, 7 schemas, PostGIS extension                |
| Kafka                   | 1         | Single broker, RF=1                                          |
| Keycloak                | 1         | OIDC/JWT provider                                            |
| MinIO                   | 1         | Object storage (or local filesystem)                         |

### 13.4 Deploy Strategy

- **Stop-start deployment** (sufficient for ~10 users):
  1. Stop service via `systemctl stop <service>`
  2. Replace JAR artifact
  3. Run Flyway migrations (if any)
  4. Start service via `systemctl start <service>`
- **Orchestration:** simple shell scripts or Ansible playbook
- **Rollback:** keep previous JAR version, revert via script

---

## 14) Operations & Runbooks

### 14.1 Database Migrations

- **Flyway** for all 7 Postgres schemas, run before each service startup
- Backward-compatible migrations only (expand-contract pattern)
- Single `flyway migrate` command per service (schema-scoped)

### 14.2 Search Maintenance

- No separate reindex procedure — search uses live Postgres `tsvector` queries
- If `tsvector` columns become stale, run `UPDATE ... SET search_vector = ...` to regenerate
- `pg_trgm` indexes auto-maintained by Postgres on write

### 14.3 DLQ Handling

- Monitor DLQ topics via Kafka CLI tools
- Replay tool per topic with safety guards (idempotent consumers handle replays safely)
- Review required before bulk replay

### 14.4 EV Refresh

- Embedded refresh worker runs on configurable intervals (set via Config Server)
- Provider outage: serve stale data, log warnings
- Manual cache bust: truncate `ev.chargers` + trigger refresh via actuator endpoint

### 14.5 Incident Playbooks

| Scenario           | Response                                                              |
| ------------------ | --------------------------------------------------------------------- |
| Service crash      | systemd auto-restarts; check logs for root cause                      |
| Kafka broker down  | Services buffer to outbox tables; restart Kafka; events will catch up |
| Postgres down      | All services unavailable; restart Postgres; WAL recovery              |
| Keycloak outage    | Existing JWTs valid via cached JWKS; new logins fail                  |
| Config Server down | Services continue with last-fetched config; restart Config Server     |

---

## 15) Key Design Rules (Non-Negotiable)

1. **No cross-schema queries** — services own their schemas exclusively. Cross-service data access via APIs and Kafka events only. Even though all schemas are on one Postgres instance, no cross-schema joins or foreign keys.
2. **All Kafka consumers are idempotent** using `eventId` deduplication.
3. **Strict API versioning** (`/v1`) and **backward-compatible** JSON event schemas.
4. **AI Orchestrator proposes structured edits**; Trip & Media Service validates and applies.
5. **External calls wrapped with resilience primitives** (timeout, circuit breaker, fallback).
6. **Security enforced in services** (authorization at business logic layer), not only at NGINX.
7. **Events are immutable facts**; commands are explicitly labeled command topics.
8. **Search and notifications are eventually consistent** by design.

---

## 16) Decisions Log

| #   | Decision                                               | Rationale                                                                                                                                                                                         |
| --- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D1  | JSON event serialization (not Protobuf)                | No Schema Registry overhead; sufficient at < 5 RPS; simpler debugging                                                                                                                             |
| D2  | Transactional Outbox (not Change Streams)              | Native to Postgres; no separate relay process; exactly-once within TX boundary                                                                                                                    |
| D3  | Manual "Share to Community" (not auto-post on publish) | Users may not want every published trip as a community post; keeps Community Service autonomous                                                                                                   |
| D4  | No `search.index.commands.v1` topic                    | Search uses live Postgres full-text queries; no indexer pipeline needed                                                                                                                           |
| D5  | `notification.commands.v1` retained                    | Needed for admin broadcasts and system-triggered one-off notifications outside domain event flows                                                                                                 |
| D6  | Score snapshots (not per-vote events)                  | Prevents hot partitions on viral posts; vote volume doesn't scale Kafka load                                                                                                                      |
| D7  | ACL managed in-process (Trip & Media Service)          | IAM and Trip in same JVM; avoids network hop for ACL checks                                                                                                                                       |
| D8  | AI quota counters in Postgres, Caffeine fast-path      | Durability for quotas; Caffeine reduces DB queries for hot-path checks                                                                                                                            |
| D9  | Fork attribution: orphan forks on original deletion    | Forks retain origin metadata snapshot; no cascading deletes                                                                                                                                       |
| D10 | Media metadata in dedicated Postgres schema            | Clear ownership; avoids coupling media to another service's schema                                                                                                                                |
| D11 | NGINX (not Spring Cloud Gateway)                       | Saves ~300 MB RAM; static routing is sufficient for 4 services on localhost                                                                                                                       |
| D12 | 4 consolidated services (not 9+)                       | Each JVM has ~128–192 MB baseline overhead. With ~10 users at < 1 RPS, 9+ JVMs waste ~600 MB+ on idle overhead. 4 services still gives proper microservice boundaries aligned to feature domains. |
| D13 | Postgres + JSONB (not MongoDB)                         | One DB engine; simpler ops; JSONB is fully capable for trip document model; eliminates ~500 MB RAM for MongoDB                                                                                    |
| D14 | Postgres full-text search (not Elasticsearch)          | Zero extra RAM; `tsvector` + `pg_trgm` sufficient for small dataset (<100K docs); eliminates ~1.5 GB RAM for ES                                                                                   |
| D15 | Caffeine (not Redis)                                   | In-process caching, zero network overhead, zero extra RAM; sufficient for 10 users                                                                                                                |
| D16 | Static routing (not Eureka)                            | 4 services on localhost; service discovery unnecessary; saves ~256 MB RAM                                                                                                                         |
| D17 | Spring Cloud Config Server retained                    | Centralized config management for all 4 services; feature flags, timeouts, external URLs managed in one Git repo; low RAM cost (~192 MB)                                                          |
| D18 | Env vars for secrets (not Vault)                       | Acceptable for university project; saves ~256 MB RAM per Vault instance                                                                                                                           |
| D19 | Kafka single broker (not 3-broker cluster)             | Sufficient for < 5 RPS; saves ~800 MB RAM; outbox tables provide source-of-truth recovery                                                                                                         |

---

## 17) Open Items for v1.1+ (Scale-Up Path)

When user count exceeds ~50–100, consider the following scale-up steps:

- **Split services back out**: Extract IAM and Media from Trip Service when codebases grow large
- **Add Elasticsearch** when dataset exceeds ~100K documents or full-text search latency degrades
- **Add Redis** if Caffeine in-process caching becomes insufficient (multi-instance deployments need shared cache)
- **Add second VM + load balancer** for basic HA
- **Scale Kafka to 3 brokers** with RF=3 for durability
- **Add Eureka** if deploying to multiple VMs (service discovery becomes useful)
- **Migrate secrets to Vault** for production-grade secret management
- **Add Protobuf + Schema Registry** if event schema management becomes painful
- WebSocket support for live notifications (currently polling only)
- Comment editing and edit history
- Advanced feed ranking (precomputed materialized views, trending algorithm)
- Richer moderation tools (shadow bans, content filters, automated spam detection)

---

_End of Document_
