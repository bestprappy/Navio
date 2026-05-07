**Project:** TripPlanner + EV Charger Integration + Community Sharing + Trip Copying + (Bonus) AI Planning Assistance
**Deployment Model:** Single University VM (8 GB RAM)
**Status:** Approved for Implementation
**Date:** 2026-02-07
**Revised:** 2026-05-07 — Synced with OpenAPI v1.1 trip-planning fixes: trip dates, sections/lists, saved places, itinerary days/items, notes, reservations, attachments, budget, expenses, and tripmates; keeps finalized copy-trip model, Google Maps-first provider strategy, hybrid Thailand EV charger data, geo-tile caching, and charger community reviews; consolidated for 8 GB single-VM deployment (~10 users)

---

## 0) Executive Summary

This system is a **microservices + event-driven** trip planning platform with built-in **EV charging intelligence**, a **Reddit-like community layer** for posting and discussing travel plans, and a simple **copy-trip model** where users can copy a posted/public trip into their own private trip library. The v1.1 API also formalizes the detailed trip-planning workspace needed by the UI: trip date ranges, custom sections/lists, saved places, itinerary days/items, notes, reservations, attachments, budgets, expenses, and tripmates. For maps and location features, the v1.0 provider is **Google Maps Platform** with `@vis.gl/react-google-maps` on the Next.js frontend. Mapbox is kept as an optional future provider through a provider-adapter abstraction.

The EV charger layer is designed for the Thailand data problem: OpenChargeMap coverage can be weak locally, so the system does **not** depend on a single EV charger API. It uses a **hybrid charger data strategy**: Google Places API for discovery, a local Postgres/PostGIS charger database as the durable source for application reads, optional OpenChargeMap fallback, admin-imported Thai charger seed data, and user-submitted charger suggestions with admin verification. Google is **not queried on every map load**; the EV service reads from Postgres first and only calls external providers on cache miss, stale geo-tile refresh, manual refresh, or low-confidence coverage areas.

The system is consolidated into **4 domain-aligned Spring Boot services** behind an **NGINX reverse proxy**, running on a **single 8 GB university VM**. Async processing (notifications, EV refresh) uses a **Kafka single-broker** setup. All data is stored in a **single PostgreSQL instance** with schema-per-service isolation (7 schemas). Full-text search uses Postgres `tsvector` + `pg_trgm` (no Elasticsearch). Caching is handled by **Caffeine** in-process caches (no Redis). Centralized non-secret configuration is managed by **Spring Cloud Config Server**. A bonus AI capability provides planning assistance via a dedicated AI Orchestrator that calls domain service APIs (never cross-service database reads).

---

## 0.1) Finalized Revision: Community Post → Copy Trip Model

The final v1.0 design uses a simple copy-trip model instead of a lineage-based remix model. A user can publish or share a trip to the community. Other users can view the post and choose **Copy to My Trips**. The system creates a new private trip owned by the copying user using a snapshot of the source trip's stops, dates, notes, route details, and EV profile.

**Copy behavior:**

- The copied trip becomes fully editable by the new owner.
- The copied trip does not stay synchronized with the source trip.
- Source trip edits do not update existing copies.
- Source trip deletion does not delete existing copies.
- The system may store source metadata for attribution/analytics, but no lineage graph, derived-trip queries, or cascade behavior is required.

**Feasibility verdict:** **Feasible and recommended for v1.0.** This model is simpler than a lineage/remix model, reduces database complexity, reduces API surface area, and fits the single-VM university deployment.

| Area | Feasibility Check | Result |
| ---- | ----------------- | ------ |
| Product UX | Users understand “Copy to My Trips” more easily than advanced remix lineage. | Good for v1 |
| Backend complexity | Requires one copy endpoint and one transactional insert of a new trip snapshot. | Low complexity |
| Database design | Only needs optional source metadata columns, not a graph table. | Simpler |
| Authorization | Copy allowed only when the source trip is public, unlisted with valid share token, or visible through a community post. | Clear |
| Scalability | Copy operation is lightweight for ~10 users and <5 RPS. | Feasible |
| Risk | Main risk is copying stale/invalid EV route data; fix by allowing recompute after copy. | Manageable |


---

## 0.2) Finalized Map and Location Provider Decision

### Final v1.0 choice

Use **Google Maps Platform** for v1.0.

Recommended stack:

```txt
Maps & Location Provider:
- Google Maps Platform
  - Maps JavaScript API for interactive trip maps
  - Places API for destination search, autocomplete, POI lookup, and EV charger discovery
  - Routes API for route calculation, ETA, waypoint routing, and route polyline rendering

Frontend React Library:
- @vis.gl/react-google-maps

Backend:
- Spring Boot EV/Geo provider adapters call Google APIs server-side when needed
```

### Why Google Maps first

Google Maps is the better default for this project because the product needs a practical trip-planning UX: destination search, familiar map behavior, place autocomplete, route display, and charger discovery. For a university MVP and Thailand-focused product, Google Maps is easier to explain, easier for users to understand, and strong for POI/place search.

### Mapbox position

Mapbox is still useful later if the project becomes more focused on advanced EV navigation, map styling, custom visualization, or deeper battery-aware routing. However, it is not the first choice for v1.0 because the MVP needs reliability and familiar trip-planning behavior more than advanced map customization.

### Provider abstraction rule

