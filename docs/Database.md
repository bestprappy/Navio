# Database Design Document v1.0 — Consolidated

**Project:** TripPlanner Platform
**Based on:** System Design Doc v1.0 — Revised for 8 GB Single-VM Deployment
**Date:** 2026-02-07
**Revised:** 2026-02-12

---

## Table of Contents

1. Trip Schema (PostgreSQL)
2. IAM Schema (PostgreSQL)
3. Community & Social Schema (PostgreSQL)
4. Notification Schema (PostgreSQL)
5. Media Schema (PostgreSQL)
6. AI Orchestrator Schema (PostgreSQL)
7. EV Intelligence Schema (PostgreSQL + PostGIS)
8. Object Storage (MinIO / Local Filesystem)
9. Cross-Schema Relationship Map

---

## Architecture Note

All 7 schemas reside on a **single PostgreSQL instance** (`pg-primary`). Each service owns its schemas exclusively — **no cross-schema joins or foreign keys are permitted**, preserving microservice data isolation even on a shared instance. The PostGIS extension is enabled instance-wide for the `ev` schema's geo queries.

---

## Conventions

- All timestamps are `TIMESTAMPTZ` (UTC)
- All primary keys use `UUID` (generated as ULIDs or UUIDv7 for sortability)
- Soft deletes use a `status` column or `deleted_at` timestamp — never physical DELETE for domain entities in v1
- All tables include `created_at` (immutable) and `updated_at` (on every mutation)
- Index names follow: `idx_{table}_{columns}`
- Unique constraint names follow: `uq_{table}_{columns}`
- Foreign key names follow: `fk_{table}_{referenced_table}`
- Enum type names follow: `enum_{domain}_{name}`
- Full-text search uses `tsvector` generated columns + GIN indexes
- Geo queries use PostGIS `GEOGRAPHY(POINT, 4326)` + GIST indexes

---

## 1) Trip Schema (PostgreSQL)

**Schema:** `trip`
**Owner Service:** Trip & Media Service
**Postgres Instance:** `pg-primary` (shared)

### Types

```sql
CREATE SCHEMA IF NOT EXISTS trip;

CREATE TYPE trip.enum_visibility AS ENUM ('private', 'unlisted', 'public');
CREATE TYPE trip.enum_trip_status AS ENUM ('active', 'deleted');
```

### Table: `trip.trips`

Stores trips with embedded stops and route data as JSONB columns (replaces MongoDB document model).

```sql
CREATE TABLE trip.trips (
    trip_id         UUID                    NOT NULL DEFAULT gen_random_uuid(),
    owner_id        VARCHAR(255)            NOT NULL,   -- Keycloak 'sub' claim
    title           VARCHAR(300)            NOT NULL,
    description     TEXT,
    visibility      trip.enum_visibility    NOT NULL DEFAULT 'private',
    status          trip.enum_trip_status   NOT NULL DEFAULT 'active',

    -- Embedded document-like structures as JSONB
    stops           JSONB                   NOT NULL DEFAULT '[]',
    -- stops schema: [{ "stopId": "stop_01J...", "name": "San Francisco", "lat": 37.7749,
    --   "lng": -122.4194, "order": 0, "notes": "Start here", "arrivalDate": "2026-03-10",
    --   "departureDate": "2026-03-11", "mediaIds": ["media_01J..."], "placeId": "ChIJ..." }]

    route_legs      JSONB                   NOT NULL DEFAULT '[]',
    -- route_legs schema: [{ "fromStopId": "stop_01J...", "toStopId": "stop_02J...",
    --   "distanceKm": 120.5, "durationMin": 95, "polyline": "encoded_string",
    --   "computedAt": "2026-02-07T10:00:00Z", "available": true }]

    ev_profile      JSONB,
    -- ev_profile schema: { "batteryKwh": 75, "connectorType": "CCS2", "consumptionWhPerKm": 180 }

    tags            TEXT[]                  NOT NULL DEFAULT '{}',
    notes           TEXT,

    -- Fork attribution (null if original)
    forked_from     JSONB,
    -- forked_from schema: { "tripId": "uuid", "title": "Original Trip Title",
    --   "ownerDisplayName": "Jane Doe", "revisionId": "rev_01J..." }

    dates           JSONB,
    -- dates schema: { "startDate": "2026-03-10", "endDate": "2026-03-15" }

    stats           JSONB                   NOT NULL DEFAULT '{"totalDistanceKm": 0, "totalDurationMin": 0, "stopCount": 0, "forkCount": 0}',

    -- Full-text search vector (auto-maintained via trigger)
    search_vector   TSVECTOR,

    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT pk_trips PRIMARY KEY (trip_id)
);

-- User's trip list (paginated, newest first)
CREATE INDEX idx_trips_owner ON trip.trips (owner_id, status, updated_at DESC);

-- Public/unlisted trip queries
CREATE INDEX idx_trips_visibility ON trip.trips (visibility, status, updated_at DESC);

-- Fork lookup ("list forks of trip X")
CREATE INDEX idx_trips_forked_from ON trip.trips ((forked_from->>'tripId'))
    WHERE forked_from IS NOT NULL;

-- Tag-based queries (GIN index for array containment)
CREATE INDEX idx_trips_tags ON trip.trips USING GIN (tags)
    WHERE status = 'active';

-- Full-text search (GIN index on tsvector)
CREATE INDEX idx_trips_search ON trip.trips USING GIN (search_vector)
    WHERE status = 'active' AND visibility IN ('public', 'unlisted');

-- Cleanup soft-deleted trips
CREATE INDEX idx_trips_deleted ON trip.trips (deleted_at)
    WHERE status = 'deleted';
```

**Search vector trigger:**

```sql
-- Function to generate tsvector from trip fields
CREATE OR REPLACE FUNCTION trip.update_trip_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.notes, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(
            (SELECT string_agg(s->>'name', ' ') FROM jsonb_array_elements(NEW.stops) AS s), ''
        )), 'B') ||
        setweight(to_tsvector('english', COALESCE(array_to_string(NEW.tags, ' '), '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_trips_search_vector
BEFORE INSERT OR UPDATE OF title, description, notes, stops, tags ON trip.trips
FOR EACH ROW EXECUTE FUNCTION trip.update_trip_search_vector();
```

