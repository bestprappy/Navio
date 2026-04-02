# Navio — Claude Code Context

## Project Overview

Navio is a distributed, event-driven trip planning platform built as a university capstone.
It decomposes into **4 domain-aligned Spring Boot services** behind an **NGINX reverse proxy**,
running on a **single 8 GB university VM** targeting ~10 concurrent users.

```
Navio/                              ← umbrella repo (you are here)
├── client/                         ← Git submodule → Next.js frontend
├── server/                         ← Git submodule → Navio-Server
│   └── Trip-Media-Service/         ← Git submodule → port 8081 (in progress)
├── docs/                           ← System design, database, implementation guides
└── docker-compose.yml
```

## Services

| Service                  | Port | Submodule                   | Status      |
| ------------------------ | ---- | --------------------------- | ----------- |
| Trip & Media Service     | 8081 | `Trip-Media-Service/`       | In progress |
| EV Intelligence Service  | 8082 | `ev-intelligence-service/`  | Planned     |
| Community Service        | 8083 | `community-service/`        | Planned     |
| AI Orchestrator          | 8084 | `ai-orchestrator/`          | Planned     |
| Spring Cloud Config      | 8888 | —                           | Planned     |
| Keycloak                 | 8180 | —                           | Planned     |

## Tech Stack

- **Backend:** Java 25 / Spring Boot 4.x / Spring Data JPA / Flyway / Resilience4j / Lombok
- **Frontend:** Next.js / Keycloak JS / Zod / Arcjet / Google Maps or Mapbox
- **Database:** PostgreSQL 16 — single instance, 7 schemas (`trip`, `iam`, `media`, `ev`, `social`, `notif`, `ai`)
- **Messaging:** Apache Kafka (single broker) — JSON serialization, no Schema Registry
- **Auth:** Keycloak OIDC — JWT validated per-service via JWKS endpoint
- **Caching:** Caffeine (in-process JVM) — no Redis
- **Search:** Postgres `tsvector` + `pg_trgm` — no Elasticsearch
- **Object Storage:** MinIO / local filesystem
- **Proxy:** NGINX (static routing to localhost ports) — no Spring Cloud Gateway, no Eureka

## Hard Architectural Rules

1. **No cross-schema joins or foreign keys.** Each service owns its schemas exclusively. Cross-service data access goes through internal HTTP or Kafka events — never direct DB reads.
2. **No shared DTOs or shared libraries.** Every service defines its own internal domain models. Data received from another service is mapped at the boundary.
3. **Transactional Outbox for all Kafka events.** Domain events are written to an `outbox` table in the same DB transaction as the domain write. An embedded `@Scheduled` publisher polls and forwards to Kafka. Never publish to Kafka directly from business logic.
4. **ACL checks for trip access are in-process.** The IAM module lives in the same JVM as the Trip Engine. Use direct Java method calls — never HTTP.
5. **Internal endpoints use `X-Internal-Auth` header.** All `localhost:port/internal/v1/...` endpoints validate this shared secret. Never expose internal endpoints through NGINX.
6. **Secrets never in Git or Config Server.** All secrets (`POSTGRES_PASSWORD`, `KEYCLOAK_ADMIN_SECRET`, `MINIO_SECRET_KEY`, `MAPS_API_KEY`, etc.) come from environment variables only.
7. **Soft deletes only.** Never physically DELETE domain entities in v1. Use `status` column or `deleted_at` timestamp.
8. **All PKs are UUID.** Prefer ULIDs or UUIDv7 for sortability. All timestamps are `TIMESTAMPTZ` (UTC).

## Coding Conventions (Java / Spring Boot)

- Use **Lombok** (`@Data`, `@Builder`, `@RequiredArgsConstructor`, etc.) — no boilerplate getters/setters
- **Flyway** migrations live in `src/main/resources/db/migration/` — naming: `V{n}__{description}.sql`
- Outbox event `eventId` is a **ULID** — set at outbox-insert time, used by consumers for deduplication
- All Kafka events follow the standard envelope: `{ eventId, eventType, occurredAt, producer, partitionKey, trace, payload }`
- Error responses follow: `{ status, error, message, correlationId, timestamp }`
- Correlation ID: read from `X-Correlation-Id` header or generate if absent; propagate through all log entries and Kafka headers
- Resilience4j wraps **all** external calls (Maps API, MinIO, EV providers, LLM) — timeout + circuit breaker minimum
- Caffeine cache config goes through Spring Cache abstraction — keep TTL and max size configurable via Config Server

## Submodule Workflow

```bash
# Pull latest across all submodules
git submodule update --remote --merge

# After committing inside a submodule, update the parent pointer
cd ..  # back to parent repo
git add <submodule-dir>
git commit -m "Update <submodule> submodule pointer"
git push
```

When editing code inside `server/Trip-Media-Service/`, remember to push both:
1. The submodule repo (`Trip-Media-Service`)
2. The parent repo (`Navio-Server`) with the updated submodule pointer
3. The umbrella repo (`Navio`) if the server submodule pointer changed

## Key Documentation

- [System Design Summary](docs/Summary.md)
- [Database Design](docs/Database.md) — full SQL DDL for all 7 schemas
- [Implementation Guide](docs/Implementation.md) — phased build plan with exit criteria per phase
- [Server README](server/README.md) — IAM deep-dive, auth flow, cross-service communication
- [Trip & Media Service README](server/Trip-Media-Service/README.md) — full API reference, module breakdown
