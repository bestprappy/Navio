# Implementation Guide v1.0 — Consolidated

**Project:** TripPlanner Platform
**Based on:** System Design Doc v1.0 — Revised for 8 GB Single-VM Deployment
**Approach:** Phased, dependency-ordered, each phase produces a deployable increment

---

## Guiding Principles

1. **Infrastructure before application** — stateful systems must be stable before domain services deploy.
2. **Auth before everything** — no service is useful without identity and access control.
3. **Core domain first** — Trip Engine is the product's reason to exist; ship it early.
4. **Horizontal concerns wired early** — observability and the event bus go in Phase 0 so every subsequent service benefits.
5. **Each phase ends with a working vertical slice** — not a pile of unconnected pieces.
6. **Bonus features last** — AI is the final phase; never let it delay core delivery.

---

## Phase Overview

| Phase | Name                                           | Depends On       | Milestone                                                           |
| ----- | ---------------------------------------------- | ---------------- | ------------------------------------------------------------------- |
| 0     | Infrastructure & Platform                      | —                | VM, Postgres, Kafka, Config Server, NGINX, Keycloak operational     |
| 1     | Auth, NGINX Routing & IAM                      | Phase 0          | User signs up, authenticates, requests routed via NGINX             |
| 2     | Trip Engine (Core CRUD)                        | Phase 1          | User can create/edit/delete trips with Postgres+JSONB, revisions    |
| 3     | Trip Engine (Sharing, Forking & Outbox Events) | Phase 2          | Share links, forking, outbox → Kafka events flowing                 |
| 4     | EV Intelligence                                | Phase 1, Phase 3 | Charger search (PostGIS), EV route compute, embedded refresh worker |
| 5     | Community, Search & Notifications              | Phase 1, Phase 3 | Posts, comments, votes, Postgres FTS, in-app notifications          |
| 6     | Media Pipeline                                 | Phase 1          | Upload, scan, thumbnail, safe URLs (embedded in Trip & Media)       |
| 7     | AI Planning Assistance (Bonus)                 | Phase 2, Phase 4 | AI suggest, chat-with-plan, quota enforcement                       |

---

## Phase 0 — Infrastructure & Platform

**Goal:** The single 8 GB VM has all stateful systems deployed, healthy, and reachable. Service skeleton is ready for cloning.

### 0.1 VM Provisioning

- Provision a single 8 GB RAM VM (university-provided)
- Install OS packages: JDK 21, PostgreSQL 16 + PostGIS, Docker (for Kafka/Keycloak/MinIO)
- Configure firewall: SSH, HTTP/HTTPS (NGINX), Keycloak (8180), service ports (8081-8084), Config Server (8888)
- Set up systemd unit files or Docker Compose for all infrastructure components
- No network segmentation needed — single VM, all traffic is `localhost`

### 0.2 Stateful Systems

Deploy on the single VM:

- **PostgreSQL** (single instance, ~400 MB RAM):
  - Create 7 schemas: `trip`, `iam`, `media`, `ev`, `social`, `notif`, `ai`
  - Enable PostGIS extension (`CREATE EXTENSION postgis;`)
  - Enable `pg_trgm` extension for trigram search (`CREATE EXTENSION pg_trgm;`)
  - Configure: `shared_buffers=128MB`, `work_mem=4MB`, `max_connections=80`
  - Flyway baseline migrations (empty schemas with version tracking) will run per-service

- **Kafka** (single broker, `-Xmx256m`, ~400 MB RAM):
  - Single-broker deployment (ZooKeeper or KRaft mode, 1 broker)
  - Replication factor = 1 (single broker — no replication possible)
  - Default retention: 7 days
  - Create initial topics (`trip.events.v1`, `iam.events.v1`, `community.events.v1`, `ev.events.v1`, `notification.commands.v1`) with 1-3 partitions each
  - JSON serialization — no Schema Registry needed

- **Keycloak** (~512 MB RAM):
  - Deploy on embedded H2 or share the Postgres instance
  - Configure realm, OIDC client, JWT issuer, JWKS endpoint
  - Seed admin user

- **MinIO** (or local filesystem, ~200 MB RAM):
  - Single-node mode (no erasure coding — single disk)
  - Create `uploads` and `exports` buckets
  - Configure pre-signed URL support

### 0.3 Platform Services

- **Spring Cloud Config Server** (`-Xmx128m`, ~192 MB RAM):
  - Single node (no LB needed for ~10 users)
  - Git-backed config repo with profiles: `default`, `dev`, `prod`
  - Stores: feature flags, timeouts, Kafka topic names, external API URLs, refresh intervals
  - All 4 services configured as Config Server clients via `spring.config.import=configserver:http://localhost:8888`
  - Secrets **NOT** in Config Server — use environment variables (see 0.4)