### Table: `trip.revisions`

Stores full trip snapshots for rollback.

```sql
CREATE TABLE trip.revisions (
    revision_id         UUID                    NOT NULL DEFAULT gen_random_uuid(),
    trip_id             UUID                    NOT NULL,
    revision_number     INTEGER                 NOT NULL,   -- monotonic counter per trip
    snapshot            JSONB                   NOT NULL,   -- full trip document at this point in time
    change_description  VARCHAR(500),                       -- optional, auto-generated or user-provided
    created_by          VARCHAR(255)            NOT NULL,
    created_at          TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_revisions PRIMARY KEY (revision_id),
    CONSTRAINT fk_revisions_trip FOREIGN KEY (trip_id) REFERENCES trip.trips(trip_id),
    CONSTRAINT uq_revisions_trip_number UNIQUE (trip_id, revision_number)
);

-- List revisions for a trip (newest first); also used for cap enforcement (keep last 100)
CREATE INDEX idx_revisions_trip ON trip.revisions (trip_id, revision_number DESC);
```

### Table: `trip.share_tokens`

```sql
CREATE TABLE trip.share_tokens (
    token_id        UUID                    NOT NULL DEFAULT gen_random_uuid(),
    trip_id         UUID                    NOT NULL,
    token           VARCHAR(64)             NOT NULL,   -- cryptographically random, URL-safe (32+ chars)
    visibility      trip.enum_visibility    NOT NULL DEFAULT 'unlisted',
    created_by      VARCHAR(255)            NOT NULL,
    expires_at      TIMESTAMPTZ,                        -- null = no expiry
    revoked_at      TIMESTAMPTZ,                        -- set on revocation
    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_share_tokens PRIMARY KEY (token_id),
    CONSTRAINT fk_share_tokens_trip FOREIGN KEY (trip_id) REFERENCES trip.trips(trip_id),
    CONSTRAINT uq_share_tokens_token UNIQUE (token)
);

-- Resolve share link (public endpoint, must be fast)
-- Covered by UNIQUE constraint index

-- List active share links for a trip
CREATE INDEX idx_share_tokens_trip ON trip.share_tokens (trip_id, revoked_at);

-- Expiry checks
CREATE INDEX idx_share_tokens_expiry ON trip.share_tokens (expires_at)
    WHERE expires_at IS NOT NULL AND revoked_at IS NULL;
```

### Table: `trip.outbox` (Transactional Outbox for Events)

```sql
CREATE TABLE trip.outbox (
    outbox_id       UUID                    NOT NULL DEFAULT gen_random_uuid(),
    event_id        VARCHAR(100)            NOT NULL,   -- ULID
    event_type      VARCHAR(100)            NOT NULL,   -- e.g., 'TripCreated.v1'
    partition_key   VARCHAR(255)            NOT NULL,   -- tripId
    payload         JSONB                   NOT NULL,
    trace_context   JSONB,
    published       BOOLEAN                 NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    published_at    TIMESTAMPTZ,

    CONSTRAINT pk_trip_outbox PRIMARY KEY (outbox_id)
);

CREATE INDEX idx_trip_outbox_unpublished ON trip.outbox (created_at)
    WHERE published = FALSE;
-- Outbox poller reads unpublished rows ordered by created_at
```

---

## 2) IAM Schema (PostgreSQL)

**Schema:** `iam`
**Owner Service:** Trip & Media Service
**Postgres Instance:** `pg-primary` (shared)

### Types

```sql
CREATE SCHEMA IF NOT EXISTS iam;

CREATE TYPE iam.enum_user_role AS ENUM ('user', 'mod', 'admin');
CREATE TYPE iam.enum_user_status AS ENUM ('active', 'banned', 'deactivated');
CREATE TYPE iam.enum_acl_permission AS ENUM ('owner', 'editor', 'viewer');
CREATE TYPE iam.enum_resource_type AS ENUM ('trip');
-- Extend enum_resource_type as new resource types need ACL
```

### Table: `iam.users`

Mirrors Keycloak user profiles with app-specific fields.

```sql
CREATE TABLE iam.users (
    user_id         VARCHAR(255)            NOT NULL,   -- Keycloak 'sub' claim (e.g., UUID)
    email           VARCHAR(320)            NOT NULL,
    display_name    VARCHAR(100)            NOT NULL,
    avatar_url      VARCHAR(2048),
    role            iam.enum_user_role      NOT NULL DEFAULT 'user',
    status          iam.enum_user_status    NOT NULL DEFAULT 'active',
    bio             TEXT,
    preferences     JSONB                   NOT NULL DEFAULT '{}',
    -- preferences schema: { "notifications": { "inApp": true, "email": false, "push": false }, "theme": "light", "locale": "en" }
    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_users PRIMARY KEY (user_id)
);

CREATE INDEX idx_users_email ON iam.users (email);
CREATE INDEX idx_users_status ON iam.users (status);
CREATE INDEX idx_users_role ON iam.users (role) WHERE role IN ('mod', 'admin');
-- Partial index: fast lookup for mod/admin users (small set)
```

### Table: `iam.bans`

Tracks ban/unban history. A user is considered banned if their latest ban record has `unbanned_at IS NULL`.

```sql
CREATE TABLE iam.bans (
    ban_id          UUID                    NOT NULL DEFAULT gen_random_uuid(),
    user_id         VARCHAR(255)            NOT NULL,
    banned_by       VARCHAR(255)            NOT NULL,   -- mod/admin user_id
    reason          TEXT                    NOT NULL,
    banned_at       TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    unbanned_at     TIMESTAMPTZ,                        -- NULL = still active
    unbanned_by     VARCHAR(255),                       -- who lifted the ban

    CONSTRAINT pk_bans PRIMARY KEY (ban_id),
    CONSTRAINT fk_bans_user FOREIGN KEY (user_id) REFERENCES iam.users(user_id),
    CONSTRAINT fk_bans_banned_by FOREIGN KEY (banned_by) REFERENCES iam.users(user_id)
);

CREATE INDEX idx_bans_user_id ON iam.bans (user_id, banned_at DESC);
CREATE INDEX idx_bans_active ON iam.bans (user_id) WHERE unbanned_at IS NULL;
-- Fast "is user currently banned?" lookup
```

