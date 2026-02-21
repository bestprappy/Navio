<p align="center">
  <img src="https://img.shields.io/badge/status-in%20development-blue?style=for-the-badge" alt="Status" />
  <img src="https://img.shields.io/badge/architecture-microservices-informational?style=for-the-badge" alt="Architecture" />
  <img src="https://img.shields.io/badge/backend-Spring%20Boot%203-6DB33F?style=for-the-badge&logo=springboot&logoColor=white" alt="Spring Boot" />
  <img src="https://img.shields.io/badge/messaging-Apache%20Kafka-231F20?style=for-the-badge&logo=apachekafka&logoColor=white" alt="Kafka" />
  <img src="https://img.shields.io/badge/database-PostgreSQL%2016-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/auth-Keycloak%20OIDC-4D4D4D?style=for-the-badge&logo=keycloak&logoColor=white" alt="Keycloak" />
  <img src="https://img.shields.io/badge/frontend-Next.js-000000?style=for-the-badge&logo=nextdotjs&logoColor=white" alt="Next.js" />
</p>

# Navio

> **A distributed, event-driven microservices platform for intelligent trip planning — with built-in EV charging intelligence, a Reddit-like community layer for posting and discussing travel plans, and a forking model to remix itineraries with attribution.**

Navio decomposes a real-world trip-planning product — itinerary creation, EV route optimization, community discussions, media uploads, and itinerary forking — into **4 domain-aligned Spring Boot services** communicating through an **Apache Kafka event backbone**. All traffic enters through a single **NGINX reverse proxy**, data is isolated via **schema-per-service** on a shared PostgreSQL instance, and the entire stack is designed to run on a **single 8 GB university VM** serving ~10 concurrent users.

---

## Table of Contents