Do **not** hard-code the whole application to Google Maps. Create a provider abstraction:

```txt
MapProviderAdapter
├── GoogleMapsAdapter      // v1.0 implementation
└── MapboxAdapter          // optional v1.1+ implementation
```

Internal APIs should hide the external provider:

```txt
POST /v1/geo/geocode
POST /v1/geo/route
GET  /v1/ev/chargers/near
```

This allows the frontend and core domain logic to stay stable even if the provider changes later.

---

## 0.3) Finalized EV Charger Data Strategy for Thailand

### Problem

OpenChargeMap can have many markers in some foreign countries, but Thailand coverage may be weak or inconsistent. Therefore, the system must not rely on OpenChargeMap as the only EV charger data source.

### Final strategy

Use a **hybrid EV charger data layer**:

| Source | Role in v1.0 | Notes |
| ------ | ------------ | ----- |
| Google Places API | Primary external discovery provider | Used only when local cache is missing, stale, or low confidence |
| Local Postgres/PostGIS `ev.chargers` table | Main application read source | Frontend reads charger markers from backend, backend reads local DB first |
| Admin-imported charger seed data | Thailand coverage bootstrap | Good for capstone demo and controlled data quality |
| User-submitted chargers | Fill missing local data | Stored as pending until verified |
| OpenChargeMap | Optional fallback only | Useful where coverage exists, but not relied on |
| Future partner/operator APIs | Production upgrade path | Best for real-time availability, but difficult for v1.0 |

### Important cost rule

The EV Intelligence Service must **not query Google on every user request**. Google Maps Platform usage is billed by API usage / billable events / SKU requests, not by LLM-style tokens, so repeated direct calls can become expensive.

Correct flow:

```txt
User opens EV charger map
        ↓
Frontend calls backend only
        ↓
EV Intelligence Service checks local Postgres/PostGIS first
        ↓
If local tile has enough fresh chargers → return local data
        ↓
If tile is missing/stale/low confidence → refresh from Google once
        ↓
Normalize provider result
        ↓
Save/update `ev.chargers` and `ev.charger_tiles`
        ↓
Return charger markers to frontend
```

### Geo-tile refresh strategy

Do not cache by exact latitude/longitude because every user has slightly different coordinates. Cache and refresh by geo-tile.

Example:

```txt
Bangkok center    → tile_13_6502_3811
Chiang Mai area   → tile_13_6421_3540
Phuket area       → tile_13_6104_4028
```

Recommended tile table:

```sql
ev.charger_tiles
- tile_key
- provider
- last_refreshed_at
- expires_at
- charger_count
- confidence_score
- refresh_status
- last_error
```

Refresh rules:

```txt
If tile is fresh       → local DB only
If tile is stale       → refresh from provider once
If tile has no results → try Google, then optional fallback source
If provider fails      → serve stale local data marked as stale
```

### Lazy detail loading rule

Do not call detailed provider APIs for every marker. Load detailed information only when the user selects a specific charger.

Bad:

```txt
Map loads 50 chargers → call provider details API 50 times
```

Good:

```txt
Map loads 50 cached markers → no provider details calls
User clicks 1 charger → optionally fetch/update details for that charger only
```

### Safe long-term data rule

Use Google primarily for discovery/freshness and store provider-derived data with `source`, `place_id`, `last_seen_at`, and `expires_at`. For long-term curated Thai coverage, prefer:

```txt
- Admin-created records
- User-submitted records
- Partner/operator-provided records
- Public datasets that allow reuse
```

Avoid illegal scraping or relying on sources whose terms do not allow reuse.

---

## 0.4) Finalized Charger Reviews, Ratings, and Discussions

The system should include **user reviews, ratings, and discussion per EV charger**. This is important because Thailand EV charger data may be incomplete, stale, or fragmented across many operators.

### Two social layers

The final design has two related but separate social layers:

```txt
1. Community Trip Posts
   - Users post trips
   - Other users comment, vote, bookmark, and copy trips

2. Charger Community Layer
   - Users review, rate, discuss, report, and suggest edits for each charger
```

### Charger page features

Each charger detail page should support:

```txt
- Rating average and review count
- User reviews
- Charger-specific discussion/comments
- User-submitted photos
- Availability feedback
- Report incorrect information
- Suggest charger edits
- Submit missing charger
- Admin verification status
- Confidence score
```

### v1.0 feature priority

Must-have:

```txt
- Star rating
- Review text
- One review per user per charger
- Report wrong information
- Suggest missing charger
- Admin approve/reject workflow
```

Nice-to-have:

```txt
- Nested charger comments
- Review photos
- Verified visit badge
- Advanced trust/confidence scoring
```

### Feasibility verdict

This is feasible for v1.0 if implemented simply. It makes the project stronger because user feedback helps solve the Thailand charger-data coverage problem.

## 1) Goals, Scope, Assumptions

### 1.1 Goals

- Fast, reliable trip planning UX with map routing + EV charging stops.
- Social layer for publishing, commenting, voting, bookmarking.
- Community sharing where users can post trips and other users can copy them as independent trips.
- Lean operational footprint on a single university VM (8 GB RAM, ~10 users).

### 1.2 In Scope