### Table: `iam.acl_entries`

Generic resource-level access control. Trip & Media Service uses this for trip permissions.

```sql
CREATE TABLE iam.acl_entries (
    acl_id          UUID                    NOT NULL DEFAULT gen_random_uuid(),
    resource_type   iam.enum_resource_type  NOT NULL,
    resource_id     VARCHAR(255)            NOT NULL,   -- e.g., tripId (UUID as string)
    user_id         VARCHAR(255)            NOT NULL,
    permission      iam.enum_acl_permission NOT NULL,
    granted_by      VARCHAR(255)            NOT NULL,   -- user who granted access
    granted_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_acl_entries PRIMARY KEY (acl_id),
    CONSTRAINT fk_acl_user FOREIGN KEY (user_id) REFERENCES iam.users(user_id),
    CONSTRAINT uq_acl_resource_user UNIQUE (resource_type, resource_id, user_id)
    -- One permission entry per user per resource (upsert on grant)
);

CREATE INDEX idx_acl_resource ON iam.acl_entries (resource_type, resource_id);
-- "Who has access to this trip?"
CREATE INDEX idx_acl_user ON iam.acl_entries (user_id, resource_type);
-- "What trips does this user have access to?"
```

### Table: `iam.audit_log`

Append-only log for security-sensitive operations. Never updated or deleted.

```sql
CREATE TABLE iam.audit_log (
    log_id          UUID                    NOT NULL DEFAULT gen_random_uuid(),
    actor_user_id   VARCHAR(255)            NOT NULL,
    action          VARCHAR(100)            NOT NULL,
    -- Actions: 'user.ban', 'user.unban', 'acl.grant', 'acl.revoke',
    --          'role.change', 'trip.visibility_change', 'trip.share_link_create',
    --          'trip.share_link_revoke', 'post.mod_delete', 'comment.mod_delete'
    resource_type   VARCHAR(50),
    resource_id     VARCHAR(255),
    target_user_id  VARCHAR(255),           -- affected user (for bans, acl changes)
    detail          JSONB,                  -- action-specific payload
    ip_address      INET,
    user_agent      VARCHAR(500),
    correlation_id  VARCHAR(100),           -- request correlation ID for tracing
    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_audit_log PRIMARY KEY (log_id)
);

CREATE INDEX idx_audit_log_actor ON iam.audit_log (actor_user_id, created_at DESC);
CREATE INDEX idx_audit_log_resource ON iam.audit_log (resource_type, resource_id, created_at DESC);
CREATE INDEX idx_audit_log_target ON iam.audit_log (target_user_id, created_at DESC)
    WHERE target_user_id IS NOT NULL;
CREATE INDEX idx_audit_log_action ON iam.audit_log (action, created_at DESC);
```

### Table: `iam.outbox` (Transactional Outbox for Events)

```sql
CREATE TABLE iam.outbox (
    outbox_id       UUID                    NOT NULL DEFAULT gen_random_uuid(),
    event_id        VARCHAR(100)            NOT NULL,   -- ULID
    event_type      VARCHAR(100)            NOT NULL,   -- e.g., 'UserRegistered.v1'
    partition_key   VARCHAR(255)            NOT NULL,   -- userId
    payload         JSONB                   NOT NULL,
    trace_context   JSONB,
    published       BOOLEAN                 NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    published_at    TIMESTAMPTZ,

    CONSTRAINT pk_iam_outbox PRIMARY KEY (outbox_id)
);

CREATE INDEX idx_iam_outbox_unpublished ON iam.outbox (created_at)
    WHERE published = FALSE;
```

---

## 3) Community & Social Schema (PostgreSQL)

**Schema:** `social`
**Owner Service:** Community Service
**Postgres Instance:** `pg-primary` (shared)

### Types

```sql
CREATE SCHEMA IF NOT EXISTS social;

CREATE TYPE social.enum_post_status AS ENUM ('active', 'deleted');
CREATE TYPE social.enum_comment_status AS ENUM ('active', 'deleted');
CREATE TYPE social.enum_report_status AS ENUM ('open', 'reviewed', 'resolved', 'dismissed');
```

### Table: `social.posts`

```sql
CREATE TABLE social.posts (
    post_id             UUID                        NOT NULL DEFAULT gen_random_uuid(),
    author_user_id      VARCHAR(255)                NOT NULL,   -- Keycloak user ID
    trip_id             VARCHAR(255),                           -- trip UUID as string (nullable, FK-less cross-schema ref)
    title               VARCHAR(300)                NOT NULL,
    body                TEXT                        NOT NULL,
    tags                TEXT[]                      NOT NULL DEFAULT '{}',
    score               INTEGER                     NOT NULL DEFAULT 0,  -- denormalized: sum of vote directions
    upvote_count        INTEGER                     NOT NULL DEFAULT 0,  -- denormalized
    downvote_count      INTEGER                     NOT NULL DEFAULT 0,  -- denormalized
    comment_count       INTEGER                     NOT NULL DEFAULT 0,  -- denormalized
    bookmark_count      INTEGER                     NOT NULL DEFAULT 0,  -- denormalized
    status              social.enum_post_status     NOT NULL DEFAULT 'active',
    media_ids           TEXT[]                      NOT NULL DEFAULT '{}',  -- references to Media schema (FK-less)
    deleted_by          VARCHAR(255),               -- mod/admin who deleted (null if not deleted)
    deleted_at          TIMESTAMPTZ,

    -- Full-text search vector (auto-maintained via trigger)
    search_vector       TSVECTOR,

    created_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_posts PRIMARY KEY (post_id)
);

-- Feed: "new" sort
CREATE INDEX idx_posts_feed_new ON social.posts (created_at DESC)
    WHERE status = 'active';

-- Feed: "top" sort (within time window — app filters by created_at range)
CREATE INDEX idx_posts_feed_top ON social.posts (score DESC, created_at DESC)
    WHERE status = 'active';

-- Feed: by tag (GIN index for array containment)
CREATE INDEX idx_posts_tags ON social.posts USING GIN (tags)
    WHERE status = 'active';

-- User's own posts
CREATE INDEX idx_posts_author ON social.posts (author_user_id, created_at DESC);

-- Posts linked to a trip
CREATE INDEX idx_posts_trip ON social.posts (trip_id)
    WHERE trip_id IS NOT NULL;

-- Full-text search
CREATE INDEX idx_posts_search ON social.posts USING GIN (search_vector)
    WHERE status = 'active';
```