1. [Business Purpose](#business-purpose)
2. [Core Features](#core-features)
3. [System Architecture](#system-architecture)
4. [Service Inventory](#service-inventory)
5. [Tech Stack](#tech-stack)
6. [Data Architecture](#data-architecture)
7. [Messaging & Events](#messaging--events)
8. [Service Decoupling Strategy](#service-decoupling-strategy)
9. [Repository Structure](#repository-structure)
10. [Getting Started](#getting-started)
11. [Running the Stack](#running-the-stack)
12. [Implementation Phases](#implementation-phases)
13. [License](#license)

---

## Business Purpose

Modern trip planning is more than plotting waypoints on a map. EV drivers need real-time charging-station availability woven into their routes. Travelers want to share itineraries like social posts, fork and remix them, and discuss logistics in context. **Navio** tackles this complexity with a distributed architecture that mirrors how companies like Airbnb, Uber, and Google Maps engineer their platforms:

| Concern                       | How Navio Addresses It                                                                                                                                 |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **High throughput**           | Apache Kafka decouples producers from consumers, enabling non-blocking event processing (route recalculations, notifications, search denormalization). |
| **Independent deployability** | 4 domain-aligned services, each owning its own Postgres schema and release cycle.                                                                      |
| **Single entry point**        | NGINX reverse proxy routes, terminates TLS, and rate-limits all inbound traffic. No service is directly exposed.                                       |
| **Data integrity**            | Transactional Outbox pattern guarantees at-least-once event publishing without distributed transactions.                                               |
| **Observability**             | Spring Boot Actuator endpoints, structured JSON logging with correlation ID propagation across all services and Kafka headers.                         |

---

## Core Features

| Domain                    | Capabilities                                                                                                                                                                                             |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Trips**                 | CRUD with JSONB-embedded stops/routes, revision history & rollback, visibility transitions (private/unlisted/public), share links with expiry, fork with attribution chain                               |
| **IAM**                   | Keycloak OIDC user sync, three-tier roles (user/mod/admin), ban/unban with history, generic resource-level ACL engine (owner/editor/viewer), append-only audit log for all security-sensitive actions    |
| **EV Intelligence**       | Vehicle profiles (connector, battery, consumption), charger search via PostGIS geo-queries, EV route feasibility & charge-stop recommendations, scheduled charger data refresh with graceful degradation |
| **Community**             | Manual "Share to Community" posts, threaded comments, vote/score system (upsert semantics), bookmarks, moderation (report, ban/unban), Postgres full-text search across trips and posts                  |
| **Notifications**         | In-app inbox, preference management, event-driven dispatch (comments, replies, forks, moderation actions), optional email/push                                                                           |
| **Media**                 | Signed upload URLs, MIME validation, thumbnail generation, safe rendering URLs                                                                                                                           |
| **AI Planning** _(bonus)_ | LLM-powered itinerary suggestions, chat-with-plan (streaming SSE), structured edit actions validated server-side, per-user quota/budget enforcement                                                      |

---

## System Architecture

```
                         ┌───────────────┐
                         │    Client     │
                         │  (Next.js)    │
                         │  + Keycloak   │
                         └──────┬────────┘
                                │  HTTPS
                                ▼
                       ┌─────────────────┐
                       │     NGINX       │ ◄── Single public entry point
                       │ (Reverse Proxy) │     TLS termination, rate limiting
                       └──┬──┬──┬──┬─────┘
                          │  │  │  │
          ┌───────────────┘  │  │  └───────────────┐
          ▼                  │  │                   ▼
 ┌─────────────────┐        │  │        ┌────────────────────┐
 │  Trip & Media   │        │  │        │   AI Orchestrator  │
 │    Service      │        │  │        │     (Bonus)        │
 │   (port 8081)   │        │  │        │   (port 8084)      │
 │                 │        │  │        └────────────────────┘
 │ • Trip Engine   │        ▼  ▼
 │ • IAM Module    │  ┌──────────────┐  ┌───────────────────┐
 │ • Media Module  │  │  EV Intel    │  │  Community        │
 └────────┬────────┘  │  Service     │  │  Service          │
          │           │ (port 8082)  │  │  (port 8083)      │
          │           └──────┬───────┘  │                   │
          │                  │          │ • Social Module    │
          │                  │          │ • Notifications    │
          │                  │          │ • Search           │
          │                  │          └────────┬───────────┘
          │                  │                   │
          └──────────┬───────┴───────────────────┘
                     ▼
           ┌──────────────────┐
           │   Apache Kafka   │ ◄── Async event backbone
           │  (Single Broker) │     JSON serialization
           └──────────────────┘
                     │
                     ▼
           ┌──────────────────┐
           │   PostgreSQL 16  │ ◄── Single instance, 7 schemas
           │  + PostGIS       │     Schema-per-service isolation
           └──────────────────┘
```

**Key architectural decisions:**

- **NGINX** replaces Spring Cloud Gateway — saves ~300 MB RAM; static routing is sufficient for 4 services on localhost
- **PostgreSQL + JSONB** replaces MongoDB — one DB engine; JSONB handles nested trip documents; eliminates ~500 MB RAM
- **Caffeine** replaces Redis — in-process JVM caching with zero network overhead; sufficient for ~10 users
- **Postgres `tsvector` + `pg_trgm`** replaces Elasticsearch — zero extra RAM; sufficient for < 100K documents
- **Transactional Outbox** replaces Change Streams — native to Postgres; no separate relay process

---

## Service Inventory

### Trip & Media Service _(port 8081)_

The core service — owns trips, user identity, and media.

| Module          | Postgres Schema | Responsibilities                                                                                                             |
| --------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **Trip Engine** | `trip`          | Trip CRUD, JSONB stops/routes, revisions & rollback, visibility, share links, forking with attribution, Maps API integration |
| **IAM**         | `iam`           | User profile mirror from Keycloak, roles (user/mod/admin), ban/unban, ACL engine (resource-level permissions), audit logging |
| **Media**       | `media`         | Pre-signed upload URLs, embedded processing worker (MIME validation, thumbnail generation), safe rendering URLs              |

**Events produced:** `TripCreated.v1`, `TripUpdated.v1`, `TripDeleted.v1`, `TripForked.v1`, `TripVisibilityChanged.v1`, `UserRegistered.v1`, `UserBanned.v1`

### EV Intelligence Service _(port 8082)_

| Postgres Schema | Responsibilities                                                                                                                                                                     |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ev`            | Charger provider integrations (OCPI/aggregator APIs), PostGIS geo-queries (`ST_DWithin`), EV route feasibility & charge-stop recommendations, embedded refresh worker (`@Scheduled`) |

**Degradation:** Provider down → serve stale Postgres data marked `"stale"`

### Community Service _(port 8083)_

| Module            | Postgres Schema                                   | Responsibilities                                                                           |
| ----------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| **Social**        | `social`                                          | Posts, threaded comments, votes (upsert), bookmarks, moderation, outbox publisher          |
| **Notifications** | `notif`                                           | In-app inbox, preferences, Kafka consumer dispatcher (reacts to trip/community/IAM events) |
| **Search**        | _(uses `social` + internal HTTP to Trip service)_ | Postgres full-text search via `tsvector` generated columns + GIN indexes                   |

### AI Orchestrator _(port 8084, bonus)_

| Postgres Schema | Responsibilities                                                                                                                                 |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ai`            | LLM integration (Gemini), structured plan edit actions, chat-with-plan (streaming SSE), quota/budget enforcement (Postgres + Caffeine fast-path) |

**Hard rule:** No direct database access to other services — AI uses internal HTTP APIs only.

---

## Tech Stack

### Backend

| Layer                | Technology                      | Purpose                                                                   |
| -------------------- | ------------------------------- | ------------------------------------------------------------------------- |
| **Runtime**          | Java 21+ / Spring Boot 3        | Service framework, DI, auto-configuration                                 |
| **Reverse Proxy**    | NGINX                           | Single entry point, static routing to `localhost` ports, TLS termination  |
| **Auth**             | Keycloak (OIDC/JWT)             | Identity provider, JWKS-based JWT validation in each service              |
| **Database**         | PostgreSQL 16 + PostGIS         | Single instance, 7 schemas, JSONB for nested structures, geo-queries      |
| **Messaging**        | Apache Kafka (single broker)    | Async event streaming, JSON serialization, DLQ topics                     |
| **Caching**          | Caffeine (in-process JVM)       | LRU caches for trips, ACLs, chargers, quotas — no Redis                   |
| **Search**           | Postgres `tsvector` + `pg_trgm` | Full-text search with weighted ranking — no Elasticsearch                 |
| **Migrations**       | Flyway                          | Schema versioning, runs on service startup                                |
| **Resilience**       | Resilience4j                    | Circuit breakers, timeouts, bulkheads on all external calls               |
| **Configuration**    | Spring Cloud Config Server      | Git-backed centralized config (feature flags, timeouts, topic names)      |
| **Object Storage**   | MinIO / local filesystem        | Media uploads, thumbnails, exports                                        |
| **Communication**    | Java HttpClient                 | Synchronous cross-service calls (internal REST APIs)                      |
| **Event Publishing** | Transactional Outbox            | Domain events written in same DB transaction, polled & published to Kafka |

### Frontend

| Layer             | Technology             | Purpose                                    |
| ----------------- | ---------------------- | ------------------------------------------ |
| **Framework**     | Next.js                | SSR/SSG, routing, API layer                |
| **Auth**          | Keycloak JS / NextAuth | OIDC sign-up/sign-in flow                  |
| **Validation**    | Zod                    | Client-side form validation                |
| **Rate Limiting** | Arcjet                 | App-level, auth-aware rate limiting        |
| **Maps**          | Google Maps / Mapbox   | Route rendering, stop placement, polylines |

---

## Data Architecture

All 7 schemas reside on a **single PostgreSQL instance**. Each service owns its schemas exclusively — **no cross-schema joins or foreign keys**, preserving microservice data isolation even on a shared instance.

| Schema   | Owner Service   | Key Tables & Patterns                                                                                                             |
| -------- | --------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `trip`   | Trip & Media    | `trips` (JSONB: stops, route_legs, ev_profile, forked_from), `revisions` (JSONB snapshots), `share_tokens`, `outbox`              |
| `iam`    | Trip & Media    | `users`, `bans`, `acl_entries`, `audit_log`, `outbox`                                                                             |
| `media`  | Trip & Media    | `media` (upload tracking, status, thumbnail URLs)                                                                                 |
| `ev`     | EV Intelligence | `chargers` (PostGIS `GEOGRAPHY(POINT, 4326)`, GIST index, `expires_at`), `provider_metadata`, `outbox`                            |
| `social` | Community       | `posts` (with `search_vector` tsvector), `comments` (threaded via `parent_comment_id`), `votes`, `bookmarks`, `reports`, `outbox` |
| `notif`  | Community       | `notification_preferences`, `notifications`, `delivery_log`                                                                       |
| `ai`     | AI Orchestrator | `prompt_configs`, `sessions`, `usage_log`, `quota_counters`                                                                       |

---

## Messaging & Events

### Event Envelope

Every event published to Kafka follows a standard envelope:

```json
{
  "eventId": "evt_01J...ulid",
  "eventType": "TripForked.v1",
  "occurredAt": "2026-02-07T12:34:56Z",
  "producer": "trip-media-service",
  "partitionKey": "trip_8b1f2c",
  "trace": { "traceId": "...", "spanId": "..." },
  "payload": {}
}
```

### Kafka Topics

| Topic                      | Partition Key | Producers             | Consumers                                   |
| -------------------------- | ------------- | --------------------- | ------------------------------------------- |
| `trip.events.v1`           | `tripId`      | Trip & Media (outbox) | Community (notifications, search denorm)    |
| `iam.events.v1`            | `userId`      | Trip & Media (outbox) | Community (author name sync, notifications) |
| `community.events.v1`      | `postId`      | Community (outbox)    | Community (notification dispatcher)         |
| `ev.events.v1`             | `tileKey`     | EV Intelligence       | Observability                               |
| `notification.commands.v1` | `userId`      | Admin tools           | Community (notification dispatcher)         |

### Transactional Outbox Pattern

Each service writes domain events to its `outbox` table within the **same database transaction** as the domain write. An embedded `@Scheduled` publisher polls every 500 ms, sends to Kafka, and marks rows published. This guarantees at-least-once delivery without distributed transactions.

All consumers deduplicate on `eventId` (ULID) for idempotency.

---

## Service Decoupling Strategy

Navio enforces **strict service boundaries** — no shared DTOs, no shared libraries, no cross-schema database access.

### Why?

Shared data-transfer objects create hidden coupling. Changing a field in a shared DTO forces a coordinated release across every service that depends on it, negating the key benefit of microservices: independent deployability.

### How Navio handles cross-service communication:

| Pattern                            | Mechanism                             | When Used                                                                                                                                    |
| ---------------------------------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **Asynchronous events**            | Kafka topics via Transactional Outbox | Default. Domain events (`TripForked`, `CommentCreated`, etc.) flow through Kafka; each consumer deserializes into its own internal model.    |
| **Synchronous request / response** | **Java HttpClient** (internal REST)   | Cross-service queries (e.g., Community → Trip for search, AI → Trip/EV for context). All internal endpoints versioned under `/internal/v1/`. |
| **In-process calls**               | Direct Java method invocation         | Modules within the same JVM (e.g., Trip Engine → IAM ACL checks share the same service, so no HTTP overhead).                                |

> **Rule:** Every service defines its own internal domain models. Data received from another service is mapped at the boundary — never passed through as a shared class.

### Security: East–West Communication

All services run on **localhost** — no network exposure for internal calls. A shared secret header (`X-Internal-Auth`) is validated on internal endpoints. No mTLS needed (single VM, loopback traffic only).

---

## Repository Structure

This is an **umbrella repository** that uses **Git Submodules** to compose independently versioned components into a single, cloneable workspace.

```
Navio/                              ← You are here (umbrella repo)
├── client/                         ← Git submodule → Navio-Client (Next.js frontend)
├── server/                         ← Git submodule → Navio-Server (backend ecosystem)
│   ├── trip-media-service/         ← Submodule – Trip Engine + IAM + Media (port 8081)
│   ├── ev-intelligence-service/    ← (planned) Submodule – EV charger search & routing (port 8082)
│   ├── community-service/          ← (planned) Submodule – Social, notifications, search (port 8083)
│   └── ai-orchestrator/            ← (planned) Submodule – LLM integration (port 8084)
├── docs/                           ← System design, database design, implementation guide
├── docker-compose.yml              ← Orchestrates all services locally
└── README.md
```

> `server/` is itself a Git repository ([Navio-Server](https://github.com/bestprappy/Navio-Server)) that houses each backend microservice as its own submodule. This two-level submodule strategy cleanly separates the frontend and backend ecosystems while keeping every service independently versioned.

> The `client/` and `server/` submodules are private repositories. If you have been granted access, clone with `--recurse-submodules`. Otherwise, the architecture and orchestration are fully documented in this README and the [docs/](docs/) directory.

---

## Getting Started

### Prerequisites

| Tool                    | Version          |
| ----------------------- | ---------------- |
| Git                     | 2.13+            |
| Docker & Docker Compose | 24+ / v2 plugin  |
| Java                    | 21+              |
| Node.js                 | 18+ LTS          |
| PostgreSQL (local dev)  | 16+ with PostGIS |

### Clone with Submodules

```bash
# Clone the umbrella repo AND all submodules in a single command
git clone --recurse-submodules https://github.com/bestprappy/Navio.git
cd Navio
```

**Already cloned without `--recurse-submodules`?** Initialize retroactively:

```bash
git submodule update --init --recursive
```

**Pull the latest changes across all submodules:**

```bash
git submodule update --remote --merge
```

---

## Running the Stack

```bash
# Build and start all services
docker compose up --build

# Tear down and remove volumes
docker compose down -v
```

| Service                 | Local URL               | Port |
| ----------------------- | ----------------------- | ---- |
| NGINX (entry point)     | `http://localhost`      | 80   |
| Trip & Media Service    | `http://localhost:8081` | 8081 |
| EV Intelligence Service | `http://localhost:8082` | 8082 |
| Community Service       | `http://localhost:8083` | 8083 |
| AI Orchestrator         | `http://localhost:8084` | 8084 |
| Config Server           | `http://localhost:8888` | 8888 |
| Keycloak                | `http://localhost:8180` | 8180 |
| Kafka Broker            | `localhost:9092`        | 9092 |
| PostgreSQL              | `localhost:5432`        | 5432 |

---

## Implementation Phases

Development follows a strict dependency-ordered phased approach. Each phase produces a deployable increment.

| Phase | Name                              | Milestone                                                                                  |
| ----- | --------------------------------- | ------------------------------------------------------------------------------------------ |
| **0** | Infrastructure & Platform         | VM, PostgreSQL (7 schemas), Kafka, Config Server, Keycloak, NGINX, MinIO, service template |
| **1** | Auth & IAM                        | Keycloak OIDC flow, NGINX routing, IAM module (users, roles, ACLs), frontend shell         |
| **2** | Trip Engine (Core CRUD)           | Trip create/edit/delete with JSONB stops, revision history & rollback, Maps integration    |
| **3** | Sharing, Forking & Outbox         | Share links, forking with attribution, Transactional Outbox → Kafka events                 |
| **4** | EV Intelligence                   | Charger search (PostGIS), EV route compute, embedded refresh worker                        |
| **5** | Community, Search & Notifications | Posts, comments, votes, Postgres FTS, in-app notifications, event-driven dispatcher        |
| **6** | Media Pipeline                    | Upload, scan, thumbnails, safe URLs (embedded in Trip & Media)                             |
| **7** | AI Planning _(bonus)_             | LLM suggest, chat-with-plan, quota enforcement                                             |

> Phases 4 & 5 can run in parallel. Phase 6 can run parallel to 4–5 (only depends on Phase 1). Phase 7 starts after 4 & 5.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

<p align="center"><sub>Built by <a href="https://github.com/bestprappy">bestprappy</a> — Navio</sub></p>