- Trip CRUD + revisions + publish/unpublish + share links + copy public/community trips
- Detailed trip-planning modules: trip dates, sections/lists, saved places, itinerary day items, notes, reservations, attachments, budget, expenses, and tripmates
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
- **Trips:** Postgres core trip row + normalized child tables for UI modules; JSONB remains for flexible route snapshots, EV profile, provider metadata, and extensible metadata (no MongoDB)
- **Gateway:** NGINX reverse proxy with static routing to `localhost` ports (no Spring Cloud Gateway)
- **Service Discovery:** Static routing via NGINX config (no Eureka)
- **Configuration:** Spring Cloud Config Server (Git-backed, single node) for centralized non-secret config (feature flags, timeouts, Kafka topic names, external API URLs)
- **Secrets:** Environment variables or encrypted local files (no Vault — acceptable for university project)
- **Observability:** Spring Boot Actuator + structured JSON log files (lightweight; no dedicated OTel/Prometheus/Grafana stack unless RAM permits)
- **Scale:** ~10 concurrent users, < 5 RPS total
- External Providers:
  - Maps/Routing/Geocoding: **Google Maps Platform for v1.0**; Mapbox kept as optional future provider through adapter abstraction
  - Frontend maps library: `@vis.gl/react-google-maps`
  - EV Charger data: Google Places API as primary discovery provider, local Postgres/PostGIS charger database as main read source, OpenChargeMap optional fallback, admin/user-submitted Thai charger data, future partner/operator APIs
  - Messaging: SendGrid/Twilio/FCM/APNs (as needed)
  - LLM: Gemini (via AI SDK in UI, orchestrated on server)

---

## 2) Requirements

### 2.1 Functional Requirements

**Trips**

- Create/edit/delete trips with title, description, start/end dates, default currency, optional budget amount, route data, and EV profile
- Manage trip date range through `PATCH /v1/trips/{tripId}/dates`; dates generate the itinerary day range
- Manage custom sections/lists such as Places to Visit, Restaurants, Lodging, Activities, and user-created sections
- Add, update, remove, and reorder saved places inside sections; places may come from Google Places or manual entry
- Manage notes attached to the whole trip, a place, a day, or a reservation
- Manage itinerary days and scheduled items referencing places, reservations, notes, transport, or custom items
- Manage reservations for flights, lodging, rental cars, restaurants, activities, and other bookings
- Attach uploaded media/files to the trip, places, notes, reservations, or expenses through media links
- Manage budget, expenses, expense splits, budget summary, and group balances
- Manage tripmates/members for collaboration and expense splitting; member changes sync with ACL permissions
- Revision history and rollback to a specific revision
- Publish/unpublish and visibility transitions (private/unlisted/public)
- Share links (create/revoke, expiry optional)
- Copy public/community-shared trips into the current user's private trip library
- Copied trips are independent snapshots owned by the copying user; later edits/deletions of the source trip do not affect copied trips
- Store lightweight copy metadata for attribution/analytics only: source trip ID, source post ID, source title, source author display name, copied timestamp

**EV Integration**

- Vehicle profiles (connector, battery, consumption model)
- Charger lookup near stop with filters (connector, power, network)
- EV route feasibility and charge-stop recommendations
- Google Maps Platform for maps/routing/place discovery in v1.0
- Provider-agnostic adapter design so Mapbox or partner APIs can be added later
- Hybrid charger data strategy for Thailand: Google Places API + local curated Postgres/PostGIS charger database + OpenChargeMap fallback + admin-imported seed data + user-submitted charger suggestions
- Cached charger data in Postgres with geo-tile refresh control, scheduled refresh, Caffeine overlay cache, and graceful degradation
- Do not query Google for every request; call external providers only on cache miss, stale tile, manual refresh, or low-confidence coverage area
- Lazy-load charger details only when a user selects a specific charger

**EV Charger Community**

- View charger details, rating average, review count, confidence score, and verification status
- Add/edit/delete the current user's own charger review
- One review per user per charger using `UNIQUE(user_id, charger_id)`
- Charger-specific comments/discussion
- Report wrong charger information
- Suggest charger edits
- Submit missing chargers
- Admin approve/reject workflow for submitted chargers and suggested edits
- Optional photos through the existing Media service
- User feedback updates charger confidence score and verification metadata

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
- Notifications from: comments, replies, optional trip-copy events, moderation actions, etc.

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
- `@vis.gl/react-google-maps` for interactive maps, markers, and route visualization

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

- **Trip domain:** Trip CRUD + trip dates, sections/lists, saved places, itinerary days/items, notes, reservations, attachments, budget/expenses, tripmates, revisions, and rollback. The core trip is stored as a Postgres row; UI modules are normalized child tables; route snapshots and EV profile remain JSONB. Full-text search uses `tsvector` generated columns.
- **Visibility transitions:** private/unlisted/public
- **Share link** create/revoke
- **Trip copying**: users can copy public/community-shared trips into their own account. Copying creates a new independent trip row owned by the copier, with optional source metadata for attribution/analytics only.
- **Routing/ETA** integration with Maps provider
- **IAM domain:** App user profile mirror + preferences, roles (user/mod/admin), ban/unban users, ACL engine (generic resource ACL storage and evaluation)
- **Media domain:** Issues pre-signed upload URLs, stores metadata in `media` schema, returns safe rendering URLs
- **Embedded Media Worker** (`@Scheduled`): polls for uploaded files, runs virus scan + mime/size validation, generates thumbnails, updates metadata status (ready/blocked)
- **Embedded Outbox Publisher** (`@Scheduled`): polls `trip.outbox` and `iam.outbox` tables, publishes events to Kafka, marks rows as published
- Enforces trip access authorization (ACL checks in-process via IAM schema, same JVM)
- Fetches config from Config Server on startup