**Search vector trigger:**

```sql
CREATE OR REPLACE FUNCTION social.update_post_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.body, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(array_to_string(NEW.tags, ' '), '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_posts_search_vector
BEFORE INSERT OR UPDATE OF title, body, tags ON social.posts
FOR EACH ROW EXECUTE FUNCTION social.update_post_search_vector();
```

### Table: `social.comments`

Threaded comments with `parent_comment_id` for replies.

```sql
CREATE TABLE social.comments (
    comment_id          UUID                        NOT NULL DEFAULT gen_random_uuid(),
    post_id             UUID                        NOT NULL,
    parent_comment_id   UUID,                       -- NULL = top-level; non-null = reply
    author_user_id      VARCHAR(255)                NOT NULL,
    body                TEXT                        NOT NULL,
    status              social.enum_comment_status  NOT NULL DEFAULT 'active',
    depth               SMALLINT                    NOT NULL DEFAULT 0,
    -- depth: 0 = top-level, 1 = reply to top-level, 2 = reply to reply, etc.
    -- Cap depth at 3–5 in application logic to prevent infinite nesting
    deleted_by          VARCHAR(255),
    deleted_at          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_comments PRIMARY KEY (comment_id),
    CONSTRAINT fk_comments_post FOREIGN KEY (post_id) REFERENCES social.posts(post_id),
    CONSTRAINT fk_comments_parent FOREIGN KEY (parent_comment_id) REFERENCES social.comments(comment_id)
);

-- Top-level comments for a post (no parent), sorted by time
CREATE INDEX idx_comments_post_toplevel ON social.comments (post_id, created_at ASC)
    WHERE parent_comment_id IS NULL AND status = 'active';

-- Replies to a specific comment
CREATE INDEX idx_comments_parent ON social.comments (parent_comment_id, created_at ASC)
    WHERE parent_comment_id IS NOT NULL AND status = 'active';

-- User's comment history
CREATE INDEX idx_comments_author ON social.comments (author_user_id, created_at DESC);
```

### Table: `social.votes`

One vote per user per post. Direction: +1 (upvote), -1 (downvote). Retract by deleting.

```sql
CREATE TABLE social.votes (
    vote_id             UUID                        NOT NULL DEFAULT gen_random_uuid(),
    post_id             UUID                        NOT NULL,
    user_id             VARCHAR(255)                NOT NULL,
    direction           SMALLINT                    NOT NULL,
    -- direction: +1 or -1. Application enforces via CHECK.
    created_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_votes PRIMARY KEY (vote_id),
    CONSTRAINT fk_votes_post FOREIGN KEY (post_id) REFERENCES social.posts(post_id),
    CONSTRAINT uq_votes_post_user UNIQUE (post_id, user_id),
    CONSTRAINT chk_votes_direction CHECK (direction IN (-1, 1))
);

-- No additional index needed beyond the unique constraint (post_id, user_id)
```

**Vote upsert procedure** (for `PUT /v1/posts/{postId}/vote`):

```sql
-- Direction = 0 means retract (delete the vote row)
-- Direction = +1 or -1 means upsert

-- Upsert vote:
INSERT INTO social.votes (post_id, user_id, direction, updated_at)
VALUES ($1, $2, $3, NOW())
ON CONFLICT (post_id, user_id)
DO UPDATE SET direction = EXCLUDED.direction, updated_at = NOW();

-- Retract vote:
DELETE FROM social.votes WHERE post_id = $1 AND user_id = $2;

-- Then recompute denormalized score on posts table:
UPDATE social.posts
SET score = COALESCE((SELECT SUM(direction) FROM social.votes WHERE post_id = $1), 0),
    upvote_count = COALESCE((SELECT COUNT(*) FROM social.votes WHERE post_id = $1 AND direction = 1), 0),
    downvote_count = COALESCE((SELECT COUNT(*) FROM social.votes WHERE post_id = $1 AND direction = -1), 0),
    updated_at = NOW()
WHERE post_id = $1;
-- In practice, use atomic increment/decrement instead of recount for performance.
-- Recount is the safe fallback / consistency repair.
```

### Table: `social.bookmarks`

```sql
CREATE TABLE social.bookmarks (
    bookmark_id         UUID                        NOT NULL DEFAULT gen_random_uuid(),
    post_id             UUID                        NOT NULL,
    user_id             VARCHAR(255)                NOT NULL,
    created_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_bookmarks PRIMARY KEY (bookmark_id),
    CONSTRAINT fk_bookmarks_post FOREIGN KEY (post_id) REFERENCES social.posts(post_id),
    CONSTRAINT uq_bookmarks_post_user UNIQUE (post_id, user_id)
);

-- User's bookmarks list (newest first)
CREATE INDEX idx_bookmarks_user ON social.bookmarks (user_id, created_at DESC);
```

### Table: `social.reports`

