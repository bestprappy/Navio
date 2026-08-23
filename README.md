# Navio

> An EV-aware trip-planning platform with itinerary building, public trip discovery, community discussions, and optional local-AI planning assistance.

Navio uses five domain-oriented Spring Boot services when optional AI is enabled and four when it is disabled. Three additional Spring platform applications are mandatory: Spring Cloud Gateway, Spring Cloud Config Server, and Eureka Discovery Server. Production traffic enters through NGINX and then uses the same Spring Cloud Gateway used in development. AI Planning uses Spring AI with a replaceable provider: it runs beside Ollama on a CPU-only ML VM or on the application VM with a hosted model API.

## Final architecture

### Runtime inventory

| Component | Type | Port | Deployment |
| --- | --- | ---: | --- |
| User Management Service | Spring Boot | 8081 | Application VM |
| Trip Planning Service | Spring Boot | 8082 | Application VM |
| Mobility & EV Service | Spring Boot | 8083 | Application VM |
| Community Service | Spring Boot | 8084 | Application VM |
| AI Planning Service | Spring Boot + Spring AI | 8085 | ML VM with Ollama, or application VM with hosted provider |
| API Gateway | Spring Cloud Gateway | 8080 | Application VM; dev and production |
| Configuration Server | Spring Cloud Config Server | 8888 | Application VM; private only |
| Discovery Server | Eureka | 8761 | Application VM; private only |
| Identity Provider | Keycloak | 8180 | Application VM |
| Production edge proxy | NGINX | 80/443 | Application VM |
| Model server | Ollama | 11434 | Optional local-inference profile; ML VM loopback only |
| Primary database | PostgreSQL 16 + PostGIS | 5432 | Application VM; private only |
| Event broker | Kafka, single KRaft broker | 9092 | Application VM; private only |
| Telemetry collector | Grafana Alloy | Private management port only | Each active VM |
| Central observability backend | Hosted logs, metrics, traces, and Grafana | HTTPS | External; required by the 8 GB profile |

Only NGINX is publicly reachable in production. Gateway, Config Server, Eureka, backend ports, PostgreSQL, Kafka, Keycloak administration endpoints, telemetry management endpoints, and Ollama remain private.

Self-hosted AI profile:

```text
                              Application VM
                           Ubuntu Server 24.04
                         4 vCPU / 8 GB / 60 GB

 Browser ──HTTPS──> NGINX edge ──> Next.js
                         │
                         └──> Spring Cloud Gateway :8080
                                  │ Eureka discovery
                                  ├──> User Management Service :8081
                                  ├──> Trip Planning Service    :8082
                                  ├──> Mobility & EV Service    :8083
                                  └──> Community Service        :8084

 Config Server :8888 ──> Eureka :8761 ──> Gateway + service registrations
 Keycloak :8180 / PostgreSQL/PostGIS / Kafka / Grafana Alloy
                         │
                         │ private network
                         ▼
                         Machine-learning VM
                           Ubuntu Server 24.04
                         8 vCPU / 8 GB / 80 GB

                         AI Planning Service :8085 (Eureka registered)
                                  │
                                  └──> Ollama :11434 (localhost only)
```

## Service responsibilities

### User Management Service

Owns Navio-specific user data and provides an administration facade over Keycloak.

- Local profile created from the Keycloak `sub` claim
- Display name, handle, avatar, bio, location, privacy, and preferences
- Saved vehicles and default vehicle
- User search and administration
- Suspend/reactivate workflow and administrative audit history
- Global role grant/revoke operations through the Keycloak Admin API
- `UserRegistered`, `UserProfileUpdated`, `UserRoleChanged`, `UserSuspended`, and related integration events

Keycloak remains authoritative for credentials, login, sessions, password reset, email verification, and global `USER`, `MODERATOR`, and `ADMIN` roles. The User Management Service never stores passwords or issues tokens.

### Trip Planning Service

Owns trips and every permission scoped to a particular trip.

- Trip CRUD, date range, itinerary blocks, lists, places, notes, and checklists
- Costs, budget, expenses, reservations, attachments, and tripmates
- Trip-specific vehicle snapshots used for EV calculations
- Owner/editor/viewer authorization
- Revision history and rollback
- Private, unlisted, and public visibility
- Public Explore catalogue and trip search
- Share links and independent copy-to-my-trips behavior
- Route and EV-result snapshots returned by Mobility & EV

### Mobility & EV Service

Owns external location providers and the charger domain.