**Data Ownership**

- `trip` schema: trips, trip sections, trip places, itinerary items, notes, reservations, trip attachments, expenses, expense splits, trip members, revisions, share tokens, copy metadata, outbox
- `iam` schema: users, roles, bans, ACL entries, audit log, outbox
- `media` schema: media metadata

**Events Produced**

- `TripCreated.v1`, `TripUpdated.v1`, `TripDeleted.v1`
- `TripVisibilityChanged.v1`, `TripCopied.v1`
- `TripShareLinkCreated.v1`, `TripShareLinkRevoked.v1`
- `UserRegistered.v1`, `UserProfileUpdated.v1`, `UserDeactivated.v1`
- `UserBanned.v1`, `UserUnbanned.v1`, `UserNotificationPrefsUpdated.v1`

**Event Publishing**

- **Transactional Outbox Pattern** (see §8) — domain events written to outbox tables within the same DB transaction as the domain write, then published by embedded poller

---

### 4.4 EV Intelligence Service (Postgres schema: `ev`)

**Responsibilities**

- Charger provider integrations through adapters:
  - `GooglePlacesChargerProvider` for v1.0 primary external discovery
  - `OpenChargeMapProvider` as optional fallback where coverage exists
  - `AdminImportProvider` for CSV/seed data
  - Future `PartnerOperatorProvider` for Thai charger network APIs if access is granted
- Geo/routing provider integrations through `MapProviderAdapter`:
  - `GoogleMapsAdapter` for v1.0
  - optional `MapboxAdapter` later
- Charger search near geo point + filters using PostGIS (`ST_DWithin`)
- EV leg feasibility + charge-stop recommendation
- Local charger database in Postgres `ev.chargers` as the main application read source
- Geo-tile refresh control in `ev.charger_tiles` to avoid repeated external API calls for the same area
- Caffeine in-process cache overlay for hot charger reads (30–60s TTL)
- **Embedded EV Refresh Worker** (`@Scheduled`): periodic charger data pulls per geo-tile and provider, updates `ev.chargers` and `ev.charger_tiles`, publishes `ChargerCacheRefreshed.v1` to Kafka
- Charger detail lazy loading: provider detail calls happen only when a user opens a charger detail page or when a stale charger requires refresh
- User-submitted missing chargers with `PENDING_VERIFICATION` status
- Charger reviews, ratings, comments/discussions, reports, and suggested edits
- Admin verification workflow for submitted chargers, suggested edits, and reports
- Confidence score updates based on source reliability, verification status, user reviews, successful charging feedback, reports, and freshness
- Fetches config from Config Server on startup (refresh intervals, provider URLs, tile settings, API quotas, external rate limits)

**Data Ownership**

- `ev` schema: chargers, charger tiles, provider metadata, charger reviews, charger comments, charger reports, charger suggestions, charger review media links, outbox

**Events Produced**

- `ChargerCacheRefreshed.v1`
- `ChargerStatusUpdated.v1` (if provider supports)
- `ChargerSubmitted.v1`
- `ChargerVerified.v1`
- `ChargerReviewCreated.v1`
- `ChargerReported.v1`
- `ChargerSuggestionSubmitted.v1`

**Degradation**

- Provider down → serve stale Postgres data + mark `stale`
- Google quota exhausted → local DB only; admin/user-created charger records still work
- Poor provider coverage in Thailand → rely on admin-imported seed data and user submissions

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
- `POST /v1/trips/{tripId}/copy` — copy a public/community-shared trip into the current user's private trip library; optional body: `{ "sourcePostId": "...", "newTitle": "..." }`
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

**Detailed Trip Planning Modules**