```sql
CREATE TABLE social.reports (
    report_id           UUID                        NOT NULL DEFAULT gen_random_uuid(),
    post_id             UUID                        NOT NULL,
    comment_id          UUID,                       -- nullable; if set, report is about a comment
    reporter_user_id    VARCHAR(255)                NOT NULL,
    reason              TEXT                        NOT NULL,
    status              social.enum_report_status   NOT NULL DEFAULT 'open',
    reviewed_by         VARCHAR(255),               -- mod/admin who reviewed
    reviewed_at         TIMESTAMPTZ,
    resolution_notes    TEXT,
    created_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_reports PRIMARY KEY (report_id),
    CONSTRAINT fk_reports_post FOREIGN KEY (post_id) REFERENCES social.posts(post_id),
    CONSTRAINT fk_reports_comment FOREIGN KEY (comment_id) REFERENCES social.comments(comment_id)
);

-- Open reports queue for moderators
CREATE INDEX idx_reports_open ON social.reports (created_at ASC)
    WHERE status = 'open';

-- Reports by post (for checking "already reported by this user")
CREATE INDEX idx_reports_post_user ON social.reports (post_id, reporter_user_id);

-- Reports by comment
CREATE INDEX idx_reports_comment ON social.reports (comment_id)
    WHERE comment_id IS NOT NULL;
```

### Table: `social.outbox` (Transactional Outbox for Events)

```sql
CREATE TABLE social.outbox (
    outbox_id       UUID                    NOT NULL DEFAULT gen_random_uuid(),
    event_id        VARCHAR(100)            NOT NULL,
    event_type      VARCHAR(100)            NOT NULL,
    partition_key   VARCHAR(255)            NOT NULL,
    payload         JSONB                   NOT NULL,
    trace_context   JSONB,
    published       BOOLEAN                 NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    published_at    TIMESTAMPTZ,

    CONSTRAINT pk_social_outbox PRIMARY KEY (outbox_id)
);

CREATE INDEX idx_social_outbox_unpublished ON social.outbox (created_at)
    WHERE published = FALSE;
```

---

## 4) Notification Schema (PostgreSQL)

**Schema:** `notif`
**Owner Service:** Community Service
**Postgres Instance:** `pg-primary` (shared)

### Types

```sql
CREATE SCHEMA IF NOT EXISTS notif;

CREATE TYPE notif.enum_notification_type AS ENUM (
    'comment_on_post',      -- someone commented on your post
    'reply_to_comment',     -- someone replied to your comment
    'trip_forked',          -- someone forked your trip
    'post_reported',        -- (mod) a post was reported
    'user_banned',          -- you were banned
    'system_broadcast',     -- admin system message
    'trip_shared_with_you', -- someone shared a trip with you
    'moderation_action'     -- mod action on your content
);

CREATE TYPE notif.enum_delivery_channel AS ENUM ('in_app', 'email', 'push', 'sms');
CREATE TYPE notif.enum_delivery_status AS ENUM ('pending', 'sent', 'failed', 'skipped');
```

### Table: `notif.notification_preferences`

```sql
CREATE TABLE notif.notification_preferences (
    user_id             VARCHAR(255)                NOT NULL,
    in_app_enabled      BOOLEAN                     NOT NULL DEFAULT TRUE,
    email_enabled       BOOLEAN                     NOT NULL DEFAULT FALSE,
    push_enabled        BOOLEAN                     NOT NULL DEFAULT FALSE,
    sms_enabled         BOOLEAN                     NOT NULL DEFAULT FALSE,

    email_address       VARCHAR(320),               -- cached from IAM for dispatch
    push_token          VARCHAR(500),               -- FCM/APNs token
    phone_number        VARCHAR(20),                -- for SMS

    updated_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_notif_prefs PRIMARY KEY (user_id)
);
```

### Table: `notif.notifications`

In-app notification inbox.

```sql
CREATE TABLE notif.notifications (
    notification_id     UUID                            NOT NULL DEFAULT gen_random_uuid(),
    user_id             VARCHAR(255)                    NOT NULL,
    type                notif.enum_notification_type    NOT NULL,
    title               VARCHAR(300)                    NOT NULL,
    body                TEXT                            NOT NULL,
    entity_ref_type     VARCHAR(50),                    -- 'post', 'comment', 'trip', 'user'
    entity_ref_id       VARCHAR(255),                   -- ID of the referenced entity
    actor_user_id       VARCHAR(255),                   -- who triggered this (nullable for system)
    actor_display_name  VARCHAR(100),                   -- snapshot for rendering without cross-schema lookup
    read                BOOLEAN                         NOT NULL DEFAULT FALSE,
    read_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_notifications PRIMARY KEY (notification_id)
);

-- Inbox query: unread first, then by time
CREATE INDEX idx_notifications_inbox ON notif.notifications
    (user_id, read, created_at DESC);

-- Unread count (fast)
CREATE INDEX idx_notifications_unread ON notif.notifications (user_id)
    WHERE read = FALSE;

-- Retention cleanup (delete older than 90 days)
CREATE INDEX idx_notifications_created ON notif.notifications (created_at);
```

### Table: `notif.delivery_log`

Tracks external delivery attempts (email/push/SMS).

```sql
CREATE TABLE notif.delivery_log (
    delivery_id         UUID                            NOT NULL DEFAULT gen_random_uuid(),
    notification_id     UUID                            NOT NULL,
    user_id             VARCHAR(255)                    NOT NULL,
    channel             notif.enum_delivery_channel     NOT NULL,
    status              notif.enum_delivery_status      NOT NULL DEFAULT 'pending',
    provider            VARCHAR(50),                    -- 'sendgrid', 'fcm', 'twilio'
    provider_message_id VARCHAR(255),                   -- external provider reference
    error_message       TEXT,
    attempt_count       SMALLINT                        NOT NULL DEFAULT 1,
    sent_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_delivery_log PRIMARY KEY (delivery_id),
    CONSTRAINT fk_delivery_notification FOREIGN KEY (notification_id)
        REFERENCES notif.notifications(notification_id)
);

CREATE INDEX idx_delivery_notification ON notif.delivery_log (notification_id);
CREATE INDEX idx_delivery_pending ON notif.delivery_log (created_at)
    WHERE status = 'pending';
```

---

## 5) Media Schema (PostgreSQL)

**Schema:** `media`
**Owner Service:** Trip & Media Service
**Postgres Instance:** `pg-primary` (shared)

### Types

