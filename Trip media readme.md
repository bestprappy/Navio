# Trip & Media Service

> **The core service in the Navio platform** — owns trip planning, identity & access management (IAM), and media processing. Runs on port **8081**.

This is the largest and most critical service in the Navio ecosystem. It consolidates three domain modules into a single JVM to minimize resource usage and eliminate network overhead for latency-sensitive operations like ACL checks.

---

## Modules

| Module          | Postgres Schema | Description                                                             |
| --------------- | --------------- | ----------------------------------------------------------------------- |
| **Trip Engine** | `trip`          | Trip CRUD, JSONB stops/routes, revisions, visibility, sharing, forking  |
| **IAM**         | `iam`           | User profiles, roles, bans, ACL engine, audit logging, event publishing |
| **Media**       | `media`         | Pre-signed uploads, MIME validation, thumbnail generation, safe URLs    |

---

## IAM Module (Identity & Access Management)

IAM is the **authorization backbone** of the entire Navio platform. It is embedded in this service (not standalone) so that trip ACL checks are direct Java method calls with zero network overhead.

### What IAM Does

- **User Profile Sync** — On first authenticated request, upserts Keycloak JWT claims (`sub`, `email`, `name`) into `iam.users`
- **Role Management** — Three-tier role model: `user` (default), `mod`, `admin`
- **Ban / Unban** — Moderators and admins can ban users; full ban history tracked in `iam.bans` with `banned_at` / `unbanned_at` timestamps
- **ACL Engine** — Generic resource-level access control via `iam.acl_entries`. Supports `owner`, `editor`, `viewer` permissions on any resource type (currently `trip`)
- **Audit Logging** — Every security-sensitive action is recorded in the append-only `iam.audit_log` table (bans, ACL changes, visibility transitions, moderation actions)
- **Event Publishing** — Domain events written to `iam.outbox` within the same DB transaction, then published to Kafka topic `iam.events.v1` by the embedded outbox publisher

### IAM Database Tables

```
iam.users           — Keycloak profile mirror (user_id, email, display_name, role, status, bio, preferences)
iam.bans            — Ban/unban history (ban_id, user_id, banned_by, reason, banned_at, unbanned_at)
iam.acl_entries     — Resource-level ACL (resource_type, resource_id, user_id, permission, granted_by)
iam.audit_log       — Append-only security audit trail (actor, action, resource, target, detail, ip, correlation_id)
iam.outbox          — Transactional Outbox for IAM events → Kafka
```

### IAM API Endpoints

**Public endpoints (routed through NGINX):**

```
GET    /v1/me                           → Current user profile
PATCH  /v1/me/preferences               → Update preferences (notifications, theme, locale)
POST   /v1/mod/users/{userId}/ban       → Ban user (mod/admin only)
POST   /v1/mod/users/{userId}/unban     → Unban user (mod/admin only)
```

**Internal endpoints (service-to-service, localhost only):**

```
POST   /internal/v1/users/sync          → Upsert user profile from Keycloak claims
GET    /internal/v1/users/{userId}       → Get user profile
POST   /internal/v1/acl/check           → Check permission: { resourceType, resourceId, userId, requiredPermission } → allow/deny
POST   /internal/v1/acl/grant           → Grant permission on a resource
DELETE /internal/v1/acl/revoke          → Revoke permission
GET    /internal/v1/acl/list            → List permissions on a resource
```

### IAM Events (Kafka topic: `iam.events.v1`)

| Event                   | Trigger                                    | Consumers                        |
| ----------------------- | ------------------------------------------ | -------------------------------- |
| `UserRegistered.v1`     | First-time user profile sync from Keycloak | Community (author name cache)    |
| `UserProfileUpdated.v1` | User updates profile/preferences           | Community (author name sync)     |
| `UserBanned.v1`         | Moderator bans a user                      | Community (enforce restrictions) |
| `UserUnbanned.v1`       | Moderator unbans a user                    | Community (lift restrictions)    |

### How Trip Engine Uses IAM

Since Trip Engine and IAM share the same JVM, ACL checks are **direct Java method calls** — no HTTP, no serialization, no network latency:

```
Trip CRUD request → Trip Controller → IAM ACL Service (in-process) → iam.acl_entries query → allow/deny
```