- `PATCH /v1/trips/{tripId}/dates` — set or update trip start/end dates and enable itinerary day generation
- `GET /v1/trips/{tripId}/sections` — list trip sections/lists such as Places to Visit, Restaurants, Lodging, Activities, and custom lists
- `POST /v1/trips/{tripId}/sections` — create a custom section/list
- `PATCH /v1/trips/{tripId}/sections/{sectionId}` — rename, collapse, or reorder a section
- `DELETE /v1/trips/{tripId}/sections/{sectionId}` — delete a section subject to business rules
- `PATCH /v1/trips/{tripId}/sections/reorder` — reorder all trip sections
- `GET /v1/trips/{tripId}/sections/{sectionId}/places` — list saved places in one section
- `POST /v1/trips/{tripId}/sections/{sectionId}/places` — add a Google or manual place to a section
- `PATCH /v1/trips/{tripId}/places/{placeId}` — update place details, notes, scheduled date/time, or section assignment
- `DELETE /v1/trips/{tripId}/places/{placeId}` — remove a saved place and clean up or detach dependent itinerary references
- `PATCH /v1/trips/{tripId}/sections/{sectionId}/places/reorder` — reorder places inside a section
- `GET /v1/trips/{tripId}/notes` — list trip/place/day/reservation notes
- `POST /v1/trips/{tripId}/notes` — create a note attached to a trip target
- `PATCH /v1/trips/{tripId}/notes/{noteId}` — update note content or target
- `DELETE /v1/trips/{tripId}/notes/{noteId}` — delete a note
- `GET /v1/trips/{tripId}/itinerary` — return itinerary days generated from trip dates plus scheduled items
- `POST /v1/trips/{tripId}/itinerary/items` — add a place, reservation, note, transport item, or custom item to one trip day
- `PATCH /v1/trips/{tripId}/itinerary/items/{itemId}` — update itinerary item date/time/title/notes/reference
- `DELETE /v1/trips/{tripId}/itinerary/items/{itemId}` — remove an itinerary item
- `PATCH /v1/trips/{tripId}/itinerary/days/{date}/reorder` — reorder items within one itinerary day
- `GET /v1/trips/{tripId}/reservations` — list reservations and related attachments
- `POST /v1/trips/{tripId}/reservations` — create a reservation or booking record
- `GET /v1/trips/{tripId}/reservations/{reservationId}` — get one reservation
- `PATCH /v1/trips/{tripId}/reservations/{reservationId}` — update reservation details
- `DELETE /v1/trips/{tripId}/reservations/{reservationId}` — delete a reservation and handle attachment policy
- `GET /v1/trips/{tripId}/attachments` — list uploaded media linked to trip targets
- `POST /v1/trips/{tripId}/attachments` — link an existing uploaded media object to a trip target
- `DELETE /v1/trips/{tripId}/attachments/{attachmentId}` — remove the attachment link without necessarily deleting the media asset
- `GET /v1/trips/{tripId}/budget` — get trip budget amount and currency
- `PATCH /v1/trips/{tripId}/budget` — update trip budget amount and default currency
- `GET /v1/trips/{tripId}/budget/summary` — total spent, remaining budget, and category breakdown
- `GET /v1/trips/{tripId}/budget/balances` — calculate who owes whom based on expense splits
- `GET /v1/trips/{tripId}/expenses` — list expenses with optional filters
- `POST /v1/trips/{tripId}/expenses` — create an expense and optional split records
- `GET /v1/trips/{tripId}/expenses/{expenseId}` — get one expense and splits
- `PATCH /v1/trips/{tripId}/expenses/{expenseId}` — update expense details and recalculate split records when provided
- `DELETE /v1/trips/{tripId}/expenses/{expenseId}` — delete an expense and split records
- `GET /v1/trips/{tripId}/members` — list tripmates used for collaboration and expense splitting
- `POST /v1/trips/{tripId}/members/invite` — invite a tripmate and create/sync ACL permissions
- `DELETE /v1/trips/{tripId}/members/{userId}` — remove a tripmate and sync ACL permissions

**Trip Copy Endpoint Behavior**

`POST /v1/trips/{tripId}/copy` performs these steps:

1. Validate the authenticated user.
2. Check that the source trip is copyable: public, visible through a valid community post, or visible through a valid share token.
3. Read the source trip snapshot.
4. Create a new trip row with a new `tripId`, `ownerUserId = currentUser`, and `visibility = private`.
5. Copy the safe trip-planning snapshot into the new trip: trip dates, sections, saved places, itinerary items, public notes, route summary, and EV profile. Reservation confirmation numbers, private attachments, tripmates, and expense obligations should not be blindly copied unless the product explicitly marks them as shareable.
6. Store lightweight source metadata for attribution/analytics.
7. Insert a first revision named `CopiedFromSource`.
8. Write `TripCopied.v1` to `trip.outbox`.
9. Return the new private trip.

**EV Intelligence**

- `POST /v1/ev/route/compute` — compute EV-aware route feasibility + charge stops
- `GET /v1/ev/chargers/near?lat=...&lng=...&radiusKm=...&connector=...&minKw=...` — charger search; reads local Postgres first, external provider only on cache miss/stale tile/low confidence
- `GET /v1/ev/chargers/{chargerId}` — charger detail page data
- `POST /v1/ev/chargers/suggest` — suggest a missing charger; creates `PENDING_VERIFICATION` charger record
- `GET /v1/ev/chargers/{chargerId}/reviews` — list charger reviews
- `POST /v1/ev/chargers/{chargerId}/reviews` — create or replace current user's review; one review per user per charger
- `PATCH /v1/ev/chargers/{chargerId}/reviews/{reviewId}` — edit own review
- `DELETE /v1/ev/chargers/{chargerId}/reviews/{reviewId}` — delete own review or moderator delete
- `GET /v1/ev/chargers/{chargerId}/comments?parentId=...` — list charger comments/discussion
- `POST /v1/ev/chargers/{chargerId}/comments` — create charger comment; optional `parentCommentId` for replies
- `DELETE /v1/ev/chargers/{chargerId}/comments/{commentId}` — delete own comment or moderator delete
- `POST /v1/ev/chargers/{chargerId}/report` — report incorrect charger information
- `POST /v1/ev/chargers/{chargerId}/suggest-edit` — suggest edits to name, address, connectors, power, opening hours, location, etc.
- `GET /v1/admin/ev/charger-reports` — admin/mod list of charger reports
- `POST /v1/admin/ev/chargers/{chargerId}/approve` — approve submitted charger
- `POST /v1/admin/ev/chargers/{chargerId}/reject` — reject submitted charger
- `POST /v1/admin/ev/charger-suggestions/{suggestionId}/approve` — approve suggested edit
- `POST /v1/admin/ev/charger-suggestions/{suggestionId}/reject` — reject suggested edit
- `POST /v1/admin/ev/tiles/{tileKey}/refresh` — manually refresh charger data for one geo-tile

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
| `trip`         | Trip & Media Service    | Trips, trip sections/lists, saved places, itinerary items, notes, reservations, trip attachments, budget/expenses, tripmates, revisions, share tokens, copy metadata, outbox |
| `iam`          | Trip & Media Service    | Users, roles, bans, ACL entries, audit log, outbox           |
| `media`        | Trip & Media Service    | Media metadata, upload tracking                              |
| `ev`           | EV Intelligence Service | Chargers, charger tiles, reviews, comments, reports, suggestions, provider metadata, outbox |
| `social`       | Community Service       | Posts, comments, votes, bookmarks, reports, outbox           |
| `notif`        | Community Service       | Notification preferences, in-app notifications, delivery log |
| `ai`           | AI Orchestrator         | Prompt configs, sessions, usage logs, quota counters         |
| Object Storage | Trip & Media Service    | MinIO or local filesystem                                    |