```sql
CREATE SCHEMA IF NOT EXISTS media;

CREATE TYPE media.enum_media_status AS ENUM (
    'pending',          -- upload URL issued, file not yet uploaded
    'uploaded',         -- file uploaded, awaiting processing
    'processing',       -- worker is scanning/thumbnailing
    'ready',            -- safe, thumbnails generated
    'blocked',          -- failed virus scan or validation
    'expired'           -- upload URL expired without upload
);

CREATE TYPE media.enum_media_purpose AS ENUM (
    'trip_stop',        -- image attached to a trip stop
    'post_image',       -- image in a community post
    'user_avatar',      -- user profile avatar
    'general'           -- other
);
```

### Table: `media.media`

```sql
CREATE TABLE media.media (
    media_id            UUID                            NOT NULL DEFAULT gen_random_uuid(),
    owner_user_id       VARCHAR(255)                    NOT NULL,
    purpose             media.enum_media_purpose        NOT NULL DEFAULT 'general',
    filename            VARCHAR(255)                    NOT NULL,   -- original filename
    mime_type           VARCHAR(100)                    NOT NULL,   -- e.g., 'image/jpeg'
    size_bytes          BIGINT                          NOT NULL,
    status              media.enum_media_status         NOT NULL DEFAULT 'pending',

    -- Storage paths (relative to bucket root)
    storage_bucket      VARCHAR(100)                    NOT NULL DEFAULT 'uploads',
    storage_key         VARCHAR(500)                    NOT NULL,   -- e.g., "user_2abc/2026/02/07/{media_id}/original.jpg"

    -- URLs (computed, may include CDN prefix)
    original_url        VARCHAR(2048),                  -- set after upload confirmed
    thumbnail_small_url VARCHAR(2048),                  -- 200px, set after processing
    thumbnail_medium_url VARCHAR(2048),                 -- 600px, set after processing

    -- Image metadata (set after processing)
    width               INTEGER,
    height              INTEGER,
    content_hash        VARCHAR(64),                    -- SHA-256 of file content (dedup, integrity)

    -- Processing metadata
    scan_result         VARCHAR(50),                    -- 'clean', 'malicious', 'error'
    scan_engine         VARCHAR(50),                    -- 'clamav'
    processing_error    TEXT,
    processed_at        TIMESTAMPTZ,

    -- Upload expiry
    upload_expires_at   TIMESTAMPTZ,                    -- pre-signed URL expiry

    created_at          TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_media PRIMARY KEY (media_id),
    CONSTRAINT chk_media_size CHECK (size_bytes > 0 AND size_bytes <= 10485760)
    -- 10MB max
);

-- Lookup by owner (user's uploads)
CREATE INDEX idx_media_owner ON media.media (owner_user_id, created_at DESC);

-- Processing queue (embedded worker polls for uploaded items)
CREATE INDEX idx_media_processing ON media.media (created_at)
    WHERE status = 'uploaded';

-- Cleanup expired pending uploads
CREATE INDEX idx_media_expired ON media.media (upload_expires_at)
    WHERE status = 'pending';

-- Content hash for deduplication (optional)
CREATE INDEX idx_media_hash ON media.media (content_hash)
    WHERE content_hash IS NOT NULL;
```

---

## 6) AI Orchestrator Schema (PostgreSQL)

**Schema:** `ai`
**Owner Service:** AI Orchestrator Service
**Postgres Instance:** `pg-primary` (shared)

### Table: `ai.prompt_configs`

Stores versioned prompt templates and tool schemas.

```sql
CREATE SCHEMA IF NOT EXISTS ai;

CREATE TABLE ai.prompt_configs (
    config_id           UUID                    NOT NULL DEFAULT gen_random_uuid(),
    name                VARCHAR(100)            NOT NULL,   -- e.g., 'trip_suggest', 'trip_chat'
    version             INTEGER                 NOT NULL,
    active              BOOLEAN                 NOT NULL DEFAULT FALSE,
    system_prompt       TEXT                    NOT NULL,   -- the system instruction
    tool_schemas        JSONB                   NOT NULL DEFAULT '[]',
    -- tool_schemas: array of function/tool definitions for the LLM
    -- e.g., [{ "name": "addStop", "description": "...", "parameters": { ... } }]
    model               VARCHAR(100)            NOT NULL DEFAULT 'gemini-3.0-flash',
    temperature         NUMERIC(3,2)            NOT NULL DEFAULT 0.7,
    max_tokens          INTEGER                 NOT NULL DEFAULT 4096,
    safety_settings     JSONB                   NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_prompt_configs PRIMARY KEY (config_id),
    CONSTRAINT uq_prompt_config_name_version UNIQUE (name, version)
);

-- Get active config by name
CREATE INDEX idx_prompt_configs_active ON ai.prompt_configs (name)
    WHERE active = TRUE;
```

### Table: `ai.sessions`

Conversation history for chat-with-plan.

```sql
CREATE TABLE ai.sessions (
    session_id          UUID                    NOT NULL DEFAULT gen_random_uuid(),
    user_id             VARCHAR(255)            NOT NULL,
    trip_id             VARCHAR(255)            NOT NULL,   -- trip UUID as string
    config_id           UUID,                               -- which prompt config was used
    messages            JSONB                   NOT NULL DEFAULT '[]',
    -- messages: [{ "role": "user"|"assistant"|"system", "content": "...", "timestamp": "..." }]
    -- Capped: keep last 50 messages per session in application logic
    total_prompt_tokens     INTEGER             NOT NULL DEFAULT 0,
    total_completion_tokens INTEGER             NOT NULL DEFAULT 0,
    status              VARCHAR(20)             NOT NULL DEFAULT 'active',
    -- status: 'active', 'closed', 'expired'
    created_at          TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_ai_sessions PRIMARY KEY (session_id),
    CONSTRAINT fk_ai_sessions_config FOREIGN KEY (config_id)
        REFERENCES ai.prompt_configs(config_id)
);

-- User's active session for a trip (typically one at a time)
CREATE INDEX idx_ai_sessions_user_trip ON ai.sessions (user_id, trip_id, updated_at DESC);

-- Cleanup old/expired sessions
CREATE INDEX idx_ai_sessions_status ON ai.sessions (status, updated_at)
    WHERE status = 'active';
```