- Place autocomplete, search, details, nearby discovery, and geocoding
- Google Maps Platform adapter for v1 and optional Mapbox adapter
- Route geometry, distance, duration, and ETA
- EV route feasibility and recommended charging stops
- Charger discovery, PostGIS geo-queries, local cache, and geo-tile refresh
- Connector compatibility, charging time, confidence, and verification data
- Charger reviews, reports, corrections, and administrator verification
- Provider quotas, timeouts, retries, and graceful degradation

### Community Service

Owns social interactions, community media, and the in-app notification module.

- Groups, memberships, rules, flairs, and moderators
- Posts, threaded comments, votes, bookmarks, reports, and feed ranking
- Community search using PostgreSQL full-text search
- Trip attachments by `tripId`; it never writes Trip Planning data directly
- Media upload metadata and safe rendering URLs
- In-app notifications, unread counts, preferences, and mark-read operations
- Idempotent consumers for trip and user integration events

Notifications remain a module inside Community Service. There is no standalone Notification Service in v1.

### AI Planning Service

Uses Spring AI to keep the agent workflow independent from the inference provider.

- Keycloak JWT validation and AI-specific authorization
- Chat sessions, prompt versions, quotas, and usage auditing
- A bounded tool-calling agent loop
- Structured itinerary and EV-improvement proposals
- Server-side JSON-schema validation of model output
- SSE streaming to the frontend
- Calls Trip Planning and Mobility & EV through allow-listed internal APIs
- Requires explicit user confirmation before any trip change is applied

Ollama is only the inference engine in the self-hosted profile. The AI Planning Service owns orchestration and must not access another service's schema.

AI deployment profiles:

| Profile | AI location | Inference | Extra VM |
| --- | --- | --- | --- |
| Self-hosted | ML VM | Ollama with a small quantized model such as Qwen3 4B or Llama 3.2 3B | Required |
| Hosted API | Application VM | Spring AI hosted-provider adapter over HTTPS | Not required |

Switching profiles must not change `/v1/ai/**`, tool schemas, authorization, session data, or trip-action confirmation. Hosted-provider API keys remain server-side; the frontend never calls a model provider directly.

## Gateway, discovery, and configuration

Development uses `Frontend -> Spring Cloud Gateway :8080`. Production uses `Internet -> NGINX :443 -> Spring Cloud Gateway :8080`. The Spring gateway remains present in both environments and resolves explicit service IDs through Eureka.

| Public path | Spring Cloud Gateway target |
| --- | --- |
| `/v1/users/**`, `/v1/admin/users/**` | User Management Service |
| `/v1/trips/**`, `/v1/public-trips/**`, `/v1/share/**` | Trip Planning Service |
| `/v1/places/**`, `/v1/routes/**`, `/v1/geo/**`, `/v1/ev/**`, `/v1/chargers/**` | Mobility & EV Service |
| `/v1/community/**`, `/v1/groups/**`, `/v1/posts/**`, `/v1/feed/**`, `/v1/notifications/**`, `/v1/media/**` | Community Service |
| `/v1/ai/**` | AI Planning Service over the private VM network |
| `/auth/**` | Keycloak through the configured edge/auth route |

NGINX performs production TLS termination, request-size limits, basic edge rate limiting, and forwards application traffic to Spring Cloud Gateway. The gateway owns shared CORS, routing, timeouts, trace/request-ID propagation, and Eureka-aware load balancing. It does not own business authorization; each domain service validates the Keycloak JWT and enforces its own resource permissions.

Spring Cloud Config Server on port 8888 serves versioned, environment-specific non-secret configuration from a private Git repository. It starts at a fixed private address without depending on Eureka. Secrets remain in environment variables or protected mounted files. Eureka on port 8761 registers the gateway and domain services and is never exposed publicly.

Startup order is Config Server, Eureka, domain services, Spring Cloud Gateway, then NGINX. PostgreSQL, Kafka, Keycloak, and required network dependencies must already be healthy.

## Data ownership

Navio uses one PostgreSQL/PostGIS instance on the application VM. Each service receives a database role limited to its own schemas. Cross-service joins and cross-schema foreign keys are forbidden.