### 6.2 Trip Copy Data Model

The copy model should be implemented inside the `trip.trips` table or a small companion table. The simplest v1.0 approach is to store source metadata directly on the copied trip row.

Recommended fields on `trip.trips`:

| Field | Purpose |
| ----- | ------- |
| `id` | New trip ID generated for the copied trip |
| `owner_user_id` | User who copied the trip and now owns it |
| `title` | Copied title, optionally prefixed with “Copy of …” or user-provided |
| `visibility` | Always starts as `private` after copy |
| `stops_jsonb` | Snapshot of source stops |
| `route_legs_jsonb` | Snapshot of source route legs; can be recomputed later |
| `ev_profile_jsonb` | Snapshot of EV assumptions used by the source trip |
| `copied_from_trip_id` | Optional source trip reference for attribution/analytics only |
| `copied_from_post_id` | Optional source community post reference |
| `copied_from_title` | Source title snapshot |
| `copied_from_author_display_name` | Source author snapshot |
| `copied_at` | Copy timestamp |

Rules:

- No foreign key is required from copied trips to the source trip. This prevents source deletion from breaking copied trips.
- The copied trip starts as `private` to prevent accidental reposting. The user can later publish it manually.
- Revisions start fresh for the copied trip. The first revision should be `CopiedFromSource`.
- Media should not be blindly duplicated. For v1.0, copied trips may reference already-safe public media URLs or omit private media.
- EV route data may be copied as a snapshot, but the UI should show a **Recompute EV Route** action because charger availability may change.

### 6.3 Detailed Trip Planning Data Model

OpenAPI v1.1 introduces UI-level trip modules that should be modeled as first-class child tables instead of hiding everything inside one large JSONB document.

Recommended `trip` child tables:

| Table | Purpose |
| ----- | ------- |
| `trip.trip_sections` | Custom user lists/sections such as Places to Visit, Restaurants, Lodging, Activities, and custom sections |
| `trip.trip_places` | Saved Google/manual places inside sections, with schedule date/time, notes, and display order |
| `trip.trip_notes` | Notes attached to `TRIP`, `PLACE`, `DAY`, or `RESERVATION` targets |
| `trip.itinerary_items` | Day-based itinerary items referencing places, reservations, notes, transport, or custom items |
| `trip.reservations` | Bookings for flights, lodging, rental cars, restaurants, activities, and other reservations |
| `trip.trip_attachments` | Links from uploaded media to trip targets such as reservations, expenses, notes, places, or the trip itself |
| `trip.expenses` | Trip expenses with category, amount, currency, payer, date, optional place/reservation references |
| `trip.expense_splits` | Per-user split records used to calculate group balances |
| `trip.trip_members` | Tripmates for collaboration and expense splitting; must sync to `iam.acl_entries` |

Rules:

- `trip.trips` remains the aggregate root and stores title, description, visibility, dates, currency, budget amount, route snapshots, EV profile, and copy metadata.
- Child tables should use `trip_id` foreign keys to `trip.trips` because they are owned by the same service and schema.
- Cross-service references such as `user_id`, `media_id`, and `source_post_id` remain plain IDs without foreign keys to other schemas.
- Reordering is stored with `sort_order` columns and updated transactionally.
- `GET /v1/trips/{tripId}/itinerary` should generate the day range from `start_date` and `end_date`, then attach matching `trip.itinerary_items` rows.
- Budget amount and default currency live on `trip.trips`; actual spending lives in `trip.expenses` and `trip.expense_splits`.
- Tripmate invitation should create/update `trip.trip_members` and sync the corresponding ACL entry.
- Deleting a place or reservation should clean up, detach, or soft-delete dependent notes, attachments, itinerary items, and expenses according to service rules.

### 6.4 EV Charger Data Model

The EV charger data model must support provider data, local curated data, user submissions, reviews, reports, and verification.

Recommended `ev.chargers` fields:

```sql
ev.chargers
- id
- name
- operator_name
- lat
- lng
- location geography(Point, 4326)
- address
- province
- connector_types jsonb
- max_kw
- total_connectors
- available_connectors
- price_text
- opening_hours jsonb
- source
- source_external_id
- google_place_id
- source_url
- confidence_score
- verification_status
- status
- rating_avg
- rating_count
- report_count
- last_seen_at
- last_provider_refreshed_at
- last_user_verified_at
- expires_at
- created_by_user_id
- created_at
- updated_at
```