### Table: `ai.usage_log`

Per-request usage tracking for cost analysis.

```sql
CREATE TABLE ai.usage_log (
    usage_id            UUID                    NOT NULL DEFAULT gen_random_uuid(),
    user_id             VARCHAR(255)            NOT NULL,
    session_id          UUID,                   -- nullable for one-shot suggest calls
    trip_id             VARCHAR(255)            NOT NULL,
    request_type        VARCHAR(30)             NOT NULL,   -- 'suggest', 'chat'
    config_id           UUID,
    model               VARCHAR(100)            NOT NULL,
    prompt_tokens       INTEGER                 NOT NULL,
    completion_tokens   INTEGER                 NOT NULL,
    total_tokens        INTEGER                 NOT NULL,
    cost_usd            NUMERIC(10,6)           NOT NULL,   -- estimated cost
    latency_ms          INTEGER,                -- response time
    status              VARCHAR(20)             NOT NULL,   -- 'success', 'error', 'timeout', 'cb_open'
    error_message       TEXT,
    created_at          TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_ai_usage_log PRIMARY KEY (usage_id)
);

-- Monthly cost reports per user
CREATE INDEX idx_ai_usage_user_month ON ai.usage_log (user_id, created_at);

-- Aggregation queries
CREATE INDEX idx_ai_usage_model ON ai.usage_log (model, created_at);
```

### Table: `ai.quota_counters`

Source of truth for per-user monthly token/cost quotas.

```sql
CREATE TABLE ai.quota_counters (
    user_id             VARCHAR(255)            NOT NULL,
    month               CHAR(7)                 NOT NULL,   -- 'YYYY-MM'
    tokens_used         BIGINT                  NOT NULL DEFAULT 0,
    cost_usd            NUMERIC(10,4)           NOT NULL DEFAULT 0.0,
    request_count       INTEGER                 NOT NULL DEFAULT 0,
    tokens_limit        BIGINT                  NOT NULL DEFAULT 100000,   -- configurable per user
    cost_limit_usd      NUMERIC(10,4)           NOT NULL DEFAULT 10.00,   -- configurable per user
    updated_at          TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_ai_quota PRIMARY KEY (user_id, month)
);

-- No additional indexes needed — PK covers the primary lookup pattern
```

**Atomic quota check + increment** (used on every AI request):

```sql
-- Check and increment atomically:
UPDATE ai.quota_counters
SET tokens_used = tokens_used + $3,
    cost_usd = cost_usd + $4,
    request_count = request_count + 1,
    updated_at = NOW()
WHERE user_id = $1
  AND month = $2
  AND tokens_used + $3 <= tokens_limit
  AND cost_usd + $4 <= cost_limit_usd
RETURNING tokens_used, cost_usd;

-- If 0 rows returned → quota exceeded → reject with 429

-- If row doesn't exist yet (first request of the month):
INSERT INTO ai.quota_counters (user_id, month, tokens_used, cost_usd, request_count)
VALUES ($1, $2, $3, $4, 1)
ON CONFLICT (user_id, month) DO NOTHING;
-- Then retry the UPDATE above
```

---

## 7) EV Intelligence Schema (PostgreSQL + PostGIS)

**Schema:** `ev`
**Owner Service:** EV Intelligence Service
**Postgres Instance:** `pg-primary` (shared, with PostGIS extension)
**All data is rebuildable** — this is a durable cache populated by the EV Refresh Worker.

### Prerequisites

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA IF NOT EXISTS ev;
```

### Table: `ev.chargers`

Replaces Redis geo cache. PostGIS provides native geo queries (`ST_DWithin`, `ST_Distance`).

```sql
CREATE TABLE ev.chargers (
    charger_id          VARCHAR(255)            NOT NULL,   -- provider's unique ID
    name                VARCHAR(300)            NOT NULL,
    lat                 DOUBLE PRECISION        NOT NULL,
    lng                 DOUBLE PRECISION        NOT NULL,
    location            GEOGRAPHY(POINT, 4326)  NOT NULL,   -- PostGIS geography for geo queries

    connector_types     JSONB                   NOT NULL DEFAULT '[]',
    -- e.g., ["CCS2", "CHAdeMO"]
    max_kw              INTEGER,
    network             VARCHAR(100),           -- e.g., "Tesla Supercharger", "ChargePoint"
    operator            VARCHAR(100),
    num_ports           SMALLINT,
    status              VARCHAR(50)             NOT NULL DEFAULT 'unknown',
    -- status: 'available', 'occupied', 'offline', 'unknown'
    status_updated_at   TIMESTAMPTZ,
    address             TEXT,
    open_24h            BOOLEAN,
    pricing_info        JSONB,
    -- pricing_info: { "perKwh": 0.35, "currency": "USD" }

    -- Provider/refresh metadata
    provider            VARCHAR(50)             NOT NULL,   -- 'ocpi', 'chargepoint', 'aggregate'
    provider_id         VARCHAR(255),                       -- external provider's own ID
    tile_key            VARCHAR(50),                        -- geo-tile key: "zoom:x:y"
    stale               BOOLEAN                 NOT NULL DEFAULT FALSE,
    refreshed_at        TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ             NOT NULL,   -- when this cached entry expires

    created_at          TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_chargers PRIMARY KEY (charger_id)
);

-- Geo-proximity queries ("chargers near a point within X km")
CREATE INDEX idx_chargers_location ON ev.chargers USING GIST (location);

-- Filter by connector type (GIN for JSONB array containment)
CREATE INDEX idx_chargers_connectors ON ev.chargers USING GIN (connector_types);

-- Tile-based refresh ("all chargers in tile X")
CREATE INDEX idx_chargers_tile ON ev.chargers (tile_key, refreshed_at);

-- Stale/expired chargers (for cleanup or refresh priority)
CREATE INDEX idx_chargers_stale ON ev.chargers (stale, expires_at)
    WHERE stale = TRUE OR expires_at < NOW();