- **No Eureka** — services bind to known `localhost` ports; NGINX routes statically
- **No Vault** — secrets stored in environment variables (`POSTGRES_PASSWORD`, `KEYCLOAK_ADMIN_SECRET`, API keys)

### 0.4 Secrets Management (Environment Variables)

```
POSTGRES_URL=jdbc:postgresql://localhost:5432/tripplanner
POSTGRES_USER=tripplanner
POSTGRES_PASSWORD=<generated>
KEYCLOAK_ISSUER_URI=http://localhost:8180/realms/tripplanner
KEYCLOAK_ADMIN_SECRET=<generated>
MINIO_ACCESS_KEY=<generated>
MINIO_SECRET_KEY=<generated>
EV_PROVIDER_API_KEY=<generated>
GEMINI_API_KEY=<generated>
```

Store in `/etc/tripplanner/env` (or systemd unit file `EnvironmentFile=`), not in Git.

### 0.5 Observability (Simplified)

- **Spring Boot Actuator** on each service (`/actuator/health`, `/actuator/metrics`, `/actuator/info`)
- **Structured JSON logging** (Logback JSON encoder) → write to files → rotate with logrotate
- **Correlation ID propagation**: services read/generate `X-Correlation-Id` header, include in all log entries
- **No OTel Collector, Prometheus, Grafana, Loki, Tempo** in v1 — 8 GB budget doesn't allow it
- Monitor via: `journalctl`, Actuator endpoints, Kafka console tools, `pg_stat_activity`
- Add OTel + Grafana stack when/if the project upgrades to a larger VM

### 0.6 CI/CD Pipeline (Simplified)

- Source control: Git (mono-repo recommended for 4 services)
- Build: `./mvnw clean package -DskipTests` (or Gradle equivalent) → produce fat JARs
- Deploy: SCP JAR to VM → restart systemd service → health check
- No Docker images needed — run as systemd services with JVM flags (`-Xmx256m`, etc.)
- Test: `./mvnw test` locally before push

### 0.7 Service Skeleton (Template)

Create a **Spring Boot 3 service template** with:

- Config Server client (`spring-cloud-starter-config`)
- Health endpoints (`/actuator/health/liveness`, `/actuator/health/readiness`)
- Structured JSON logging with correlation ID propagation
- Resilience4j dependency (pre-configured, not yet wired to external calls)
- Flyway dependency (auto-run migrations on startup)
- Kafka producer/consumer boilerplate with JSON serialization (Jackson `ObjectMapper`)
- Event envelope: `{ eventId, eventType, partitionKey, payload, traceContext, timestamp }`
- Caffeine cache dependency (in-process, LRU, configurable max size + TTL)
- Transactional Outbox table + `@Scheduled` outbox publisher component
- Standard error response format (`{ status, error, message, correlationId, timestamp }`)
- No Eureka client, no Vault integration, no Protobuf/Schema Registry

**This template is the single highest-leverage task in the entire project — do it well.**

**Exit Criteria:**

- [ ] PostgreSQL running with 7 schemas, PostGIS and pg_trgm enabled
- [ ] Kafka single broker running, initial topics created, test producer/consumer round-trips a JSON message
- [ ] Config Server running, serving config from Git repo
- [ ] Keycloak running, realm configured
- [ ] MinIO running, buckets created
- [ ] NGINX installed (static routing configured in Phase 1)
- [ ] Service template compiles, starts, connects to Config Server, runs Flyway, health endpoint responds

---

## Phase 1 — Auth, NGINX Routing & IAM

**Goal:** A user can sign up via Keycloak, obtain a JWT, and hit NGINX which routes authenticated requests to the correct service. IAM module stores user profiles and role data.

### 1.1 Keycloak Integration (Frontend)

- Configure Keycloak realm (OIDC, JWT issuer, JWKS endpoint)
- Integrate NextAuth/Keycloak-js into Next.js app (sign-up, sign-in, sign-out flows)
- JWT includes: `sub` (userId), `email`, `name`
- Verify JWT structure and claims

### 1.2 NGINX Reverse Proxy

- Configure NGINX as the single entry point (replaces Spring Cloud Gateway):