Recommended `source` values:

```txt
GOOGLE_PLACES
OPENCHARGEMAP
ADMIN_IMPORT
USER_SUBMITTED
PARTNER_API
```

Recommended `verification_status` values:

```txt
UNVERIFIED
PENDING_VERIFICATION
GOOGLE_CACHED
USER_VERIFIED
ADMIN_VERIFIED
REJECTED
STALE
```

Recommended `ev.charger_tiles` fields:

```sql
ev.charger_tiles
- tile_key
- provider
- last_refreshed_at
- expires_at
- charger_count
- confidence_score
- refresh_status
- last_error
- created_at
- updated_at
```

Recommended `ev.charger_reviews` fields:

```sql
ev.charger_reviews
- id
- charger_id
- user_id
- rating
- review_text
- visit_date
- charging_successful
- wait_time_minutes
- connector_used
- created_at
- updated_at
- deleted_at

UNIQUE(user_id, charger_id)
```

Recommended `ev.charger_comments` fields:

```sql
ev.charger_comments
- id
- charger_id
- user_id
- parent_comment_id
- comment_text
- created_at
- updated_at
- deleted_at
```

Recommended `ev.charger_reports` fields:

```sql
ev.charger_reports
- id
- charger_id
- user_id
- report_type
- description
- status
- reviewed_by_admin_id
- created_at
- reviewed_at
```

Recommended `ev.charger_suggestions` fields:

```sql
ev.charger_suggestions
- id
- charger_id
- user_id
- suggested_name
- suggested_address
- suggested_connector_types jsonb
- suggested_max_kw
- suggested_opening_hours jsonb
- suggested_lat
- suggested_lng
- status
- reviewed_by_admin_id
- created_at
- reviewed_at
```

Recommended media link table:

```sql
ev.charger_review_media
- review_id
- media_id
```

### 6.4 EV Charger Query and Refresh Flow

All charger reads should go through the EV Intelligence Service.

```txt
GET /v1/ev/chargers/near
        ↓
Check Caffeine hot cache
        ↓
Check `ev.chargers` with PostGIS
        ↓
Check `ev.charger_tiles` freshness
        ↓
If enough fresh data exists → return local results
        ↓
If missing/stale/low confidence → refresh tile from provider
        ↓
Normalize + upsert provider results
        ↓
Return merged local results
```

Provider calls are allowed only when at least one condition is true:

```txt
- No chargers found in the requested tile/radius
- Tile is stale based on `expires_at`
- Coverage confidence is below threshold
- User explicitly requests refresh
- Admin manually refreshes tile
- Scheduled worker refreshes known important tiles
```

Provider detail calls should be lazy-loaded:

```txt
Map marker list → local cached summary only
Charger detail click → fetch richer provider details only if stale/missing
```

### 6.5 Backup/Restore

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

### 9.3 EV Cache and External API Cost Control

- Postgres `ev.chargers` table with `expires_at` column acts as durable charger database/cache
- Postgres `ev.charger_tiles` controls geo-tile freshness and prevents repeated provider calls for the same area
- Caffeine overlay for hot-path reads (30–60s TTL)
- Embedded EV Refresh Worker updates Postgres tables on schedule
- Google Places API is called only on cache miss, stale tile, explicit user refresh, admin refresh, or low-confidence coverage area
- Do not call provider details APIs for every map marker; lazy-load details only when the user opens one charger
- Daily/monthly provider request limits should be configured in Spring Cloud Config Server
- Mark stale on provider failure; serve stale local data rather than error where safe
- Admin/user-created charger records remain usable even when external providers are unavailable or quota-limited

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
| Google Maps quota/cost limit reached | Local charger DB, admin-imported chargers, and user-submitted chargers continue working; external refresh pauses |
| Poor Thailand provider coverage | Use admin-imported seed data, user submissions, verification, and optional fallback providers |
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
9. **Do not query Google Maps/Places on every EV map request** — local Postgres/PostGIS is the main read source; external providers are refresh sources.
10. **Keep map/provider APIs behind adapters** so Google Maps can be replaced or supplemented by Mapbox/operator APIs later.
11. **Charger reviews and reports belong to the EV domain** because they directly affect charger quality, verification, and confidence score.
12. **Avoid illegal scraping**; use APIs, admin-created data, user submissions, partner data, or public datasets with allowed reuse.

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
| D9  | Simple copy-trip model instead of lineage-based remixing | Copying creates a new independent private trip owned by the copier. Source metadata is retained only for attribution/analytics. Source deletion does not cascade to copied trips. |
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
| D20 | Google Maps Platform selected for v1.0                 | Best fit for familiar trip-planning UX, place search, routing, and MVP speed. Mapbox remains optional through provider adapters.                                                                  |
| D21 | Provider adapter abstraction for maps/EV data           | Prevents vendor lock-in and allows Mapbox, OpenChargeMap, admin imports, or partner APIs to be added later.                                                                                       |
| D22 | Hybrid EV charger data strategy for Thailand            | OpenChargeMap coverage can be weak locally; local curated data, Google discovery, admin imports, and user submissions make the system feasible.                                                    |
| D23 | Local Postgres/PostGIS first for charger reads           | Reduces external API cost and latency; Google is used as a refresh/discovery provider, not queried for every user request.                                                                         |
| D24 | Geo-tile based EV refresh control                        | Avoids repeated provider calls for the same area and keeps refresh behavior predictable.                                                                                                           |
| D25 | Charger reviews/comments kept in EV Service             | Charger feedback affects EV charger reliability, confidence score, and verification, so it belongs in the EV domain rather than general community posts.                                           |