-- Network filter
CREATE INDEX idx_chargers_network ON ev.chargers (network)
    WHERE network IS NOT NULL;

-- Power filter
CREATE INDEX idx_chargers_power ON ev.chargers (max_kw DESC)
    WHERE max_kw IS NOT NULL;
```

**Example geo query** (replaces Redis `GEOSEARCH`):

```sql
-- Find chargers within 10 km of a point, filtered by connector and min power
SELECT charger_id, name, lat, lng, connector_types, max_kw, network, status,
       ST_Distance(location, ST_MakePoint($2, $1)::geography) AS distance_m,
       CASE WHEN stale THEN 'stale' WHEN expires_at < NOW() THEN 'stale' ELSE 'fresh' END AS freshness
FROM ev.chargers
WHERE ST_DWithin(location, ST_MakePoint($2, $1)::geography, $3 * 1000)  -- radius in meters
  AND connector_types @> $4::jsonb   -- e.g., '["CCS2"]'
  AND (max_kw >= $5 OR $5 IS NULL)   -- optional min power filter
ORDER BY distance_m ASC
LIMIT 50;
-- $1 = lat, $2 = lng, $3 = radiusKm, $4 = connector filter (JSONB), $5 = minKw
```

### Table: `ev.provider_metadata`

Tracks provider API state and rate limits.

```sql
CREATE TABLE ev.provider_metadata (
    provider            VARCHAR(50)             NOT NULL,
    tile_key            VARCHAR(50)             NOT NULL,
    last_refreshed_at   TIMESTAMPTZ,
    last_error          TEXT,
    consecutive_failures INTEGER                NOT NULL DEFAULT 0,
    next_refresh_at     TIMESTAMPTZ,
    created_at          TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_provider_metadata PRIMARY KEY (provider, tile_key)
);
```

### Table: `ev.outbox` (Transactional Outbox for Events)

```sql
CREATE TABLE ev.outbox (
    outbox_id       UUID                    NOT NULL DEFAULT gen_random_uuid(),
    event_id        VARCHAR(100)            NOT NULL,
    event_type      VARCHAR(100)            NOT NULL,
    partition_key   VARCHAR(255)            NOT NULL,
    payload         JSONB                   NOT NULL,
    trace_context   JSONB,
    published       BOOLEAN                 NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    published_at    TIMESTAMPTZ,

    CONSTRAINT pk_ev_outbox PRIMARY KEY (outbox_id)
);

CREATE INDEX idx_ev_outbox_unpublished ON ev.outbox (created_at)
    WHERE published = FALSE;
```

---

## 8) Object Storage (MinIO / Local Filesystem)

**Owner Service:** Trip & Media Service
**Not a database**, but structured for completeness.

### Bucket Structure

```
uploads/
  └── {user_id}/
        └── {YYYY}/{MM}/{DD}/
              └── {media_id}/
                    ├── original.{ext}          # original upload
                    ├── thumb_small.{ext}        # 200px thumbnail
                    └── thumb_medium.{ext}       # 600px thumbnail

exports/                                        # future: PDF/GPX exports
  └── {user_id}/
        └── {trip_id}/
              └── {export_id}.{format}
```

### Bucket Policies

```
uploads:
  - Private by default
  - Read access via pre-signed URLs (TTL: 1 hour) or direct serving
  - Write access via pre-signed PUT URLs (TTL: 15 minutes)

exports:
  - Private
  - Read access via pre-signed URLs only
```

---

## 9) Cross-Schema Relationship Map

No foreign keys exist across schemas. Relationships are maintained via ID references and events.

```
┌──────────────────────┐     ID ref (string)      ┌──────────────────────┐
│   IAM (iam schema)   │◄─── user_id ────────────►│ All other schemas    │
│   users.user_id      │                           │ (author, owner, etc) │
└──────────────────────┘                           └──────────────────────┘

┌──────────────────────┐     ID ref (string)      ┌──────────────────────┐
│  Trips (trip schema) │◄─── trip_id ────────────►│ social: posts.trip_id│
│  trips.trip_id       │                           │ ai: sessions.trip_id │
└──────────────────────┘                           └──────────────────────┘

┌──────────────────────┐     ID ref (string)      ┌──────────────────────┐
│Social (social schema)│◄─── post_id ────────────►│ notif: entity_ref_id │
│ posts.post_id        │                           │                      │
└──────────────────────┘                           └──────────────────────┘

┌──────────────────────┐     ID ref (string)      ┌──────────────────────┐
│ Media (media schema) │◄─── media_id ───────────►│ trip: stops.mediaIds │
│ media.media_id       │                           │ social: media_ids[]  │
└──────────────────────┘                           └──────────────────────┘

┌──────────────────────┐     ID ref (string)      ┌──────────────────────┐
│  IAM (iam schema)    │◄─── resource_id ────────►│ trip: trips.trip_id  │
│  acl_entries         │     (resource_type=trip)  │ (ACL references trip)│
└──────────────────────┘                           └──────────────────────┘
```

### Consistency Rules

- **user_id** is copied from Keycloak `sub` claim. Never auto-generated. Same string across all schemas.
- **trip_id**, **post_id**, **media_id**, **notification_id** are UUIDs generated by their owning service.
- **No JOINs across schemas.** Even though all schemas share one Postgres instance, cross-schema queries are **strictly forbidden** to preserve microservice data isolation. If enrichment is needed (e.g., author display name on a post), use:
  - Denormalization (snapshot at write time), or
  - API call to owning service, or
  - Event-driven sync (e.g., `UserProfileUpdated` → update denormalized name)

---

This covers every data store in the system: 7 PostgreSQL schemas (`trip`, `iam`, `social`, `notif`, `media`, `ai`, `ev` — each with full DDL, indexes, constraints, enums, and triggers), PostGIS for geo queries (replacing Redis), `tsvector` for full-text search (replacing Elasticsearch), the transactional outbox pattern (replacing MongoDB Change Streams), and the object storage bucket layout. The cross-schema relationship map at the end ties it all together.