- On trip creation: automatically grants `owner` permission to the creator
- On trip access: checks `owner`, `editor`, or `viewer` permission
- On trip deletion: only `owner` permission allows deletion
- On collaborator management: owner can grant/revoke `editor` or `viewer` to other users

---

## Trip Engine Module

### Key Features

- Trip CRUD with JSONB-embedded stops, route legs, EV profile, and fork attribution
- Revision history (JSONB snapshots) with rollback capability
- Visibility transitions: `private` → `unlisted` → `public`
- Share links with optional expiry and revocation
- Forking with deep-copy and attribution chain (orphan-resilient via metadata snapshot)
- Maps provider integration for route distance/duration (Resilience4j-wrapped)
- Full-text search via `tsvector` generated columns with weighted ranking

### Trip API Endpoints

```
POST   /v1/trips                              → Create trip
GET    /v1/trips                              → List user's trips (paginated)
GET    /v1/trips/{tripId}                     → Get trip (ACL-checked)
PATCH  /v1/trips/{tripId}                     → Update trip (creates revision)
DELETE /v1/trips/{tripId}                     → Soft-delete (owner only)
GET    /v1/trips/{tripId}/revisions           → List revision history
POST   /v1/trips/{tripId}/rollback            → Rollback to a specific revision
POST   /v1/trips/{tripId}/visibility          → Change visibility
POST   /v1/trips/{tripId}/share-links         → Create share link
DELETE /v1/trips/{tripId}/share-links/{id}    → Revoke share link
GET    /v1/share/{token}                      → Resolve share link (PUBLIC, no JWT)
POST   /v1/trips/{tripId}/fork                → Fork a trip
GET    /v1/trips/{tripId}/forks               → List forks
GET    /v1/trips/{tripId}/origin              → Get fork origin
POST   /v1/trips/{tripId}/permissions         → Manage collaborators (ACL)
GET    /v1/trips/{tripId}/permissions         → List collaborators
```

---

## Media Module

### Key Features

- Pre-signed upload URL generation (MinIO / local filesystem)
- Embedded media processing worker (`@Scheduled`): MIME validation, virus scanning, thumbnail generation
- Safe rendering URL generation
- Media metadata stored in `media` schema

### Media API Endpoints

```
POST   /v1/media/upload-url       → Request pre-signed upload URL
POST   /v1/media/complete         → Signal upload complete (triggers processing)
GET    /v1/media/{mediaId}        → Get media metadata + safe URL
```

---

## Embedded Background Workers

| Worker               | Schedule    | Purpose                                                |
| -------------------- | ----------- | ------------------------------------------------------ |
| **Outbox Publisher** | Every 500ms | Polls `trip.outbox` + `iam.outbox`, publishes to Kafka |
| **Media Processor**  | Polling     | Processes uploaded files (scan, validate, thumbnail)   |
| **Outbox Cleanup**   | Periodic    | Purges published outbox rows older than 7 days         |

---

## Configuration

This service fetches configuration from **Spring Cloud Config Server** (`http://localhost:8888`) on startup.

Key config properties:

| Property                   | Source          | Description                  |
| -------------------------- | --------------- | ---------------------------- |
| `spring.datasource.url`    | Environment var | PostgreSQL connection string |
| `keycloak.issuer-uri`      | Environment var | Keycloak OIDC issuer URI     |
| `kafka.bootstrap-servers`  | Config Server   | Kafka broker address         |
| `kafka.topics.trip-events` | Config Server   | Trip events topic name       |
| `kafka.topics.iam-events`  | Config Server   | IAM events topic name        |
| `maps.provider.api-key`    | Environment var | Maps API key (secret)        |
| `minio.access-key`         | Environment var | MinIO access key (secret)    |

---

## Running Locally

```bash
# Build
./mvnw clean package -DskipTests

# Run (ensure PostgreSQL, Kafka, Keycloak, Config Server are running)
java -Xmx256m -jar target/*.jar
```

The service starts on port **8081** and exposes health checks at `/actuator/health`.

---

## Related Documentation

- [System Design](../../docs/Summary.md)
- [Database Design](../../docs/Database.md)
- [Implementation Guide](../../docs/Implementation.md)