---

## 17) Feasibility Verification and Final Recommendation

### 17.1 Final Feasibility Verdict

This final design is feasible for a university capstone project on a single 8 GB VM. The copy-trip model is more feasible than a lineage-based remix model because it avoids graph traversal, source tombstones, derived-trip synchronization questions, and complicated attribution rules.

### 17.2 Why the Copy Model Is Better for v1.0

| Category | Lineage-Based Remix Model | Final Copy-Trip Model |
| -------- | ------------------------- | --------------------- |
| User mental model | More complex | Simple: “Copy to My Trips” |
| API surface | Multiple origin/lineage endpoints | One copy endpoint |
| Database | Needs graph/lineage state | Optional source metadata only |
| Delete behavior | Needs tombstone rules | Existing copies remain independent |
| Authorization | More edge cases | Source must be copyable at copy time |
| Implementation risk | Medium | Low |
| Capstone suitability | Impressive but heavy | Practical and still useful |

### 17.3 Required Implementation Guardrails

- Do not let Community Service directly write to `trip` schema. Trip & Media Service owns copy logic.
- Always create copied trips as `private`.
- Do not auto-sync copied trips with the source trip.
- Do not cascade delete copied trips when source trips/posts are deleted.
- Store source metadata only for display/analytics, not dependency.
- Recompute EV route data after copy when the user opens the copied trip or clicks recompute.
- Keep `TripCopied.v1` optional for notifications/analytics; core copy functionality should work even if Kafka is temporarily down because outbox will catch up.

### 17.4 Map Provider Feasibility

Google Maps Platform is feasible for v1.0 as long as the project uses backend-controlled access, budget limits, and caching. The frontend should not freely trigger expensive provider calls. All route, place, and charger refresh behavior should be rate-limited and controlled by the backend.

Mapbox remains a valid future option, but not necessary for the first version.

### 17.5 EV Charger Data Feasibility for Thailand

The EV charger feature remains feasible even if no complete Thai EV charger API exists.

The key is to avoid depending on one provider:

```txt
Google Places API       → external discovery provider
Postgres/PostGIS        → main charger read database
Admin imports           → demo-ready Thai charger seed data
User submissions        → fills local coverage gaps
OpenChargeMap           → optional fallback only
Partner APIs            → future production upgrade
```

This design is stronger than relying on OpenChargeMap alone because it explains the real local-data challenge and solves it with a provider-agnostic, community-assisted data layer.

### 17.6 External API Cost Feasibility

The project should not query Google on every charger map request. Cost is controlled by:

```txt
- Local DB first
- Caffeine hot cache
- Geo-tile refresh status
- Provider call only on cache miss/stale/low confidence
- Lazy details loading
- Daily/monthly request limits
- Admin refresh controls
```

For ~10 users and <5 RPS, this is feasible.

### 17.7 Charger Review and Rating Feasibility

Charger reviews, ratings, reports, and suggested edits are feasible for v1.0 if implemented simply:

```txt
Must-have:
- One review per user per charger
- Star rating and review text
- Report wrong info
- Submit missing charger
- Admin approve/reject

Nice-to-have:
- Nested comments
- Review photos
- Verified visit badge
- Advanced trust scoring
```

This improves the product because user feedback helps solve missing or stale Thai charger information.

### 17.8 Final Recommendation

Proceed with this design as the final v1.0 architecture. It keeps the project impressive enough for a capstone because it includes trip planning, Google Maps integration, EV intelligence, Thailand-friendly charger data strategy, charger reviews/ratings/discussions, community trip sharing, copy-to-my-trips, search, notifications, media handling, Kafka/outbox, and optional AI planning assistance. At the same time, the copy-trip model and local-first charger cache remove unnecessary complexity and make the implementation more realistic for ~10 users on one 8 GB VM.

---

## 18) Open Items for v1.1+ (Scale-Up Path)

When user count exceeds ~50–100, consider the following scale-up steps:

- **Split services back out**: Extract IAM and Media from Trip Service when codebases grow large
- **Add Elasticsearch** when dataset exceeds ~100K documents or full-text search latency degrades
- **Add Redis** if Caffeine in-process caching becomes insufficient (multi-instance deployments need shared cache)
- **Add second VM + load balancer** for basic HA
- **Scale Kafka to 3 brokers** with RF=3 for durability
- **Add Eureka** if deploying to multiple VMs (service discovery becomes useful)
- **Migrate secrets to Vault** for production-grade secret management
- **Add Protobuf + Schema Registry** if event schema management becomes painful
- Add Mapbox adapter if advanced EV routing, visual customization, or battery-aware navigation becomes a core differentiator
- Add direct Thai charger operator/partner APIs if access is granted
- Add real-time charger availability where provider/operator APIs support it
- Add advanced charger trust score and verified-visit badges
- Advanced remix/lineage model if the product later needs full attribution chains
- WebSocket support for live notifications (currently polling only)
- Comment editing and edit history
- Advanced feed ranking (precomputed materialized views, trending algorithm)
- Richer moderation tools (shadow bans, content filters, automated spam detection)

---

_End of Document_