```nginx
upstream trip_media_service {
    server 127.0.0.1:8081;
}
upstream ev_service {
    server 127.0.0.1:8082;
}
upstream community_service {
    server 127.0.0.1:8083;
}
upstream ai_service {
    server 127.0.0.1:8084;
}

server {
    listen 80;
    # listen 443 ssl;  # enable with Let's Encrypt when domain is available

    # --- Trip & Media routes ---
    location /v1/trips     { proxy_pass http://trip_media_service; }
    location /v1/share     { proxy_pass http://trip_media_service; }
    location /v1/media     { proxy_pass http://trip_media_service; }
    location /v1/me        { proxy_pass http://trip_media_service; }
    location /v1/mod       { proxy_pass http://trip_media_service; }

    # --- EV Intelligence routes ---
    location /v1/ev        { proxy_pass http://ev_service; }

    # --- Community routes ---
    location /v1/posts     { proxy_pass http://community_service; }
    location /v1/feed      { proxy_pass http://community_service; }
    location /v1/search    { proxy_pass http://community_service; }
    location /v1/notifications { proxy_pass http://community_service; }

    # --- AI routes ---
    location /v1/ai        { proxy_pass http://ai_service; }

    # Proxy headers
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # Timeouts
    proxy_connect_timeout 5s;
    proxy_read_timeout    30s;

    # Correlation ID: pass through or generate
    map $http_x_correlation_id $corr_id {
        default $http_x_correlation_id;
        ""      $request_id;
    }
    proxy_set_header X-Correlation-Id $corr_id;
}
```

- No JWT validation in NGINX — JWT validation is done by each Spring Boot service using the Keycloak JWKS endpoint
- Public route allowlist: `GET /v1/share/{token}` (no JWT required) — handled in service logic

### 1.3 IAM Module (inside Trip & Media Service)

IAM is a module within the Trip & Media Service (port 8081), not a separate service.

- **Flyway migrations** — `iam` schema:
  - `iam.users`, `iam.bans`, `iam.acl_entries`, `iam.audit_log`, `iam.outbox` (per Database.md §2)
- **Internal endpoints** (called by other services via `localhost:8081`):
  - `POST /internal/v1/users/sync` — upsert user profile from Keycloak claims
  - `GET /internal/v1/users/{userId}` — get profile
  - `POST /internal/v1/acl/check` — body: `{ resourceType, resourceId, userId, requiredPermission }` → allow/deny
  - `POST /internal/v1/acl/grant` — grant permission
  - `DELETE /internal/v1/acl/revoke` — revoke permission
  - `GET /internal/v1/acl/list?resourceType=...&resourceId=...` — list permissions on resource
- **Public endpoints** (through NGINX):
  - `GET /v1/me` — current user profile
  - `PATCH /v1/me/preferences` — update preferences
  - `POST /v1/mod/users/{userId}/ban` — ban (mod/admin only)
  - `POST /v1/mod/users/{userId}/unban` — unban (mod/admin only)
- **Events** published via outbox → Kafka topic `iam.events.v1`:
  - `UserRegistered.v1`, `UserProfileUpdated.v1`, `UserBanned.v1`, `UserUnbanned.v1`
- **ACL checks are in-process** — since IAM is in the same JVM as Trip Engine, ACL checks are direct method calls (no HTTP call needed for trip operations)

### 1.4 Frontend Shell