| Schema | Owner | Purpose |
| --- | --- | --- |
| `iam` | User Management | Profiles, preferences, vehicles, ban/audit history, role snapshots, outbox |
| `trip` | Trip Planning | Trips, itinerary modules, budgets, permissions, revisions, sharing, copy metadata, outbox |
| `ev` | Mobility & EV | Chargers, tiles, reviews, reports, suggestions, provider metadata, outbox |
| `social` | Community | Groups, memberships, posts, comments, votes, bookmarks, reports, outbox |
| `notif` | Community | Notification preferences, inbox, delivery attempts, consumed events |
| `media` | Community | Upload sessions and media asset metadata |
| `ai` | AI Planning | Prompt configurations, sessions, messages, quotas, usage, tool audit |

Keycloak uses its own database/schema and is not counted among the seven Navio application schemas.

## Kafka usage

Kafka is used only for asynchronous integration events, never for request/response flows that need an immediate result.

| Topic | Producer | Consumers | Primary purpose |
| --- | --- | --- | --- |
| `user.events.v1` | User Management | Trip, Community, Mobility & EV | Profile snapshots, suspension, and role-change propagation |
| `trip.events.v1` | Trip Planning | Community | Notifications and community-owned public-trip snapshots |
| `community.events.v1` | Community | Notification/audit module | Comment, reply, report, and score-snapshot events |
| `mobility.events.v1` | Mobility & EV | Community/admin consumers | Charger verification and material status changes |

Core operations stay synchronous:

- Login and token issuance: Keycloak/OIDC
- Trip load/save/copy: REST
- Place, route, and charger queries: REST
- AI chat and tool calls: HTTP/SSE

Producers use a transactional outbox. Consumers deduplicate by `eventId`. A single KRaft broker is sufficient for the capstone workload; ZooKeeper and Schema Registry are not deployed.

## Observability

Centralized observability is mandatory:

- Every Spring project exposes private Actuator health/readiness and Micrometer metrics.
- Services write structured JSON logs containing service, environment, request ID, trace ID, and span ID.
- W3C trace context is propagated through NGINX, Spring Cloud Gateway, REST calls, Kafka headers, and AI tool calls.
- Grafana Alloy runs on the application VM and optional ML VM, collecting logs, metrics, and sampled OpenTelemetry traces.
- Alloy exports over HTTPS to a hosted centralized observability backend with Grafana dashboards and alerts.
- Tokens, cookies, passwords, database credentials, hosted-model keys, and unnecessary personal or prompt data are redacted.

The hosted backend is required for the current 8 GB application-VM profile. Self-hosting Grafana, Loki, Prometheus, and Tempo requires a separate observability VM or upgrading the application VM to at least 16 GB.

## Deployment constraints

### Application VM

- Ubuntu Server 24.04
- 4 vCPU, 8 GB RAM, 60 GB storage
- Runs four domain services plus Spring Cloud Gateway, Config Server, Eureka, Next.js, NGINX, Keycloak, PostgreSQL/PostGIS, Kafka, and Grafana Alloy
- Uses explicit JVM/container memory limits; this is a tight capstone deployment
- Non-secret configuration comes from Config Server; secrets come from environment variables or mounted secret files
- No Redis, Elasticsearch, MinIO, or self-hosted full observability backend
- Builds run in CI or on a development machine; the VM receives production artifacts
- Logs are rotated and uploads are capped or stored externally

### Machine-learning VM

- Required only for the self-hosted Ollama profile
- Ubuntu Server 24.04
- 8 vCPU, 8 GB RAM, 80 GB storage, no GPU
- Runs AI Planning Service and Ollama
- Ollama binds only to loopback
- One small quantized model is loaded at a time
- One active generation is allowed initially
- AI failure does not affect core planning, mobility, community, or authentication
- Grafana Alloy ships ML-service and Ollama telemetry to the same centralized backend

### Hosted-provider alternative

- Run AI Planning :8085 on the application VM
- Configure a supported hosted `ChatModel`/`StreamingChatModel` through Spring AI
- Do not provision the ML VM or Ollama
- Enforce provider cost quotas, timeouts, data-minimization, and circuit breakers
- Preserve the same public AI API and server-owned tool registry
- Upgrade the application VM to 16 GB before sustained production use; the mandatory platform applications leave little safe headroom on 8 GB

## Technology

| Layer | Technology |
| --- | --- |
| Frontend | Next.js 16, React 19, TypeScript |
| Backend | Java 21+, Spring Boot 3 |
| Authentication | Keycloak OIDC/OAuth2 |
| API gateway | Spring Cloud Gateway + Spring Cloud LoadBalancer |
| Production edge | NGINX |
| Configuration | Spring Cloud Config Server backed by private Git |
| Service discovery | Eureka |
| Database | PostgreSQL 16 + PostGIS |
| Messaging | Kafka, single KRaft broker |
| Maps and places | Google Maps Platform; Mapbox adapter optional |
| AI integration | Spring AI with Ollama or a hosted model provider |
| Caching | Caffeine in-process caches |
| Search | PostgreSQL `tsvector` and `pg_trgm` |
| Migrations | Flyway |
| Resilience | Resilience4j |
| Observability | Actuator, Micrometer, OpenTelemetry, Grafana Alloy, hosted centralized backend |