- Next.js app deployed on same VM (or separate — student's choice)
- Keycloak sign-up/sign-in flow working
- Authenticated API calls to NGINX with JWT in `Authorization: Bearer` header
- Basic layout/navigation shell (trip list page, empty states)
- Zod validation on client-side forms
- Arcjet integration for app-level rate limiting

**Exit Criteria:**

- [ ] User signs up via Keycloak, JWT issued
- [ ] NGINX routes request to Trip & Media Service, returns user profile
- [ ] IAM module stores user, publishes `UserRegistered.v1` to Kafka via outbox
- [ ] Unauthorized requests rejected (401) by service
- [ ] Public route (`/v1/share/{token}`) passes through without JWT (404 is fine — sharing not implemented yet)
- [ ] Actuator health endpoint accessible

---

## Phase 2 — Trip Engine (Core CRUD)

**Goal:** User can create, read, update, delete trips with stops and notes. Revision history and rollback work. Maps integration provides route distance/time.

### 2.1 Trip Engine Module (inside Trip & Media Service)

Trip Engine is a module within the Trip & Media Service (port 8081), sharing the JVM with IAM.

- **Flyway migrations** — `trip` schema:
  - `trip.trips` (JSONB columns: stops, route_legs, ev_profile, forked_from, dates, stats)
  - `trip.revisions` (snapshot as JSONB)
  - `trip.share_tokens` (Phase 3)
  - `trip.outbox`
  - Full-text search trigger on trips table
  - All per Database.md §1
- **API endpoints**:
  - `POST /v1/trips` — create trip (auto: owner ACL grant in-process, visibility=private)
  - `GET /v1/trips/{tripId}` — load trip (ACL check: owner/editor/viewer — in-process method call)
  - `PATCH /v1/trips/{tripId}` — update trip (ACL: owner/editor); creates revision snapshot; updates search_vector via trigger
  - `DELETE /v1/trips/{tripId}` — soft-delete (ACL: owner only); handle fork orphaning
  - `GET /v1/trips/{tripId}/revisions` — list revisions (ACL: owner/editor)
  - `POST /v1/trips/{tripId}/rollback` — body: `{ "revisionId": "..." }` (ACL: owner/editor)
  - `GET /v1/trips` — list user's own trips (paginated)
- **Maps integration**:
  - On trip update (when stops change): call Maps provider for route distance/duration
  - Resilience4j: timeout 5s, circuit breaker, fallback to "route data unavailable"
  - Store route data in `route_legs` JSONB column
- **ACL enforcement**: Direct Java method call to IAM module (same JVM — no HTTP overhead)
- **Caching**: Caffeine cache for recently-accessed trips (max 200 entries, 5 min TTL)

### 2.2 Frontend — Trip UI

- Trip list page (user's trips)
- Trip create/edit form (stops with drag-to-reorder, notes, dates)
- Map rendering with stops and route polylines (Mapbox GL or Google Maps JS)
- Revision history panel with rollback button
- Delete confirmation flow

**Exit Criteria:**

- [ ] User creates a trip with 3+ stops (stored as JSONB), sees route on map
- [ ] User edits a trip, revision is created (JSONB snapshot)
- [ ] User rolls back to previous revision
- [ ] User deletes a trip (soft delete)
- [ ] Unauthorized user cannot access another user's private trip (403)
- [ ] Maps provider failure degrades gracefully (trip saves, route shows "unavailable")
- [ ] Full-text search trigger fires on insert/update (verified via `SELECT search_vector`)

---

## Phase 3 — Sharing, Forking & Outbox Events

**Goal:** Users can share trips via links, fork plans, and all trip mutations flow through the outbox → Kafka for downstream consumers.

### 3.1 Trip Engine — Sharing

- **Share link endpoints**:
  - `POST /v1/trips/{tripId}/share-links` → returns `{ tokenId, token, url }`
  - `DELETE /v1/trips/{tripId}/share-links/{tokenId}` — revoke
  - `GET /v1/share/{token}` — public (no JWT); resolves token → trip (read-only view)
- **Postgres table**: `trip.share_tokens` (per Database.md §1)
- **Visibility endpoint**: `POST /v1/trips/{tripId}/visibility` — body: `{ "visibility": "private" | "unlisted" | "public" }`

### 3.2 Trip Engine — Forking

- `POST /v1/trips/{tripId}/fork` — ACL check: trip must be public/unlisted, or user has viewer+ permission
  - Deep-copy trip row with new UUID, `forked_from` JSONB populated (snapshot for orphan resilience)
  - New trip owned by forking user (grant owner ACL in-process)
- `GET /v1/trips/{tripId}/forks` — list forks of a trip (public only, via JSONB index)
- `GET /v1/trips/{tripId}/origin` — return fork origin metadata

### 3.3 Trip Engine — Permissions (Front-Door)

- `POST /v1/trips/{tripId}/permissions` — body: `{ "userId": "...", "permission": "editor" | "viewer" }` (owner only)
  - Calls IAM ACL grant in-process
- `GET /v1/trips/{tripId}/permissions` — list collaborators

### 3.4 Transactional Outbox → Kafka

Replaces the MongoDB Change Streams Relay from the original design.

- **Outbox write**: On every trip mutation (create, update, delete, visibility change, fork), insert an event row into `trip.outbox` in the **same database transaction** as the domain write. This guarantees at-least-once event publishing without distributed transactions.
- **Outbox publisher**: An embedded `@Scheduled` component (runs every 500 ms) in the Trip & Media Service:
  1. `SELECT * FROM trip.outbox WHERE published = FALSE ORDER BY created_at LIMIT 50`
  2. Publish each event to Kafka topic `trip.events.v1` (partition by `tripId`)
  3. `UPDATE trip.outbox SET published = TRUE, published_at = NOW() WHERE outbox_id = ?`
  4. Periodically purge old published rows (`DELETE FROM trip.outbox WHERE published = TRUE AND published_at < NOW() - INTERVAL '7 days'`)
- **Idempotency**: `event_id` (ULID) is set at outbox-insert time. Consumers use it for deduplication.
- **Event types produced**:
  - `TripCreated.v1`, `TripUpdated.v1`, `TripDeleted.v1`
  - `TripVisibilityChanged.v1`
  - `TripForked.v1`
  - `TripShared.v1`

### 3.5 Frontend — Sharing & Forking UI

- Share modal: generate link, copy to clipboard, manage active links
- Public share page (SSR/SSG in Next.js, renders read-only trip view)
- Fork button on public/shared trips
- "Forked from" attribution display
- Collaborator management UI (add/remove editors/viewers)

**Exit Criteria:**

- [ ] User creates share link, another user opens it and sees the trip
- [ ] Share link revocation returns 404 for that token
- [ ] User forks a public trip; fork shows "Forked from" attribution
- [ ] Original trip deletion does NOT delete forks; fork shows "Original trip deleted"
- [ ] Outbox publisher publishes events to Kafka (verify with `kafka-console-consumer`)
- [ ] Visibility changes emit `TripVisibilityChanged.v1`
- [ ] Outbox table rows are marked published and eventually purged

---

## Phase 4 — EV Intelligence

**Goal:** Users can search for chargers near a location, compute EV-feasible routes, and see recommended charging stops.

### 4.1 EV Intelligence Service (port 8082)

- Clone service template → new service
- **Flyway migrations** — `ev` schema:
  - `ev.chargers` (PostGIS `GEOGRAPHY` column, GIST index), `ev.provider_metadata`, `ev.outbox`
  - All per Database.md §7
- **API endpoints**:
  - `GET /v1/ev/chargers/near?lat=...&lng=...&radiusKm=...&connector=...&minKw=...`
    - Query via PostGIS `ST_DWithin` (replaces Redis `GEOSEARCH`)
    - Layer Caffeine cache on top (10 min TTL, keyed by `tileKey`)
    - If stale/expired: attempt live provider call (with timeout + CB), fallback to stale data
    - Return results with `freshness: "fresh" | "stale" | "expired"` field
  - `POST /v1/ev/route/compute` — body: `{ stops[], vehicleProfile: { batteryKwh, connectorType, consumptionWhPerKm } }`
    - For each leg: calculate energy required, check feasibility, recommend charge stops if needed
    - Charger lookup via PostGIS query (near midpoints of infeasible legs)
    - Resilience4j on Maps distance/duration call
    - Return: `{ legs[], feasible: bool, recommendedChargeStops[], totalChargeTimeMin }`
- **External provider integration**:
  - OCPI / aggregator API client
  - Resilience4j: timeout 5s, circuit breaker, bulkhead

### 4.2 EV Refresh Worker (Embedded)

Runs inside the EV Intelligence Service as a `@Scheduled` component — no separate process.

- **Scheduled job** (every 30 min, configurable via Config Server):
  - Iterate geo-tiles by region/provider
  - Call provider API → parse response → upsert `ev.chargers` table (Postgres)
  - Publish `ChargerCacheRefreshed.v1` to `ev.events.v1` via outbox
  - Stagger tile refreshes to avoid thundering herd
- On provider error: log, skip tile, retry next cycle, set `stale = TRUE`, alert if sustained failure
- Expired chargers cleanup: `DELETE FROM ev.chargers WHERE expires_at < NOW() - INTERVAL '24 hours'`

### 4.3 Frontend — EV UI

- Vehicle profile settings (battery, connector, consumption)
- Charger search panel (near a stop or arbitrary map point)
- EV route compute results overlay on trip map
- Staleness indicators on charger data

**Exit Criteria:**

- [ ] Charger search returns results via PostGIS geo query
- [ ] EV route compute correctly identifies infeasible legs and suggests charge stops
- [ ] EV Refresh Worker populates charger table on schedule
- [ ] Provider outage → stale results returned with indicator
- [ ] Circuit breaker opens after sustained provider failures
- [ ] Caffeine cache serves repeated queries without hitting Postgres

---

## Phase 5 — Community, Search & Notifications

**Goal:** Users can share trips to a community feed, browse/search posts, comment, vote, bookmark, receive notifications. This phase builds the entire Community Service (port 8083).

### 5.1 Community Module

- Clone service template → Community Service (port 8083)
- **Flyway migrations** — `social`, `notif` schemas:
  - `social.posts` (with search_vector), `social.comments`, `social.votes`, `social.bookmarks`, `social.reports`, `social.outbox`
  - `notif.notification_preferences`, `notif.notifications`, `notif.delivery_log`
  - All per Database.md §3, §4
- **API endpoints**:
  - `POST /v1/posts` — body: `{ title, body, tags[], tripId? }`
  - `GET /v1/posts/{postId}` — get post (with score, author info)
  - `GET /v1/feed?sort=new|top&tag=...&page=...` — paginated feed
  - `POST /v1/posts/{postId}/comments` — body: `{ body, parentCommentId? }`
  - `GET /v1/posts/{postId}/comments?parentId=...&page=...` — list comments
  - `PUT /v1/posts/{postId}/vote` — body: `{ "direction": 1 | -1 | 0 }`
  - `POST /v1/posts/{postId}/bookmark` / `DELETE /v1/posts/{postId}/bookmark`
  - `GET /v1/me/bookmarks?page=...`
  - `POST /v1/posts/{postId}/report` — body: `{ reason }`
  - `DELETE /v1/posts/{postId}` — mod/admin soft delete
- **Events** published via outbox → `community.events.v1`:
  - `PostCreated.v1`, `PostDeleted.v1`, `CommentCreated.v1`, `PostReported.v1`

### 5.2 Search (Postgres Full-Text — No Separate Service)

Search is built into the Community Service using Postgres `tsvector` + `pg_trgm`. No Elasticsearch, no Search Indexer Worker.

- **API endpoint**: `GET /v1/search?q=...&type=trips|posts&page=...&size=...`
  - **Trips search**: Query `trip.trips` via cross-service internal HTTP call to Trip & Media Service → `GET /internal/v1/trips/search?q=...` which runs:
    ```sql
    SELECT trip_id, title, description, owner_id, tags, ts_rank(search_vector, query) AS rank
    FROM trip.trips, plainto_tsquery('english', $1) AS query
    WHERE search_vector @@ query
      AND status = 'active' AND visibility IN ('public', 'unlisted')
    ORDER BY rank DESC
    LIMIT $2 OFFSET $3;
    ```
  - **Posts search**: Query `social.posts` directly:
    ```sql
    SELECT post_id, title, body, author_user_id, score, ts_rank(search_vector, query) AS rank
    FROM social.posts, plainto_tsquery('english', $1) AS query
    WHERE search_vector @@ query AND status = 'active'
    ORDER BY rank DESC
    LIMIT $2 OFFSET $3;
    ```
  - Caffeine cache on search results (30s TTL)

### 5.3 Notification Module (Embedded in Community Service)

Notifications run inside the Community Service — no separate Notification Service or Dispatcher Worker.

- **API endpoints**:
  - `GET /v1/notifications?page=...` — paginated inbox (newest first)
  - `POST /v1/notifications/{id}/read` — mark read
  - `GET /v1/notifications/unread-count` — badge count
- **Kafka consumers** (consumer group: `community-service`):
  - `trip.events.v1`:
    - `TripForked.v1` → notify original trip owner
  - `community.events.v1` (own events, for notification creation):
    - `CommentCreated.v1` → notify post author (and parent comment author if reply)
    - `PostReported.v1` → notify moderators
  - `iam.events.v1`:
    - `UserBanned.v1` → notify banned user (in-app only)
  - `notification.commands.v1`:
    - `NotifyUser.v1` → direct notification dispatch (admin broadcasts)
- **Retention**: `@Scheduled` cleanup job deletes notifications older than 90 days
- **External dispatch** (optional for v1):
  - Email: SendGrid / SES
  - Push: FCM / APNs
  - Check user preferences before dispatching

### 5.4 Outbox Publisher (Embedded)

Same pattern as Trip & Media Service — `@Scheduled` component polls `social.outbox` every 500 ms and publishes to Kafka.

### 5.5 Frontend — Community, Search & Notifications UI

- "Share to Community" button on published trips
- Feed page with sort toggle (new/top) and tag filter
- Post detail page with comments, vote buttons
- Threaded comment display
- Search bar → search results page with tabs (trips/posts)
- Notification bell icon with unread count badge
- Notification dropdown/panel

**Exit Criteria:**

- [ ] User creates a post linked to a trip; it appears in feed
- [ ] Comments (threaded) display correctly
- [ ] Vote updates score; retract works
- [ ] Bookmark add/remove works
- [ ] Mod deletes a post; it disappears from feed
- [ ] Search returns relevant trips and posts via Postgres full-text search
- [ ] User A comments on User B's post → User B sees notification
- [ ] User A forks User B's trip → User B sees notification
- [ ] Mark read works; unread count updates
- [ ] Outbox publisher publishes `PostCreated.v1` and `CommentCreated.v1` to Kafka

---

## Phase 6 — Media Pipeline

**Goal:** Users can upload images to trips and posts. Uploads are scanned, thumbnails generated, and safe URLs returned.

### 6.1 Media Module (inside Trip & Media Service)

Media runs inside the Trip & Media Service (port 8081) — no separate Media Service.

- **Flyway migrations** — `media` schema:
  - `media.media` (per Database.md §5)
- **API endpoints**:
  - `POST /v1/media/upload-url` — body: `{ filename, mimeType, sizeBytes }` → validate type/size → generate pre-signed upload URL → insert record (status=pending) → return `{ mediaId, uploadUrl, expiresIn }`
  - `POST /v1/media/complete` — body: `{ mediaId }` → set status=processing, trigger media processing
  - `GET /v1/media/{mediaId}` — metadata + URLs (only if status=ready)
- **Size/type limits**: max 10 MB, allowed types: JPEG, PNG, WebP, GIF

### 6.2 Media Processing Worker (Embedded)

Runs inside Trip & Media Service as a `@Scheduled` or `@Async` component.

- Polls `media.media WHERE status = 'uploaded'` every 5 seconds
- Processing pipeline:
  1. Download from MinIO
  2. Validate MIME type (magic bytes, not just extension)
  3. Virus scan (ClamAV if available, or skip for university project)
  4. If clean: generate thumbnails (small: 200px, medium: 600px), upload to MinIO
  5. Update media record: `status=ready`, set thumbnail URLs, dimensions
  6. If blocked: set `status=blocked`, log reason

### 6.3 Integration Points

- Trip Engine: `PATCH /v1/trips/{tripId}` accepts `mediaIds[]` in stops — validates media exists and status=ready (in-process call)
- Community: `POST /v1/posts` accepts `mediaIds[]` — validates via internal HTTP call to Trip & Media Service

### 6.4 Frontend — Media Integration

- Image upload component (drag-and-drop or file picker)
- Upload progress indicator
- Display images in trip stops and community posts
- Thumbnails in feeds/lists, full-size on detail views

**Exit Criteria:**

- [ ] User uploads an image → receives `mediaId` → image appears after processing
- [ ] Invalid file type rejected
- [ ] Large file rejected (>10 MB)
- [ ] Thumbnail generated and served
- [ ] Blocked file (simulated) does not render

---

## Phase 7 — AI Planning Assistance (Bonus)

**Goal:** Users can ask the AI for itinerary suggestions and EV-optimized plan improvements.

### 7.1 AI Orchestrator Service (port 8084)

- Clone service template → AI Orchestrator Service (port 8084)
- **Flyway migrations** — `ai` schema:
  - `ai.prompt_configs`, `ai.sessions`, `ai.usage_log`, `ai.quota_counters` (per Database.md §6)
- **API endpoints**:
  - `POST /v1/ai/plan/suggest` — body: `{ tripId }` → fetch trip via internal HTTP to Trip & Media Service → fetch EV context via internal HTTP to EV Intelligence Service → build prompt → call Gemini → return structured actions
  - `POST /v1/ai/plan/chat` — body: `{ tripId, message }` → conversational, streaming SSE response → structured actions + explanation
  - Both: check quota before calling LLM; reject with 429 if exceeded
- **Quota enforcement**:
  - `ai.quota_counters` is source of truth (Postgres)
  - Caffeine cache for fast-path quota check (30s TTL)
  - Atomic increment via SQL (per Database.md §6)
- **LLM integration**:
  - Gemini SDK (HTTP client)
  - Resilience4j: timeout 30s, circuit breaker, bulkhead (AI traffic isolated)
  - Streaming: SSE for chat endpoint
  - Safety: output filtering, block PII in prompts
  - Redacted logging: log prompt template + token counts, never raw user content
- **Structured action schema** returned to frontend:
  ```json
  {
    "actions": [
      {
        "type": "addStop",
        "params": { "name": "...", "lat": 37.7, "lng": -122.4, "order": 2 }
      },
      {
        "type": "insertChargeStop",
        "params": {
          "afterStopId": "stop_01J...",
          "chargerId": "...",
          "chargerName": "..."
        }
      }
    ]
  }
  ```
  Frontend displays proposed changes as diff view → user confirms → frontend calls Trip Engine PATCH to apply

### 7.2 Frontend — AI UI

- "AI Suggest" button on trip detail page
- Chat panel (side drawer) for conversational planning
- Streaming response display
- Proposed changes as diff view (before/after)
- User confirms → changes applied via Trip Engine API
- Quota usage display in user settings

### 7.3 Rate Limiting Split

- **Arcjet** (Next.js): rate limiting — max 5 AI requests/minute/user (abuse prevention)
- **AI Orchestrator**: quota/budget — max 100K tokens/month/user (cost control)
- These are complementary, not redundant

**Exit Criteria:**

- [ ] User requests AI suggestion → receives structured actions → confirms → trip updated
- [ ] Chat streaming works (SSE)
- [ ] Quota exceeded → 429 response with clear message
- [ ] LLM down → 503 response; core trip features unaffected
- [ ] AI circuit breaker opens after sustained LLM failures
- [ ] Token usage tracked accurately in Postgres

---

## Cross-Cutting: Wired Throughout All Phases

These are not separate phases — they are integrated into every phase as each service is built:

| Concern                               | Implementation                                                     | When                                                          |
| ------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------- |
| Structured JSON logging               | Service template; logback config                                   | Every phase                                                   |
| Correlation ID propagation            | NGINX generates if absent; services propagate; Kafka headers carry | Phase 1+                                                      |
| Health endpoints (`/actuator/health`) | Service template (Spring Boot Actuator)                            | Every phase                                                   |
| Config Server client                  | Service template (`spring-cloud-starter-config`)                   | Every phase                                                   |
| Resilience4j (external calls)         | Configured per integration                                         | Phase 2+ (Maps), Phase 4 (EV), Phase 5 (email), Phase 7 (LLM) |
| Flyway migrations                     | Run on deploy, before service starts                               | Every service                                                 |
| Audit logging                         | IAM module in Trip & Media Service                                 | Phase 1–3                                                     |
| Transactional Outbox                  | Service template; `@Scheduled` publisher component                 | Phase 2+ (Trip, EV, Community)                                |
| Caffeine caching                      | Service template; configured per domain                            | Phase 2+ (trips, chargers, quotes, search results)            |
| Security (shared secret header)       | NGINX passes `X-Internal-Secret`; services validate                | Phase 1 setup, enforce from Phase 2+                          |

---

## Phase Dependencies (DAG)

```
Phase 0 (Infra: VM + Postgres + Kafka + Config Server + Keycloak + NGINX)
  └── Phase 1 (Auth + NGINX Routing + IAM module)
        ├── Phase 2 (Trip Core CRUD — Postgres+JSONB)
        │     └── Phase 3 (Sharing + Forking + Outbox Events)
        │           ├── Phase 4 (EV Intelligence — PostGIS + embedded refresh)
        │           ├── Phase 5 (Community + Search + Notifications)
        │           └── Phase 7 (AI) ← also needs Phase 4
        └── Phase 6 (Media) ← only needs Phase 1; can run parallel to 4–5
```

**Parallelization opportunities:**

- Phase 4 (EV) and Phase 5 (Community) can run **in parallel** after Phase 3
- Phase 6 (Media) can run **in parallel** with Phases 4–5 (only depends on Phase 1)
- Phase 7 (AI) starts after both Phase 4 and Phase 5 are done

---

## Estimated Timeline (Team of 2–3 Engineers)

| Phase                        | Duration  | Cumulative |
| ---------------------------- | --------- | ---------- |
| Phase 0 (Infra)              | 1–2 weeks | Week 2     |
| Phase 1 (Auth + NGINX + IAM) | 1–2 weeks | Week 4     |
| Phase 2 (Trip Core)          | 2 weeks   | Week 6     |
| Phase 3 (Sharing + Outbox)   | 1–2 weeks | Week 8     |
| Phase 4 + 5 (parallel)       | 3 weeks   | Week 11    |
| Phase 6 (Media)              | 1 week    | Week 12    |
| Phase 7 (AI)                 | 2 weeks   | Week 14    |
| Hardening + testing          | 1–2 weeks | Week 16    |

**Total: ~16 weeks (4 months) to production-ready with all features including AI.**
**MVP (through Phase 5, no media/AI): ~11 weeks (~2.5 months).**

Timeline is significantly shorter than original because:

- No MongoDB/Redis/Elasticsearch setup and integration
- No separate Search/Notification/Media services
- No Eureka/Vault/Schema Registry configuration
- Workers embedded in parent services (no separate deployment)
- Single VM — no multi-node coordination

---

## Post-Launch Checklist

Before go-live, verify:

- [ ] All Actuator health endpoints responding on all 4 services
- [ ] Runbooks written: Kafka lag, outbox stuck, EV provider outage, Keycloak outage, Postgres backup/restore, service restart
- [ ] Test with ~10 concurrent users (manual or simple script)
- [ ] Backup/restore tested for PostgreSQL (single `pg_dump`/`pg_restore` covers everything)
- [ ] Security: secrets in env vars only, no secrets in logs or Git
- [ ] No internal endpoints exposed via NGINX (only `/v1/*` routes)
- [ ] Outbox publisher running (no stuck unpublished rows)
- [ ] Data retention jobs running (notifications 90d, revisions cap, outbox purge)
- [ ] MinIO accessible only via pre-signed URLs (no public bucket)
- [ ] Kafka consumer groups are consuming without lag

---