## Repository structure

```text
Navio/
├── client/                              # Next.js frontend submodule
├── server/                              # Backend umbrella submodule
│   ├── user-management-service/         # Spring Boot :8081
│   ├── trip-planning-service/           # Spring Boot :8082
│   ├── mobility-service/                # Spring Boot :8083
│   ├── community-service/               # Spring Boot :8084
│   ├── ai-planning-service/             # Spring Boot :8085; selected AI profile
│   └── platform/
│       ├── api-gateway/                  # Spring Cloud Gateway :8080
│       ├── configuration-server/         # Spring Cloud Config :8888
│       └── discovery-server/             # Eureka :8761
├── config-repository/                    # Private/non-secret environment configuration
├── observability/                        # Alloy collection and dashboard definitions
├── docs/
│   ├── api/
│   ├── database/
│   └── summary/
├── docker-compose.yml                   # Local development infrastructure
└── README.md
```

## Getting started

### Prerequisites

- Git 2.13+
- Docker with the Compose v2 plugin
- Java 21+
- Node.js 20+
- PostgreSQL 16 with PostGIS for non-container development

```bash
git clone --recurse-submodules https://github.com/bestprappy/Navio.git
cd Navio
```

If the repository was cloned without submodules:

```bash
git submodule update --init --recursive
```

### Local infrastructure

The root Compose file provides local PostgreSQL, Keycloak, Kafka, and observability infrastructure. Kafka runs in KRaft mode without ZooKeeper, using one combined broker/controller node suitable for local development and the non-HA capstone deployment profile.

```bash
docker compose up -d postgres keycloak kafka
docker compose ps
docker compose exec kafka kafka-metadata-quorum --bootstrap-server localhost:9092 describe --status
```

Kafka clients use different bootstrap addresses depending on where they run:

| Client location | Bootstrap server |
| --- | --- |
| Spring service running on the host | `localhost:29092` |
| Container on `navio-network` | `kafka:9092` |

Kafka metadata and topic data persist in the `kafka-data` Docker volume. `KAFKA_CLUSTER_ID` may override the development default, but it must remain unchanged for the lifetime of that volume. Existing ZooKeeper-mode clusters are not converted by simply reusing their data directory; migrate valuable clusters with a supported ZooKeeper-to-KRaft bridge release before upgrading to Kafka 4.x or Confluent Platform 8.x.

The container settings follow Confluent's [KRaft Docker configuration reference](https://docs.confluent.io/platform/current/installation/docker/config-reference.html). Apache Kafka 4.x operates without ZooKeeper; see the [Kafka 4.0 release announcement](https://kafka.apache.org/blog/2025/03/18/apache-kafka-4.0.0-release-announcement/).

The Compose file still does not instantiate the mandatory Gateway, Config Server, Eureka, or domain-service containers. Those Spring applications currently run from their Maven projects. The target development stack calls Spring Cloud Gateway directly; production adds NGINX in front while preserving the same gateway routes.

## Implementation order

| Phase | Deliverable |
| ---: | --- |
| 0 | Private network, PostgreSQL/PostGIS, Kafka, Keycloak, and deployment secrets |
| 1 | Config Server, Eureka, Spring Cloud Gateway, and NGINX production edge |
| 2 | Grafana Alloy, structured logs, metrics, traces, dashboards, and alerts |
| 3 | User Management and Keycloak integration |
| 4 | Trip Planning core, permissions, public Explore, sharing, and copy |
| 5 | Mobility & EV provider adapters, routing, charger cache, and EV calculations |
| 6 | Community, media, search, and in-app notifications |
| 7 | Cross-service outbox events and operational hardening |
| 8 | AI Planning Service with the selected Ollama or hosted-provider profile |

## Documentation

- [Architecture](docs/summary/Navio%20Architecture.md)
- [API documentation](docs/api/Navio%20Api%20Documentation.md)
- [OpenAPI specification](docs/api/Navio%20Open%20API.yaml)
- [Database design](docs/database/Navio%20Database.md)
