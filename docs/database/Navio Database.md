# TripPlanner + EV + Community — Professional Database Design Documentation

**Project:** TripPlanner + EV Charger Integration + Community Sharing + Trip Copying + AI Planning Assistance  
**Database:** PostgreSQL 16+ with PostGIS, `pg_trgm`, and JSONB  
**Deployment:** Single PostgreSQL instance on one 8 GB university VM  
**Architecture:** Microservices with schema-per-service isolation  
**Version:** v1.1 database design — synced with OpenAPI v1.1 trip-planning modules  
**Prepared for:** Capstone implementation  
**Date:** 2026-05-07

---

## 1. Executive Summary

This document defines the professional database design for the TripPlanner + EV + Community platform. The system uses one physical PostgreSQL instance for operational simplicity, but separates data ownership by schema. Each service owns its own schema or schemas and must not directly query or modify another service's tables.

The database supports:

- Trip planning with dates, sections/lists, saved places, itinerary days/items, notes, reservations, attachments, budget, expenses, tripmates, route legs, EV profile snapshots, visibility, revisions, rollback, share links, and copy-to-my-trips behavior.
- IAM user mirror, roles, bans, ACL permissions, and audit logs.
- Media upload metadata, validation status, safe URLs, and thumbnails.
- EV charger local database with PostGIS search, geo-tile refresh control, provider metadata, user reviews, charger comments, reports, and suggested edits.
- Community posts, threaded comments, votes, bookmarks, moderation, and full-text search.
- In-app notifications and delivery logs.
- AI planning sessions, prompt versions, usage logs, quota counters, and tool invocation logs.
- Transactional outbox tables for reliable Kafka event publishing.

The design prioritizes feasibility for a university capstone, correctness, clean service boundaries, and future scalability.

---

## 2. Database Architecture Principles

### 2.1 Physical Model

The system uses a single PostgreSQL instance:

```txt
PostgreSQL instance: pg-primary
Database name: tripplanner_ev
Extensions: pgcrypto, postgis, pg_trgm, unaccent
Schemas: trip, iam, media, ev, social, notif, ai
```

### 2.2 Service Ownership Rule

Each service owns its schemas exclusively.

| Service                 | Owned Schemas          | Main Responsibility                                                                                                                                                                             |
| ----------------------- | ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Trip & Media Service    | `trip`, `iam`, `media` | Trips, trip dates, sections/lists, saved places, itinerary items, notes, reservations, attachments, budget/expenses, tripmates, revisions, sharing, copy trip, ACL, user mirror, media metadata |
| EV Intelligence Service | `ev`                   | Chargers, charger tiles, EV reviews, comments, reports, suggestions, provider data                                                                                                              |
| Community Service       | `social`, `notif`      | Posts, comments, votes, bookmarks, moderation, notifications                                                                                                                                    |
| AI Orchestrator Service | `ai`                   | Prompt configs, AI sessions, usage logs, quota counters                                                                                                                                         |

### 2.3 Non-Negotiable Data Boundary Rules

1. No cross-schema foreign keys.
2. No cross-service joins in application code.
3. Cross-service references are stored as plain IDs only.
4. Cross-service consistency is handled through APIs and Kafka events.
5. Event publishing must use the transactional outbox pattern.
6. Consumers must be idempotent using `event_id` deduplication.
7. Soft delete is preferred for user-generated content.
8. Audit logs are mandatory for sensitive operations.

Example: `social.posts.trip_id` stores the trip ID, but it does not have a foreign key to `trip.trips(id)`.

---

## 3. PostgreSQL Extensions

Recommended extensions:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;
```

| Extension  | Purpose                                                           |
| ---------- | ----------------------------------------------------------------- |
| `pgcrypto` | UUID generation using `gen_random_uuid()`                         |
| `postgis`  | Geo search for EV chargers using `geography(Point, 4326)`         |
| `pg_trgm`  | Fast fuzzy search for charger names, post titles, and trip titles |
| `unaccent` | Better text normalization for search                              |

---

## 4. Naming and Type Standards

### 4.1 Naming Conventions

| Item               | Convention                                         | Example                             |
| ------------------ | -------------------------------------------------- | ----------------------------------- |
| Schema             | Singular domain name                               | `trip`, `ev`, `social`              |
| Table              | Plural snake_case                                  | `trips`, `charger_reviews`          |
| Primary key        | `id`                                               | `id UUID PRIMARY KEY`               |
| Foreign key column | `<entity>_id`                                      | `trip_id`, `charger_id`             |
| JSONB column       | Suffix `_jsonb` when storing complex domain object | `stops_jsonb`                       |
| Timestamp          | `*_at`                                             | `created_at`, `deleted_at`          |
| Boolean            | `is_*`, `has_*`, or explicit                       | `is_pinned`, `email_enabled`        |
| Index              | `idx_<schema>_<table>_<columns>`                   | `idx_trip_trips_owner`              |
| Unique index       | `uq_<schema>_<table>_<columns>`                    | `uq_ev_reviews_user_charger_active` |

### 4.2 Standard Column Types

| Data                    | Type                                 | Notes                                                       |
| ----------------------- | ------------------------------------ | ----------------------------------------------------------- |
| Internal IDs            | `UUID`                               | Generated by PostgreSQL or application                      |
| Event IDs               | `TEXT`                               | ULID string recommended, e.g. `evt_01J...`                  |
| User-facing text        | `VARCHAR(n)` or `TEXT`               | Use `VARCHAR` for bounded labels/titles                     |
| Money/cost              | `NUMERIC(12,4)`                      | Avoid floating point                                        |
| Coordinates             | `NUMERIC(9,6)` + PostGIS `geography` | Latitude and longitude precision is enough for this project |
| Time                    | `TIMESTAMPTZ`                        | Always timezone-aware                                       |
| Date-only trip dates    | `DATE`                               | For itinerary days                                          |
| Flexible nested objects | `JSONB`                              | Stops, route legs, EV profile, metadata                     |
| Full-text search        | `TSVECTOR`                           | Generated column where possible                             |

### 4.3 Standard Audit Columns

Most tables should include:

```sql
created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
deleted_at TIMESTAMPTZ NULL
```

Use `deleted_at` only for tables where soft delete is needed.

---

## 5. High-Level Logical ERD

This ERD shows logical relationships. Dashed relationships represent cross-service ID references without database foreign keys.

```mermaid
erDiagram
    IAM_USERS ||--o{ IAM_USER_ROLES : has
    IAM_USERS ||--o{ IAM_USER_BANS : may_have
    IAM_USERS ||--o{ IAM_ACL_ENTRIES : grants

    TRIP_TRIPS ||--o{ TRIP_SECTIONS : has
    TRIP_SECTIONS ||--o{ TRIP_PLACES : contains
    TRIP_TRIPS ||--o{ TRIP_NOTES : has
    TRIP_TRIPS ||--o{ TRIP_ITINERARY_ITEMS : schedules
    TRIP_TRIPS ||--o{ TRIP_RESERVATIONS : has
    TRIP_TRIPS ||--o{ TRIP_ATTACHMENTS : links_media
    TRIP_TRIPS ||--o{ TRIP_EXPENSES : has
    TRIP_EXPENSES ||--o{ TRIP_EXPENSE_SPLITS : splits
    TRIP_TRIPS ||--o{ TRIP_MEMBERS : has
    TRIP_TRIPS ||--o{ TRIP_REVISIONS : has
    TRIP_TRIPS ||--o{ TRIP_SHARE_LINKS : has
    TRIP_TRIPS ||--o{ TRIP_TRIP_COPIES : creates_new_trip

    MEDIA_UPLOAD_SESSIONS ||--|| MEDIA_ASSETS : completes_as

    EV_CHARGERS ||--o{ EV_CHARGER_REVIEWS : has
    EV_CHARGERS ||--o{ EV_CHARGER_COMMENTS : has
    EV_CHARGERS ||--o{ EV_CHARGER_REPORTS : has
    EV_CHARGERS ||--o{ EV_CHARGER_SUGGESTIONS : receives
    EV_CHARGER_REVIEWS ||--o{ EV_CHARGER_REVIEW_MEDIA : attaches

    SOCIAL_POSTS ||--o{ SOCIAL_COMMENTS : has
    SOCIAL_POSTS ||--o{ SOCIAL_POST_VOTES : receives
    SOCIAL_POSTS ||--o{ SOCIAL_BOOKMARKS : bookmarked_by
    SOCIAL_POSTS ||--o{ SOCIAL_REPORTS : reported_as

    NOTIF_NOTIFICATIONS ||--o{ NOTIF_DELIVERY_LOG : delivered_by

    AI_SESSIONS ||--o{ AI_MESSAGES : has
    AI_SESSIONS ||--o{ AI_USAGE_LOGS : records
    AI_SESSIONS ||--o{ AI_TOOL_INVOCATIONS : uses

    IAM_USERS -. referenced_by .- TRIP_TRIPS
    IAM_USERS -. referenced_by .- SOCIAL_POSTS
    IAM_USERS -. referenced_by .- EV_CHARGER_REVIEWS
    TRIP_TRIPS -. referenced_by .- SOCIAL_POSTS
    MEDIA_ASSETS -. referenced_by .- EV_CHARGER_REVIEW_MEDIA
```

---

## 6. Schema Catalog

| Schema   | Table                      | Purpose                                                                                                                 |
| -------- | -------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `trip`   | `trips`                    | Main trip aggregate with dates, route snapshots, EV profile, default currency, budget amount, visibility, copy metadata |
| `trip`   | `trip_sections`            | Custom trip lists/sections such as Places to Visit, Restaurants, Lodging, Activities, and custom sections               |
| `trip`   | `trip_places`              | Saved Google/manual places inside sections, including schedule date/time and ordering                                   |
| `trip`   | `trip_notes`               | Notes attached to trip, place, day, or reservation targets                                                              |
| `trip`   | `itinerary_items`          | Day-based itinerary items referencing places, reservations, notes, transport, or custom items                           |
| `trip`   | `reservations`             | Flight, lodging, rental car, restaurant, activity, and other booking records                                            |
| `trip`   | `trip_attachments`         | Links from media assets to trip targets such as reservations, expenses, notes, places, or the trip itself               |
| `trip`   | `expenses`                 | Trip expenses with category, amount, payer, date, optional place/reservation references                                 |
| `trip`   | `expense_splits`           | Per-user expense split records for group balance calculations                                                           |
| `trip`   | `trip_members`             | Tripmates for collaboration and expense splitting; synced with ACL entries                                              |
| `trip`   | `trip_revisions`           | Versioned trip snapshots for history and rollback                                                                       |
| `trip`   | `share_links`              | Public/unlisted sharing tokens                                                                                          |
| `trip`   | `trip_copies`              | Analytics/attribution log for copy-to-my-trips                                                                          |
| `trip`   | `outbox`                   | Transactional event outbox for trip events                                                                              |
| `iam`    | `users`                    | Local user profile mirror from Keycloak                                                                                 |
| `iam`    | `user_roles`               | User roles: user, mod, admin                                                                                            |
| `iam`    | `user_bans`                | Ban and moderation state                                                                                                |
| `iam`    | `acl_entries`              | Resource permissions for trips and future resources                                                                     |
| `iam`    | `audit_log`                | Security and sensitive action logs                                                                                      |
| `iam`    | `outbox`                   | Transactional event outbox for IAM events                                                                               |
| `media`  | `media_assets`             | Uploaded file metadata and processing status                                                                            |
| `media`  | `upload_sessions`          | Signed upload workflow tracking                                                                                         |
| `ev`     | `chargers`                 | Durable local charger database and provider cache                                                                       |
| `ev`     | `charger_tiles`            | Geo-tile freshness and provider refresh status                                                                          |
| `ev`     | `charger_reviews`          | One review per user per charger                                                                                         |
| `ev`     | `charger_review_media`     | Review-to-media links                                                                                                   |
| `ev`     | `charger_comments`         | Charger-specific discussion thread                                                                                      |
| `ev`     | `charger_reports`          | Reports for incorrect charger data                                                                                      |
| `ev`     | `charger_suggestions`      | Missing charger submissions and suggested edits                                                                         |
| `ev`     | `provider_request_logs`    | Provider API usage, errors, and quota observability                                                                     |
| `ev`     | `outbox`                   | Transactional event outbox for EV events                                                                                |
| `social` | `posts`                    | Community posts linked optionally to trips                                                                              |
| `social` | `comments`                 | Threaded post comments                                                                                                  |
| `social` | `post_votes`               | Upsert vote state per user per post                                                                                     |
| `social` | `bookmarks`                | User bookmarks                                                                                                          |
| `social` | `reports`                  | Community moderation reports                                                                                            |
| `social` | `outbox`                   | Transactional event outbox for community events                                                                         |
| `notif`  | `notification_preferences` | Per-user notification settings                                                                                          |
| `notif`  | `notifications`            | In-app inbox                                                                                                            |
| `notif`  | `delivery_log`             | Email/push/SMS delivery attempts                                                                                        |
| `notif`  | `consumed_events`          | Idempotent Kafka consumer deduplication                                                                                 |
| `ai`     | `prompt_configs`           | Versioned prompts and tool schemas                                                                                      |
| `ai`     | `sessions`                 | AI planning/chat sessions                                                                                               |
| `ai`     | `messages`                 | AI conversation messages                                                                                                |
| `ai`     | `usage_logs`               | Token and cost tracking                                                                                                 |
| `ai`     | `quota_counters`           | Durable quota counters per user and period                                                                              |
| `ai`     | `tool_invocations`         | AI service API/tool call logs                                                                                           |

---

# 7. `trip` Schema Design

The `trip` schema stores the main trip aggregate, detailed trip-planning modules, history, share links, copy metadata, and event outbox. OpenAPI v1.1 requires the trip workspace to support dates, sections/lists, saved places, itinerary items, notes, reservations, attachments, budgets, expenses, and tripmates.

## 7.1 `trip.trips`

### Purpose

Stores the trip aggregate root. The row owns high-level trip metadata, trip date range, default currency/budget, route snapshots, EV profile, visibility, and copy metadata. Detailed UI modules such as sections, places, notes, itinerary items, reservations, attachments, expenses, and members are stored in normalized child tables so they can be listed, reordered, updated, and deleted independently.

### Columns

| Column                            |            Type | Required | Description                                                              |
| --------------------------------- | --------------: | -------: | ------------------------------------------------------------------------ |
| `id`                              |          `UUID` |      Yes | Trip ID                                                                  |
| `owner_user_id`                   |          `UUID` |      Yes | Owner user ID; soft reference to `iam.users`                             |
| `title`                           |  `VARCHAR(160)` |      Yes | Trip title                                                               |
| `description`                     |          `TEXT` |       No | Optional trip description                                                |
| `visibility`                      |   `VARCHAR(20)` |      Yes | `private`, `unlisted`, `public`                                          |
| `status`                          |   `VARCHAR(20)` |      Yes | `active`, `archived`, `deleted`                                          |
| `start_date`                      |          `DATE` |       No | Trip start date                                                          |
| `end_date`                        |          `DATE` |       No | Trip end date                                                            |
| `timezone`                        |   `VARCHAR(64)` |       No | Trip timezone, e.g. `Asia/Bangkok`                                       |
| `cover_media_id`                  |          `UUID` |       No | Soft reference to `media.media_assets`                                   |
| `currency`                        |       `CHAR(3)` |      Yes | Default trip currency, e.g. `THB`                                        |
| `budget_amount`                   | `NUMERIC(12,2)` |       No | Optional total trip budget                                               |
| `stops_jsonb`                     |         `JSONB` |      Yes | Ordered high-level route stops or backward-compatible trip stop snapshot |
| `route_legs_jsonb`                |         `JSONB` |      Yes | Route leg snapshots                                                      |
| `route_summary_jsonb`             |         `JSONB` |      Yes | Distance, duration, polyline summary, provider metadata                  |
| `ev_profile_jsonb`                |         `JSONB` |      Yes | EV profile used for route calculation                                    |
| `metadata_jsonb`                  |         `JSONB` |      Yes | Additional extensible metadata                                           |
| `copied_from_trip_id`             |          `UUID` |       No | Source trip ID for attribution only; no FK                               |
| `copied_from_post_id`             |          `UUID` |       No | Source post ID for attribution only; no FK                               |
| `copied_from_title`               |  `VARCHAR(160)` |       No | Source title snapshot                                                    |
| `copied_from_author_display_name` |  `VARCHAR(120)` |       No | Source author display name snapshot                                      |
| `copied_at`                       |   `TIMESTAMPTZ` |       No | When this trip was copied                                                |
| `search_vector`                   |      `TSVECTOR` |      Yes | Generated search vector                                                  |
| `version`                         |        `BIGINT` |      Yes | Optimistic locking version                                               |
| `created_at`                      |   `TIMESTAMPTZ` |      Yes | Creation time                                                            |
| `updated_at`                      |   `TIMESTAMPTZ` |      Yes | Last update time                                                         |
| `deleted_at`                      |   `TIMESTAMPTZ` |       No | Soft delete marker                                                       |

### Main Rules

- Copied trips always start as `private`.
- Source trip deletion must not delete copied trips.
- `copied_from_*` fields are attribution/analytics metadata only.
- Route data may be copied as a snapshot, but the UI should allow recomputing after copy.
- `stops_jsonb`, `route_legs_jsonb`, and `ev_profile_jsonb` should be validated in service code using DTO validation.
- `start_date` and `end_date` drive itinerary day generation.
- `currency` and `budget_amount` are the authoritative trip-level budget settings.
- Detailed modules are stored in child tables and should be included in revision snapshots when meaningful changes occur.
- Reorder operations must be transactional and should update `sort_order` values in a single write operation.

### Recommended Indexes

| Index                             | Type        | Purpose                          |
| --------------------------------- | ----------- | -------------------------------- |
| `idx_trip_trips_owner_created`    | B-tree      | List current user's trips        |
| `idx_trip_trips_visibility`       | B-tree      | Public/unlisted browsing         |
| `idx_trip_trips_status`           | B-tree      | Exclude deleted/archived quickly |
| `idx_trip_trips_search`           | GIN         | Full-text search                 |
| `idx_trip_trips_title_trgm`       | GIN trigram | Fuzzy title search               |
| `idx_trip_trips_stops_jsonb`      | GIN JSONB   | Optional stop metadata search    |
| `idx_trip_trips_copied_from_trip` | B-tree      | Analytics for copied trips       |

### JSONB Shape: `stops_jsonb`

```json
[
  {
    "stopId": "stop_01JABC",
    "order": 1,
    "placeName": "Bangkok",
    "address": "Bangkok, Thailand",
    "lat": 13.7563,
    "lng": 100.5018,
    "arrivalDate": "2026-07-01",
    "departureDate": "2026-07-03",
    "notes": "Start point",
    "placeProvider": "GOOGLE_MAPS",
    "placeId": "google_place_id_here"
  }
]
```

### JSONB Shape: `route_legs_jsonb`

```json
[
  {
    "fromStopId": "stop_01JABC",
    "toStopId": "stop_01JDEF",
    "distanceMeters": 145000,
    "durationSeconds": 7800,
    "polyline": "encoded_polyline",
    "provider": "GOOGLE_MAPS",
    "computedAt": "2026-05-07T10:00:00Z"
  }
]
```

### JSONB Shape: `ev_profile_jsonb`

```json
{
  "vehicleName": "BYD Atto 3",
  "batteryKwh": 60.5,
  "usableBatteryKwh": 57.0,
  "startingSocPercent": 90,
  "minimumArrivalSocPercent": 15,
  "consumptionKwhPer100Km": 16.5,
  "connectorTypes": ["CCS2", "TYPE2"]
}
```

---

## 7.2 `trip.trip_sections`

### Purpose

Stores custom place lists/sections inside a trip. Examples: Places to Visit, Restaurants, Lodging, Activities, and user-created custom lists.

| Column         |           Type | Required | Description                                                         |
| -------------- | -------------: | -------: | ------------------------------------------------------------------- |
| `id`           |         `UUID` |      Yes | Section ID                                                          |
| `trip_id`      |         `UUID` |      Yes | FK to `trip.trips`                                                  |
| `title`        | `VARCHAR(120)` |      Yes | Section/list title                                                  |
| `section_type` |  `VARCHAR(30)` |      Yes | `PLACES_TO_VISIT`, `RESTAURANTS`, `LODGING`, `ACTIVITIES`, `CUSTOM` |
| `sort_order`   |          `INT` |      Yes | Display order inside trip                                           |
| `is_collapsed` |      `BOOLEAN` |      Yes | UI collapsed state                                                  |
| `created_at`   |  `TIMESTAMPTZ` |      Yes | Creation time                                                       |
| `updated_at`   |  `TIMESTAMPTZ` |      Yes | Last update time                                                    |
| `deleted_at`   |  `TIMESTAMPTZ` |       No | Soft delete marker                                                  |

### Rules

- Default sections may be protected by business rules.
- `PATCH /sections/reorder` updates all section `sort_order` values transactionally.
- Deleting a section should either move places to a default section or soft-delete the section and its places according to product policy.

### Recommended Indexes

- `(trip_id, sort_order)` for ordered section listing.
- Partial unique index on active `(trip_id, title)` if duplicate section names should be disallowed.

---

## 7.3 `trip.trip_places`

### Purpose

Stores saved places inside trip sections. Places can be imported from Google Places or created manually.

| Column              |           Type | Required | Description                             |
| ------------------- | -------------: | -------: | --------------------------------------- |
| `id`                |         `UUID` |      Yes | Trip place ID                           |
| `trip_id`           |         `UUID` |      Yes | FK to `trip.trips`                      |
| `section_id`        |         `UUID` |      Yes | FK to `trip.trip_sections`              |
| `provider`          |  `VARCHAR(20)` |      Yes | `GOOGLE` or `MANUAL`                    |
| `provider_place_id` | `VARCHAR(255)` |       No | Google place ID or provider ID          |
| `name`              | `VARCHAR(200)` |      Yes | Place name/title                        |
| `address`           |         `TEXT` |       No | Address text                            |
| `lat`               | `NUMERIC(9,6)` |       No | Latitude                                |
| `lng`               | `NUMERIC(9,6)` |       No | Longitude                               |
| `phone`             |  `VARCHAR(80)` |       No | Phone number                            |
| `website`           |         `TEXT` |       No | Website URL                             |
| `photo_url`         |         `TEXT` |       No | Provider/display photo URL              |
| `notes`             |         `TEXT` |       No | Place-specific notes                    |
| `planned_date`      |         `DATE` |       No | Optional scheduled date                 |
| `start_time`        |         `TIME` |       No | Optional scheduled start time           |
| `end_time`          |         `TIME` |       No | Optional scheduled end time             |
| `sort_order`        |          `INT` |      Yes | Display order inside section            |
| `metadata_jsonb`    |        `JSONB` |      Yes | Provider metadata and extensible fields |
| `created_at`        |  `TIMESTAMPTZ` |      Yes | Creation time                           |
| `updated_at`        |  `TIMESTAMPTZ` |      Yes | Last update time                        |
| `deleted_at`        |  `TIMESTAMPTZ` |       No | Soft delete marker                      |

### Rules

- `provider = GOOGLE` should include `provider_place_id` when available.
- `provider = MANUAL` requires at least a name; coordinates are optional.
- Moving a place to another section updates `section_id` and `sort_order`.
- Deleting a place should clean up or detach itinerary items, notes, attachments, and expenses that reference it.

### Recommended Indexes

- `(trip_id, section_id, sort_order)` for ordered place listing.
- `(trip_id, planned_date)` for day planning.
- Trigram index on `name` for fuzzy place lookup.
- Optional unique partial index on `(trip_id, provider, provider_place_id)` for active Google places.

---

## 7.4 `trip.trip_notes`

### Purpose

Stores notes attached to a trip, place, day, or reservation target.

| Column               |          Type | Required | Description                                                                   |
| -------------------- | ------------: | -------: | ----------------------------------------------------------------------------- |
| `id`                 |        `UUID` |      Yes | Note ID                                                                       |
| `trip_id`            |        `UUID` |      Yes | FK to `trip.trips`                                                            |
| `target_type`        | `VARCHAR(30)` |      Yes | `TRIP`, `PLACE`, `DAY`, `RESERVATION`                                         |
| `target_id`          |        `UUID` |       No | Target row ID when target is an entity; null allowed for trip-level/day notes |
| `target_date`        |        `DATE` |       No | Date target when `target_type = DAY`                                          |
| `content`            |        `TEXT` |      Yes | Note content                                                                  |
| `sort_order`         |         `INT` |      Yes | Display order for target                                                      |
| `created_by_user_id` |        `UUID` |      Yes | Soft reference to user                                                        |
| `created_at`         | `TIMESTAMPTZ` |      Yes | Creation time                                                                 |
| `updated_at`         | `TIMESTAMPTZ` |      Yes | Last update time                                                              |
| `deleted_at`         | `TIMESTAMPTZ` |       No | Soft delete marker                                                            |

### Rules

- `target_type = DAY` should use `target_date` instead of `target_id`.
- Service validation must ensure `target_id` belongs to the same trip when the target is a place or reservation.

---

## 7.5 `trip.itinerary_items`

### Purpose

Stores scheduled items for itinerary days generated from the trip date range.

| Column       |           Type | Required | Description                                           |
| ------------ | -------------: | -------: | ----------------------------------------------------- |
| `id`         |         `UUID` |      Yes | Itinerary item ID                                     |
| `trip_id`    |         `UUID` |      Yes | FK to `trip.trips`                                    |
| `date`       |         `DATE` |      Yes | Itinerary day                                         |
| `item_type`  |  `VARCHAR(30)` |      Yes | `PLACE`, `RESERVATION`, `NOTE`, `TRANSPORT`, `CUSTOM` |
| `ref_id`     |         `UUID` |       No | Referenced entity ID for place/reservation/note       |
| `title`      | `VARCHAR(200)` |      Yes | Display title                                         |
| `start_time` |         `TIME` |       No | Optional start time                                   |
| `end_time`   |         `TIME` |       No | Optional end time                                     |
| `notes`      |         `TEXT` |       No | Item notes                                            |
| `sort_order` |          `INT` |      Yes | Order within the day                                  |
| `created_at` |  `TIMESTAMPTZ` |      Yes | Creation time                                         |
| `updated_at` |  `TIMESTAMPTZ` |      Yes | Last update time                                      |
| `deleted_at` |  `TIMESTAMPTZ` |       No | Soft delete marker                                    |

### Rules

- `date` should be inside the trip date range when `start_date` and `end_date` are set.
- Reordering one day updates all item `sort_order` values for that date.
- `ref_id` is required for `PLACE`, `RESERVATION`, and `NOTE`; it can be null for `TRANSPORT` or `CUSTOM`.

---

## 7.6 `trip.reservations`

### Purpose

Stores booking records for flights, lodging, rental cars, restaurants, activities, and other reservations.

| Column                |            Type | Required | Description                                                          |
| --------------------- | --------------: | -------: | -------------------------------------------------------------------- |
| `id`                  |          `UUID` |      Yes | Reservation ID                                                       |
| `trip_id`             |          `UUID` |      Yes | FK to `trip.trips`                                                   |
| `category`            |   `VARCHAR(30)` |      Yes | `FLIGHT`, `LODGING`, `RENTAL_CAR`, `RESTAURANT`, `ACTIVITY`, `OTHER` |
| `title`               |  `VARCHAR(200)` |      Yes | Reservation title                                                    |
| `provider_name`       |  `VARCHAR(160)` |       No | Airline, hotel platform, restaurant, etc.                            |
| `confirmation_number` |  `VARCHAR(120)` |       No | Booking confirmation number; sensitive during copy/share             |
| `start_datetime`      |   `TIMESTAMPTZ` |       No | Start time                                                           |
| `end_datetime`        |   `TIMESTAMPTZ` |       No | End time                                                             |
| `location_name`       |  `VARCHAR(200)` |       No | Location display name                                                |
| `address`             |          `TEXT` |       No | Address                                                              |
| `lat`                 |  `NUMERIC(9,6)` |       No | Latitude                                                             |
| `lng`                 |  `NUMERIC(9,6)` |       No | Longitude                                                            |
| `cost_amount`         | `NUMERIC(12,2)` |       No | Reservation cost                                                     |
| `currency`            |       `CHAR(3)` |       No | Reservation currency                                                 |
| `notes`               |          `TEXT` |       No | Notes                                                                |
| `metadata_jsonb`      |         `JSONB` |      Yes | Provider/reservation details                                         |
| `created_at`          |   `TIMESTAMPTZ` |      Yes | Creation time                                                        |
| `updated_at`          |   `TIMESTAMPTZ` |      Yes | Last update time                                                     |
| `deleted_at`          |   `TIMESTAMPTZ` |       No | Soft delete marker                                                   |

### Rules

- Reservation confirmation numbers should not be copied to another user by default.
- Attachments are linked through `trip.trip_attachments`, not stored directly on reservations.

---

## 7.7 `trip.trip_attachments`

### Purpose

Links already uploaded media assets to trip targets. The actual file metadata remains in `media.media_assets`.

| Column               |           Type | Required | Description                                           |
| -------------------- | -------------: | -------: | ----------------------------------------------------- |
| `id`                 |         `UUID` |      Yes | Attachment link ID                                    |
| `trip_id`            |         `UUID` |      Yes | FK to `trip.trips`                                    |
| `media_id`           |         `UUID` |      Yes | Soft reference to `media.media_assets`                |
| `target_type`        |  `VARCHAR(30)` |      Yes | `TRIP`, `PLACE`, `RESERVATION`, `EXPENSE`, `NOTE`     |
| `target_id`          |         `UUID` |       No | Target row ID; null allowed for trip-level attachment |
| `label`              | `VARCHAR(160)` |       No | Human-readable label                                  |
| `created_by_user_id` |         `UUID` |      Yes | Soft reference to user                                |
| `created_at`         |  `TIMESTAMPTZ` |      Yes | Creation time                                         |
| `deleted_at`         |  `TIMESTAMPTZ` |       No | Soft delete marker                                    |

### Rules

- Deleting an attachment removes the link only. It does not necessarily delete the underlying media asset.
- Private attachments should not be copied blindly when copying a public/community trip.

---

## 7.8 `trip.expenses` and `trip.expense_splits`

### Purpose

Stores trip spending and per-user split records for group balances.

#### `trip.expenses`

| Column            |            Type | Required | Description                                                               |
| ----------------- | --------------: | -------: | ------------------------------------------------------------------------- |
| `id`              |          `UUID` |      Yes | Expense ID                                                                |
| `trip_id`         |          `UUID` |      Yes | FK to `trip.trips`                                                        |
| `title`           |  `VARCHAR(200)` |      Yes | Expense title                                                             |
| `category`        |   `VARCHAR(30)` |      Yes | `FLIGHT`, `LODGING`, `FOOD`, `TRANSPORT`, `ACTIVITY`, `SHOPPING`, `OTHER` |
| `amount`          | `NUMERIC(12,2)` |      Yes | Expense amount                                                            |
| `currency`        |       `CHAR(3)` |      Yes | Expense currency                                                          |
| `paid_by_user_id` |          `UUID` |      Yes | Soft reference to payer                                                   |
| `expense_date`    |          `DATE` |      Yes | Expense date                                                              |
| `place_id`        |          `UUID` |       No | Optional same-trip place reference                                        |
| `reservation_id`  |          `UUID` |       No | Optional same-trip reservation reference                                  |
| `notes`           |          `TEXT` |       No | Notes                                                                     |
| `created_at`      |   `TIMESTAMPTZ` |      Yes | Creation time                                                             |
| `updated_at`      |   `TIMESTAMPTZ` |      Yes | Last update time                                                          |
| `deleted_at`      |   `TIMESTAMPTZ` |       No | Soft delete marker                                                        |

#### `trip.expense_splits`

| Column       |            Type | Required | Description                              |
| ------------ | --------------: | -------: | ---------------------------------------- |
| `id`         |          `UUID` |      Yes | Split ID                                 |
| `expense_id` |          `UUID` |      Yes | FK to `trip.expenses`                    |
| `user_id`    |          `UUID` |      Yes | Soft reference to trip member/user       |
| `amount`     | `NUMERIC(12,2)` |      Yes | Computed or exact split amount           |
| `split_type` |   `VARCHAR(30)` |      Yes | `EQUAL`, `EXACT`, `PERCENTAGE`           |
| `percentage` |  `NUMERIC(5,2)` |       No | Percentage when split type is percentage |
| `status`     |   `VARCHAR(20)` |      Yes | `OWED`, `PAID`, `WAIVED`                 |
| `created_at` |   `TIMESTAMPTZ` |      Yes | Creation time                            |
| `updated_at` |   `TIMESTAMPTZ` |      Yes | Last update time                         |

### Rules

- `amount > 0` for expenses.
- Splits should sum to the expense amount after rounding rules.
- Balance endpoint calculates net who-owes-whom from active expenses and splits.
- Existing expenses may keep historical user references after a member is removed.

---

## 7.9 `trip.trip_members`

### Purpose

Stores tripmates for collaboration and expense splitting. This table complements `iam.acl_entries` but does not replace authorization checks.

| Column               |           Type | Required | Description                   |
| -------------------- | -------------: | -------: | ----------------------------- |
| `id`                 |         `UUID` |      Yes | Member row ID                 |
| `trip_id`            |         `UUID` |      Yes | FK to `trip.trips`            |
| `user_id`            |         `UUID` |       No | Soft reference to joined user |
| `email`              | `VARCHAR(255)` |       No | Invite email for pending user |
| `display_name`       | `VARCHAR(120)` |      Yes | Display name snapshot         |
| `role`               |  `VARCHAR(20)` |      Yes | `OWNER`, `EDITOR`, `VIEWER`   |
| `invite_status`      |  `VARCHAR(20)` |      Yes | `ACCEPTED`, `PENDING`         |
| `invited_by_user_id` |         `UUID` |       No | Inviter user ID               |
| `joined_at`          |  `TIMESTAMPTZ` |       No | Join timestamp                |
| `created_at`         |  `TIMESTAMPTZ` |      Yes | Creation time                 |
| `updated_at`         |  `TIMESTAMPTZ` |      Yes | Last update time              |
| `removed_at`         |  `TIMESTAMPTZ` |       No | Soft removal timestamp        |

### Rules

- Every trip must have one active `OWNER` member for the owner.
- Inviting a member should create or update an ACL entry with `viewer` or `editor` permission.
- Removing a member should revoke the active ACL grant but preserve historical references on expenses.

---

## 7.10 Copy Behavior for Detailed Trip Modules

When copying a public/community/shared trip, create a new private trip and deep-copy safe planning content.

| Source Data                                                           | Copy Behavior                                                                                                                                      |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Trip title, description, dates, route summary, route legs, EV profile | Copy as snapshot                                                                                                                                   |
| Sections and saved places                                             | Copy fully, preserving order                                                                                                                       |
| Itinerary items                                                       | Copy fully, remapping referenced place/note/reservation IDs where copied                                                                           |
| Notes                                                                 | Copy public/shareable notes; omit private/sensitive notes if such visibility is later added                                                        |
| Reservations                                                          | Copy sanitized reservation shell only by default; omit confirmation numbers unless explicitly marked shareable                                     |
| Attachments                                                           | Copy links only for safe/public media; do not duplicate private files blindly                                                                      |
| Budget amount and currency                                            | Copy as trip-level settings                                                                                                                        |
| Expenses and splits                                                   | Do not copy personal debt obligations by default; optionally copy estimated expenses as non-settlement planning data if the product adds that flag |
| Trip members                                                          | Do not copy accepted members/invites; new owner starts as the only member                                                                          |

---

## 7.11 `trip.trip_revisions`

### Purpose

Stores immutable snapshots of trips for revision history and rollback.

| Column               |           Type | Required | Description                                    |
| -------------------- | -------------: | -------: | ---------------------------------------------- |
| `id`                 |         `UUID` |      Yes | Revision ID                                    |
| `trip_id`            |         `UUID` |      Yes | FK to `trip.trips`                             |
| `revision_no`        |          `INT` |      Yes | Sequential revision number per trip            |
| `snapshot_jsonb`     |        `JSONB` |      Yes | Full trip snapshot at this revision            |
| `change_summary`     | `VARCHAR(255)` |       No | Human-readable change label                    |
| `created_by_user_id` |         `UUID` |      Yes | User who created revision; soft user reference |
| `is_pinned`          |      `BOOLEAN` |      Yes | Prevent cleanup for important revision         |
| `created_at`         |  `TIMESTAMPTZ` |      Yes | Revision creation time                         |

### Constraints

- `UNIQUE(trip_id, revision_no)`
- `snapshot_jsonb` must be a JSON object.

### Retention

Recommended retention for v1.0:

- Keep the latest 100 revisions per trip.
- Keep pinned revisions indefinitely.
- Optionally delete unpinned revisions older than 90 days.

---

## 7.12 `trip.share_links`

### Purpose

Stores public/unlisted share links. Only token hashes are stored, never raw tokens.

| Column               |           Type | Required | Description                   |
| -------------------- | -------------: | -------: | ----------------------------- |
| `id`                 |         `UUID` |      Yes | Share link ID                 |
| `trip_id`            |         `UUID` |      Yes | FK to `trip.trips`            |
| `token_hash`         | `VARCHAR(128)` |      Yes | Hashed share token            |
| `permission`         |  `VARCHAR(20)` |      Yes | `view` or `copy`              |
| `created_by_user_id` |         `UUID` |      Yes | Creator; soft user reference  |
| `expires_at`         |  `TIMESTAMPTZ` |       No | Optional expiry               |
| `revoked_at`         |  `TIMESTAMPTZ` |       No | Revocation time               |
| `max_uses`           |          `INT` |       No | Optional usage limit          |
| `use_count`          |          `INT` |      Yes | Number of successful resolves |
| `created_at`         |  `TIMESTAMPTZ` |      Yes | Creation time                 |

### Rules

- Raw token is shown once to the creator and never stored.
- A revoked or expired token cannot be used.
- `permission = copy` means users can copy the trip from this link.

---

## 7.13 `trip.trip_copies`

### Purpose

Stores copy-to-my-trips events for attribution and analytics. This table does not create a dependency from the copied trip back to the source trip.

| Column                       |           Type | Required | Description                                   |
| ---------------------------- | -------------: | -------: | --------------------------------------------- |
| `id`                         |         `UUID` |      Yes | Copy event ID                                 |
| `new_trip_id`                |         `UUID` |      Yes | FK to the copied trip row                     |
| `copied_by_user_id`          |         `UUID` |      Yes | User who copied the trip                      |
| `source_trip_id`             |         `UUID` |       No | Source trip ID; no FK dependency              |
| `source_post_id`             |         `UUID` |       No | Source community post ID; no FK dependency    |
| `source_title`               | `VARCHAR(160)` |       No | Source title snapshot                         |
| `source_author_display_name` | `VARCHAR(120)` |       No | Source author snapshot                        |
| `copy_context`               |  `VARCHAR(30)` |      Yes | `public_trip`, `community_post`, `share_link` |
| `created_at`                 |  `TIMESTAMPTZ` |      Yes | Copy timestamp                                |

---

## 7.14 `trip.outbox`

### Purpose

Transactional outbox for trip events.

| Column             |           Type | Required | Description                               |
| ------------------ | -------------: | -------: | ----------------------------------------- |
| `id`               |         `UUID` |      Yes | Outbox row ID                             |
| `event_id`         |         `TEXT` |      Yes | Globally unique event ID, preferably ULID |
| `event_type`       | `VARCHAR(100)` |      Yes | Example: `TripCopied.v1`                  |
| `aggregate_type`   |  `VARCHAR(50)` |      Yes | Example: `Trip`                           |
| `aggregate_id`     |         `UUID` |      Yes | Trip ID                                   |
| `partition_key`    |         `TEXT` |      Yes | Kafka partition key                       |
| `payload_jsonb`    |        `JSONB` |      Yes | Event payload                             |
| `headers_jsonb`    |        `JSONB` |      Yes | Trace/correlation metadata                |
| `published`        |      `BOOLEAN` |      Yes | Whether published to Kafka                |
| `published_at`     |  `TIMESTAMPTZ` |       No | Publish time                              |
| `publish_attempts` |          `INT` |      Yes | Retry count                               |
| `last_error`       |         `TEXT` |       No | Last publishing error                     |
| `created_at`       |  `TIMESTAMPTZ` |      Yes | Creation time                             |

---

# 8. `iam` Schema Design

The `iam` schema stores the application's local user mirror and authorization data. Keycloak remains the authentication authority, while this schema stores application-specific profile, roles, bans, ACLs, and audit logs.

## 8.1 `iam.users`

| Column              |           Type | Required | Description                       |
| ------------------- | -------------: | -------: | --------------------------------- |
| `id`                |         `UUID` |      Yes | Internal user ID                  |
| `auth_subject`      | `VARCHAR(128)` |      Yes | Keycloak subject/user ID          |
| `email`             | `VARCHAR(255)` |      Yes | User email                        |
| `display_name`      | `VARCHAR(120)` |      Yes | Display name                      |
| `avatar_media_id`   |         `UUID` |       No | Soft reference to media asset     |
| `status`            |  `VARCHAR(30)` |      Yes | `active`, `deactivated`, `banned` |
| `locale`            |  `VARCHAR(20)` |       No | Example: `en`, `th`               |
| `country_code`      |      `CHAR(2)` |       No | ISO country code                  |
| `preferences_jsonb` |        `JSONB` |      Yes | User preferences                  |
| `created_at`        |  `TIMESTAMPTZ` |      Yes | Creation time                     |
| `updated_at`        |  `TIMESTAMPTZ` |      Yes | Last update time                  |
| `deleted_at`        |  `TIMESTAMPTZ` |       No | Soft delete marker                |

### Indexes

- Unique `auth_subject`
- Unique lower-case email index
- Index on `status`

---

## 8.2 `iam.user_roles`

| Column               |          Type | Required | Description                  |
| -------------------- | ------------: | -------: | ---------------------------- |
| `user_id`            |        `UUID` |      Yes | FK to `iam.users`            |
| `role`               | `VARCHAR(30)` |      Yes | `user`, `moderator`, `admin` |
| `granted_by_user_id` |        `UUID` |       No | Who granted the role         |
| `granted_at`         | `TIMESTAMPTZ` |      Yes | Grant time                   |

Primary key: `(user_id, role)`

---

## 8.3 `iam.user_bans`

| Column              |          Type | Required | Description             |
| ------------------- | ------------: | -------: | ----------------------- |
| `id`                |        `UUID` |      Yes | Ban ID                  |
| `user_id`           |        `UUID` |      Yes | FK to `iam.users`       |
| `reason`            |        `TEXT` |      Yes | Ban reason              |
| `banned_by_user_id` |        `UUID` |      Yes | Moderator/admin user ID |
| `starts_at`         | `TIMESTAMPTZ` |      Yes | Ban start               |
| `ends_at`           | `TIMESTAMPTZ` |       No | Optional expiry         |
| `revoked_at`        | `TIMESTAMPTZ` |       No | Revocation time         |
| `created_at`        | `TIMESTAMPTZ` |      Yes | Creation time           |

### Rules

- A user is considered banned when there is an active ban where `revoked_at IS NULL` and `ends_at IS NULL OR ends_at > now()`.

---

## 8.4 `iam.acl_entries`

### Purpose

Generic resource-level permissions. Used mainly for trips.

| Column               |           Type | Required | Description                 |
| -------------------- | -------------: | -------: | --------------------------- |
| `id`                 |         `UUID` |      Yes | ACL entry ID                |
| `resource_type`      |  `VARCHAR(50)` |      Yes | Example: `trip`             |
| `resource_id`        |         `UUID` |      Yes | Resource ID                 |
| `principal_type`     |  `VARCHAR(20)` |      Yes | `user`, `role`, `public`    |
| `principal_id`       | `VARCHAR(128)` |       No | User ID or role name        |
| `permission`         |  `VARCHAR(30)` |      Yes | `viewer`, `editor`, `owner` |
| `granted_by_user_id` |         `UUID` |      Yes | Granting user ID            |
| `created_at`         |  `TIMESTAMPTZ` |      Yes | Creation time               |
| `revoked_at`         |  `TIMESTAMPTZ` |       No | Revocation time             |

### Indexes

- `(resource_type, resource_id)` for loading permissions.
- `(principal_type, principal_id)` for finding all accessible resources.
- Partial unique index for active grants.

---

## 8.5 `iam.audit_log`

### Purpose

Append-only security log for sensitive operations.

| Column           |           Type | Required | Description                        |
| ---------------- | -------------: | -------: | ---------------------------------- |
| `id`             |         `UUID` |      Yes | Audit row ID                       |
| `actor_user_id`  |         `UUID` |       No | User performing the action         |
| `action`         | `VARCHAR(100)` |      Yes | Example: `TRIP_VISIBILITY_CHANGED` |
| `resource_type`  |  `VARCHAR(50)` |       No | Resource type                      |
| `resource_id`    |         `UUID` |       No | Resource ID                        |
| `ip_address`     |         `INET` |       No | Client IP                          |
| `user_agent`     |         `TEXT` |       No | Client user agent                  |
| `before_jsonb`   |        `JSONB` |       No | Previous state                     |
| `after_jsonb`    |        `JSONB` |       No | New state                          |
| `metadata_jsonb` |        `JSONB` |      Yes | Extra context                      |
| `created_at`     |  `TIMESTAMPTZ` |      Yes | Audit time                         |

### Required Audit Events

- Trip publish/unpublish.
- Share link create/revoke.
- ACL changes.
- Ban/unban users.
- Moderator post/comment deletion.
- Admin role grant/revoke.
- AI quota override.

---

# 9. `media` Schema Design

The `media` schema stores metadata only. File bytes are stored in MinIO or the local filesystem.

## 9.1 `media.media_assets`

| Column                 |           Type | Required | Description                                                        |
| ---------------------- | -------------: | -------: | ------------------------------------------------------------------ |
| `id`                   |         `UUID` |      Yes | Media asset ID                                                     |
| `owner_user_id`        |         `UUID` |      Yes | Uploading user ID                                                  |
| `bucket`               |  `VARCHAR(80)` |      Yes | Storage bucket/container                                           |
| `object_key`           |         `TEXT` |      Yes | Object storage key                                                 |
| `original_filename`    | `VARCHAR(255)` |      Yes | Original filename                                                  |
| `mime_type`            | `VARCHAR(120)` |      Yes | Detected MIME type                                                 |
| `size_bytes`           |       `BIGINT` |      Yes | File size                                                          |
| `checksum_sha256`      |     `CHAR(64)` |       No | SHA-256 checksum                                                   |
| `status`               |  `VARCHAR(30)` |      Yes | `requested`, `uploaded`, `scanning`, `ready`, `blocked`, `deleted` |
| `visibility`           |  `VARCHAR(20)` |      Yes | `private`, `public`                                                |
| `safe_url`             |         `TEXT` |       No | Safe rendering URL                                                 |
| `thumbnail_object_key` |         `TEXT` |       No | Thumbnail storage key                                              |
| `scan_result_jsonb`    |        `JSONB` |      Yes | Virus/mime validation result                                       |
| `metadata_jsonb`       |        `JSONB` |      Yes | Image dimensions, duration, etc.                                   |
| `created_at`           |  `TIMESTAMPTZ` |      Yes | Creation time                                                      |
| `updated_at`           |  `TIMESTAMPTZ` |      Yes | Last update time                                                   |
| `deleted_at`           |  `TIMESTAMPTZ` |       No | Soft delete marker                                                 |

### Rules

- Only `status = ready` assets may be rendered publicly.
- Private media should not be copied blindly when copying a trip.
- Review photos can reference this table through soft IDs from the EV schema.

---

## 9.2 `media.upload_sessions`

| Column                  |          Type | Required | Description                                   |
| ----------------------- | ------------: | -------: | --------------------------------------------- |
| `id`                    |        `UUID` |      Yes | Upload session ID                             |
| `media_id`              |        `UUID` |      Yes | FK to `media.media_assets`                    |
| `owner_user_id`         |        `UUID` |      Yes | User creating upload                          |
| `upload_url_expires_at` | `TIMESTAMPTZ` |      Yes | Signed URL expiry                             |
| `status`                | `VARCHAR(30)` |      Yes | `issued`, `completed`, `expired`, `cancelled` |
| `created_at`            | `TIMESTAMPTZ` |      Yes | Creation time                                 |
| `completed_at`          | `TIMESTAMPTZ` |       No | Completion time                               |

---

# 10. `ev` Schema Design

The `ev` schema is one of the most important parts of this project. It stores the local durable charger database, provider refresh metadata, community charger reviews, reports, and admin verification workflow.

## 10.1 `ev.chargers`

### Purpose

Main application read source for EV charger markers and details. Google Places and other providers are refresh/discovery sources, not queried on every request.

### Columns

| Column                       |                    Type | Required | Description                                                                                                   |
| ---------------------------- | ----------------------: | -------: | ------------------------------------------------------------------------------------------------------------- |
| `id`                         |                  `UUID` |      Yes | Charger ID                                                                                                    |
| `name`                       |          `VARCHAR(200)` |      Yes | Charger/station name                                                                                          |
| `operator_name`              |          `VARCHAR(160)` |       No | Operator/network                                                                                              |
| `lat`                        |          `NUMERIC(9,6)` |      Yes | Latitude                                                                                                      |
| `lng`                        |          `NUMERIC(9,6)` |      Yes | Longitude                                                                                                     |
| `location`                   | `GEOGRAPHY(Point,4326)` |      Yes | PostGIS search point                                                                                          |
| `address`                    |                  `TEXT` |       No | Full address                                                                                                  |
| `province`                   |          `VARCHAR(100)` |       No | Province/state                                                                                                |
| `connector_types_jsonb`      |                 `JSONB` |      Yes | Connector list and capabilities                                                                               |
| `max_kw`                     |          `NUMERIC(7,2)` |       No | Maximum charging power                                                                                        |
| `total_connectors`           |                   `INT` |       No | Total connectors                                                                                              |
| `available_connectors`       |                   `INT` |       No | Available connectors if known                                                                                 |
| `price_text`                 |                  `TEXT` |       No | Human-readable pricing                                                                                        |
| `opening_hours_jsonb`        |                 `JSONB` |      Yes | Opening hours                                                                                                 |
| `source`                     |           `VARCHAR(40)` |      Yes | `GOOGLE_PLACES`, `OPENCHARGEMAP`, `ADMIN_IMPORT`, `USER_SUBMITTED`, `PARTNER_API`                             |
| `source_external_id`         |          `VARCHAR(255)` |       No | Provider external ID                                                                                          |
| `google_place_id`            |          `VARCHAR(255)` |       No | Google place ID when available                                                                                |
| `source_url`                 |                  `TEXT` |       No | Provider/source URL                                                                                           |
| `confidence_score`           |          `NUMERIC(5,2)` |      Yes | 0–100 confidence score                                                                                        |
| `verification_status`        |           `VARCHAR(40)` |      Yes | `UNVERIFIED`, `PENDING_VERIFICATION`, `GOOGLE_CACHED`, `USER_VERIFIED`, `ADMIN_VERIFIED`, `REJECTED`, `STALE` |
| `status`                     |           `VARCHAR(30)` |      Yes | `active`, `temporarily_closed`, `closed`, `unknown`                                                           |
| `rating_avg`                 |          `NUMERIC(3,2)` |      Yes | Average user rating                                                                                           |
| `rating_count`               |                   `INT` |      Yes | Number of active reviews                                                                                      |
| `report_count`               |                   `INT` |      Yes | Number of reports                                                                                             |
| `last_seen_at`               |           `TIMESTAMPTZ` |       No | Last time provider/user confirmed existence                                                                   |
| `last_provider_refreshed_at` |           `TIMESTAMPTZ` |       No | Last provider refresh time                                                                                    |
| `last_user_verified_at`      |           `TIMESTAMPTZ` |       No | Last user feedback verification time                                                                          |
| `expires_at`                 |           `TIMESTAMPTZ` |       No | Cache expiry                                                                                                  |
| `created_by_user_id`         |                  `UUID` |       No | User who submitted it, if user-submitted                                                                      |
| `metadata_jsonb`             |                 `JSONB` |      Yes | Provider raw summary, normalized extras                                                                       |
| `created_at`                 |           `TIMESTAMPTZ` |      Yes | Creation time                                                                                                 |
| `updated_at`                 |           `TIMESTAMPTZ` |      Yes | Last update time                                                                                              |
| `deleted_at`                 |           `TIMESTAMPTZ` |       No | Soft delete marker                                                                                            |

### Important Rules

- Application reads from `ev.chargers` first.
- External provider calls happen only on cache miss, stale tile, manual refresh, or low-confidence coverage.
- User-submitted records start as `PENDING_VERIFICATION`.
- Admin-created or admin-approved records should use `ADMIN_VERIFIED`.
- Provider-derived data should store `source`, `source_external_id`, `google_place_id`, `last_seen_at`, and `expires_at`.

### Indexes

| Index                                 | Type           | Purpose                          |
| ------------------------------------- | -------------- | -------------------------------- |
| `idx_ev_chargers_location`            | GiST           | Radius search using `ST_DWithin` |
| `idx_ev_chargers_source_external`     | Unique partial | Upsert provider results          |
| `idx_ev_chargers_google_place_id`     | B-tree         | Google Places upsert/dedup       |
| `idx_ev_chargers_status_verification` | B-tree         | Admin and app filtering          |
| `idx_ev_chargers_name_trgm`           | GIN trigram    | Fuzzy charger name search        |
| `idx_ev_chargers_expires_at`          | B-tree         | Stale charger refresh jobs       |

---

## 10.2 `ev.charger_tiles`

### Purpose

Tracks geo-tile refresh status to avoid repeated external API calls for nearby map loads.

| Column              |           Type | Required | Description                                                |
| ------------------- | -------------: | -------: | ---------------------------------------------------------- |
| `tile_key`          |  `VARCHAR(80)` |      Yes | Example: `tile_13_6502_3811`                               |
| `provider`          |  `VARCHAR(40)` |      Yes | Example: `GOOGLE_PLACES`                                   |
| `last_refreshed_at` |  `TIMESTAMPTZ` |       No | Last successful refresh                                    |
| `expires_at`        |  `TIMESTAMPTZ` |       No | Refresh expiry                                             |
| `charger_count`     |          `INT` |      Yes | Number of chargers discovered                              |
| `confidence_score`  | `NUMERIC(5,2)` |      Yes | Tile coverage confidence                                   |
| `refresh_status`    |  `VARCHAR(30)` |      Yes | `fresh`, `stale`, `refreshing`, `failed`, `low_confidence` |
| `last_error`        |         `TEXT` |       No | Last refresh error                                         |
| `metadata_jsonb`    |        `JSONB` |      Yes | Provider/raw request metadata                              |
| `created_at`        |  `TIMESTAMPTZ` |      Yes | Creation time                                              |
| `updated_at`        |  `TIMESTAMPTZ` |      Yes | Last update time                                           |

Primary key: `(tile_key, provider)`

---

## 10.3 `ev.charger_reviews`

### Purpose

Stores user reviews and ratings. One active review per user per charger.

| Column                |          Type | Required | Description                   |
| --------------------- | ------------: | -------: | ----------------------------- |
| `id`                  |        `UUID` |      Yes | Review ID                     |
| `charger_id`          |        `UUID` |      Yes | FK to `ev.chargers`           |
| `user_id`             |        `UUID` |      Yes | Soft reference to `iam.users` |
| `rating`              |    `SMALLINT` |      Yes | 1–5 stars                     |
| `review_text`         |        `TEXT` |       No | Review body                   |
| `visit_date`          |        `DATE` |       No | Date user visited             |
| `charging_successful` |     `BOOLEAN` |       No | Whether charging succeeded    |
| `wait_time_minutes`   |         `INT` |       No | Wait time                     |
| `connector_used`      | `VARCHAR(40)` |       No | Example: `CCS2`               |
| `created_at`          | `TIMESTAMPTZ` |      Yes | Creation time                 |
| `updated_at`          | `TIMESTAMPTZ` |      Yes | Last update time              |
| `deleted_at`          | `TIMESTAMPTZ` |       No | Soft delete marker            |

### Constraints

- `rating BETWEEN 1 AND 5`
- Partial unique index: one active review per user per charger.

### Review Aggregate Rule

After create/update/delete review:

```sql
rating_avg = AVG(active ratings)
rating_count = COUNT(active reviews)
```

For v1.0, update aggregates transactionally in service code.

---

## 10.4 `ev.charger_comments`

### Purpose

Discussion thread per charger. Supports nested replies using `parent_comment_id`.

| Column              |          Type | Required | Description                                   |
| ------------------- | ------------: | -------: | --------------------------------------------- |
| `id`                |        `UUID` |      Yes | Comment ID                                    |
| `charger_id`        |        `UUID` |      Yes | FK to `ev.chargers`                           |
| `user_id`           |        `UUID` |      Yes | Soft reference to user                        |
| `parent_comment_id` |        `UUID` |       No | Self-reference for replies                    |
| `comment_text`      |        `TEXT` |      Yes | Comment body                                  |
| `status`            | `VARCHAR(30)` |      Yes | `active`, `deleted_by_user`, `deleted_by_mod` |
| `created_at`        | `TIMESTAMPTZ` |      Yes | Creation time                                 |
| `updated_at`        | `TIMESTAMPTZ` |      Yes | Last update time                              |
| `deleted_at`        | `TIMESTAMPTZ` |       No | Soft delete marker                            |

---

## 10.5 `ev.charger_reports`

### Purpose

Stores user reports about incorrect charger data.

| Column                 |          Type | Required | Description                                                             |
| ---------------------- | ------------: | -------: | ----------------------------------------------------------------------- |
| `id`                   |        `UUID` |      Yes | Report ID                                                               |
| `charger_id`           |        `UUID` |      Yes | FK to charger                                                           |
| `user_id`              |        `UUID` |      Yes | Reporter ID                                                             |
| `report_type`          | `VARCHAR(50)` |      Yes | `wrong_location`, `closed`, `wrong_connector`, `pricing_wrong`, `other` |
| `description`          |        `TEXT` |       No | Details                                                                 |
| `status`               | `VARCHAR(30)` |      Yes | `open`, `reviewing`, `resolved`, `rejected`                             |
| `reviewed_by_admin_id` |        `UUID` |       No | Admin/mod reviewer                                                      |
| `resolution_note`      |        `TEXT` |       No | Admin decision note                                                     |
| `created_at`           | `TIMESTAMPTZ` |      Yes | Creation time                                                           |
| `reviewed_at`          | `TIMESTAMPTZ` |       No | Review time                                                             |

---

## 10.6 `ev.charger_suggestions`

### Purpose

Stores submitted missing chargers and suggested edits for existing chargers.

| Column                            |           Type | Required | Description                                                    |
| --------------------------------- | -------------: | -------: | -------------------------------------------------------------- |
| `id`                              |         `UUID` |      Yes | Suggestion ID                                                  |
| `charger_id`                      |         `UUID` |       No | Existing charger for edit; null for missing charger submission |
| `user_id`                         |         `UUID` |      Yes | Suggesting user                                                |
| `suggestion_type`                 |  `VARCHAR(30)` |      Yes | `missing_charger`, `edit_charger`                              |
| `suggested_name`                  | `VARCHAR(200)` |       No | Suggested name                                                 |
| `suggested_address`               |         `TEXT` |       No | Suggested address                                              |
| `suggested_connector_types_jsonb` |        `JSONB` |      Yes | Suggested connectors                                           |
| `suggested_max_kw`                | `NUMERIC(7,2)` |       No | Suggested max kW                                               |
| `suggested_opening_hours_jsonb`   |        `JSONB` |      Yes | Suggested opening hours                                        |
| `suggested_lat`                   | `NUMERIC(9,6)` |       No | Suggested latitude                                             |
| `suggested_lng`                   | `NUMERIC(9,6)` |       No | Suggested longitude                                            |
| `status`                          |  `VARCHAR(30)` |      Yes | `pending`, `approved`, `rejected`                              |
| `reviewed_by_admin_id`            |         `UUID` |       No | Admin/mod reviewer                                             |
| `review_note`                     |         `TEXT` |       No | Decision note                                                  |
| `created_at`                      |  `TIMESTAMPTZ` |      Yes | Creation time                                                  |
| `reviewed_at`                     |  `TIMESTAMPTZ` |       No | Review time                                                    |

### Approval Behavior

- If `suggestion_type = missing_charger`, approval creates or activates a row in `ev.chargers`.
- If `suggestion_type = edit_charger`, approval updates selected fields on `ev.chargers`.
- Approval should write `ChargerVerified.v1` or `ChargerSuggestionSubmitted.v1` to `ev.outbox` as appropriate.

---

## 10.7 `ev.provider_request_logs`

### Purpose

Tracks external provider usage and failures for cost control.

| Column          |            Type | Required | Description                                           |
| --------------- | --------------: | -------: | ----------------------------------------------------- |
| `id`            |          `UUID` |      Yes | Request log ID                                        |
| `provider`      |   `VARCHAR(40)` |      Yes | `GOOGLE_PLACES`, `OPENCHARGEMAP`, etc.                |
| `operation`     |   `VARCHAR(80)` |      Yes | `nearby_search`, `details`, `route_compute`           |
| `tile_key`      |   `VARCHAR(80)` |       No | Tile related to request                               |
| `request_hash`  |  `VARCHAR(128)` |       No | Dedup/cost analysis hash                              |
| `status`        |   `VARCHAR(30)` |      Yes | `success`, `failed`, `rate_limited`, `quota_exceeded` |
| `http_status`   |           `INT` |       No | Provider HTTP status                                  |
| `duration_ms`   |           `INT` |       No | Request duration                                      |
| `cost_units`    | `NUMERIC(10,4)` |       No | Estimated billable units                              |
| `error_message` |          `TEXT` |       No | Error summary                                         |
| `created_at`    |   `TIMESTAMPTZ` |      Yes | Request time                                          |

---

# 11. `social` Schema Design

The `social` schema stores Reddit-like community functionality: posts, comments, votes, bookmarks, reports, and outbox events.

## 11.1 `social.posts`

| Column                |           Type | Required | Description                                             |
| --------------------- | -------------: | -------: | ------------------------------------------------------- |
| `id`                  |         `UUID` |      Yes | Post ID                                                 |
| `author_user_id`      |         `UUID` |      Yes | Soft reference to `iam.users`                           |
| `trip_id`             |         `UUID` |       No | Soft reference to `trip.trips`                          |
| `title`               | `VARCHAR(180)` |      Yes | Post title                                              |
| `body`                |         `TEXT` |       No | Post content                                            |
| `post_type`           |  `VARCHAR(30)` |      Yes | `trip_share`, `general`                                 |
| `status`              |  `VARCHAR(30)` |      Yes | `active`, `hidden`, `deleted_by_user`, `deleted_by_mod` |
| `tags`                |       `TEXT[]` |      Yes | Community tags                                          |
| `trip_snapshot_jsonb` |        `JSONB` |      Yes | Small denormalized trip display snapshot                |
| `score`               |          `INT` |      Yes | Ranking score                                           |
| `upvote_count`        |          `INT` |      Yes | Upvote count                                            |
| `downvote_count`      |          `INT` |      Yes | Downvote count                                          |
| `comment_count`       |          `INT` |      Yes | Active comment count                                    |
| `bookmark_count`      |          `INT` |      Yes | Bookmark count                                          |
| `search_vector`       |     `TSVECTOR` |      Yes | Full-text search vector                                 |
| `created_at`          |  `TIMESTAMPTZ` |      Yes | Creation time                                           |
| `updated_at`          |  `TIMESTAMPTZ` |      Yes | Last update time                                        |
| `deleted_at`          |  `TIMESTAMPTZ` |       No | Soft delete marker                                      |

### Rules

- Creating a community trip post does not copy the trip.
- Copying the trip must call Trip & Media Service: `POST /v1/trips/{tripId}/copy`.
- `trip_snapshot_jsonb` is for feed display only; authoritative trip data remains in Trip & Media Service.

### Indexes

- GIN index on `search_vector`.
- GIN index on `tags`.
- B-tree index on `(status, created_at DESC)`.
- B-tree index on `(score DESC, created_at DESC)`.
- B-tree index on `trip_id`.

---

## 11.2 `social.comments`

| Column              |          Type | Required | Description                                   |
| ------------------- | ------------: | -------: | --------------------------------------------- |
| `id`                |        `UUID` |      Yes | Comment ID                                    |
| `post_id`           |        `UUID` |      Yes | FK to `social.posts`                          |
| `author_user_id`    |        `UUID` |      Yes | Soft reference to user                        |
| `parent_comment_id` |        `UUID` |       No | Self-reference for reply                      |
| `body`              |        `TEXT` |      Yes | Comment text                                  |
| `status`            | `VARCHAR(30)` |      Yes | `active`, `deleted_by_user`, `deleted_by_mod` |
| `created_at`        | `TIMESTAMPTZ` |      Yes | Creation time                                 |
| `updated_at`        | `TIMESTAMPTZ` |      Yes | Last update time                              |
| `deleted_at`        | `TIMESTAMPTZ` |       No | Soft delete marker                            |

### Indexes

- `(post_id, created_at)` for top-level comments.
- `(parent_comment_id, created_at)` for replies.

---

## 11.3 `social.post_votes`

### Purpose

Stores one vote state per user per post. Uses upsert semantics.

| Column       |          Type | Required | Description            |
| ------------ | ------------: | -------: | ---------------------- |
| `post_id`    |        `UUID` |      Yes | FK to post             |
| `user_id`    |        `UUID` |      Yes | Soft reference to user |
| `direction`  |    `SMALLINT` |      Yes | `1`, `-1`, or `0`      |
| `created_at` | `TIMESTAMPTZ` |      Yes | First vote time        |
| `updated_at` | `TIMESTAMPTZ` |      Yes | Last vote update time  |

Primary key: `(post_id, user_id)`

### Rules

- `direction = 1` means upvote.
- `direction = -1` means downvote.
- `direction = 0` means retracted vote.
- Avoid emitting a Kafka event per vote. Emit score snapshots only.

---

## 11.4 `social.bookmarks`

| Column       |          Type | Required | Description            |
| ------------ | ------------: | -------: | ---------------------- |
| `post_id`    |        `UUID` |      Yes | FK to post             |
| `user_id`    |        `UUID` |      Yes | Soft reference to user |
| `created_at` | `TIMESTAMPTZ` |      Yes | Bookmark time          |

Primary key: `(post_id, user_id)`

---

## 11.5 `social.reports`

| Column                |          Type | Required | Description                                 |
| --------------------- | ------------: | -------: | ------------------------------------------- |
| `id`                  |        `UUID` |      Yes | Report ID                                   |
| `post_id`             |        `UUID` |       No | Reported post                               |
| `comment_id`          |        `UUID` |       No | Reported comment                            |
| `reporter_user_id`    |        `UUID` |      Yes | Reporting user                              |
| `report_type`         | `VARCHAR(50)` |      Yes | `spam`, `abuse`, `unsafe`, `other`          |
| `description`         |        `TEXT` |       No | Details                                     |
| `status`              | `VARCHAR(30)` |      Yes | `open`, `reviewing`, `resolved`, `rejected` |
| `reviewed_by_user_id` |        `UUID` |       No | Moderator/admin reviewer                    |
| `resolution_note`     |        `TEXT` |       No | Decision note                               |
| `created_at`          | `TIMESTAMPTZ` |      Yes | Creation time                               |
| `reviewed_at`         | `TIMESTAMPTZ` |       No | Review time                                 |

### Constraint

Exactly one of `post_id` or `comment_id` should be present.

---

# 12. `notif` Schema Design

The `notif` schema stores the notification inbox, user notification settings, delivery logs, and consumed event deduplication.

## 12.1 `notif.notification_preferences`

| Column                 |          Type | Required | Description                         |
| ---------------------- | ------------: | -------: | ----------------------------------- |
| `user_id`              |        `UUID` |      Yes | User ID; primary key                |
| `in_app_enabled`       |     `BOOLEAN` |      Yes | In-app notification enabled         |
| `email_enabled`        |     `BOOLEAN` |      Yes | Email notification enabled          |
| `push_enabled`         |     `BOOLEAN` |      Yes | Push notification enabled           |
| `sms_enabled`          |     `BOOLEAN` |      Yes | SMS notification enabled            |
| `event_settings_jsonb` |       `JSONB` |      Yes | Fine-grained settings by event type |
| `quiet_hours_jsonb`    |       `JSONB` |      Yes | Optional quiet hours                |
| `created_at`           | `TIMESTAMPTZ` |      Yes | Creation time                       |
| `updated_at`           | `TIMESTAMPTZ` |      Yes | Last update time                    |

---

## 12.2 `notif.notifications`

| Column              |           Type | Required | Description                               |
| ------------------- | -------------: | -------: | ----------------------------------------- |
| `id`                |         `UUID` |      Yes | Notification ID                           |
| `recipient_user_id` |         `UUID` |      Yes | Recipient                                 |
| `actor_user_id`     |         `UUID` |       No | User who triggered notification           |
| `type`              |  `VARCHAR(80)` |      Yes | Example: `comment_created`, `trip_copied` |
| `title`             | `VARCHAR(180)` |      Yes | Notification title                        |
| `body`              |         `TEXT` |       No | Notification body                         |
| `resource_type`     |  `VARCHAR(50)` |       No | `trip`, `post`, `charger`, etc.           |
| `resource_id`       |         `UUID` |       No | Resource ID                               |
| `status`            |  `VARCHAR(30)` |      Yes | `unread`, `read`, `archived`              |
| `metadata_jsonb`    |        `JSONB` |      Yes | Additional action/deeplink metadata       |
| `created_at`        |  `TIMESTAMPTZ` |      Yes | Creation time                             |
| `read_at`           |  `TIMESTAMPTZ` |       No | Read time                                 |
| `expires_at`        |  `TIMESTAMPTZ` |       No | Optional retention expiry                 |

### Indexes

- `(recipient_user_id, status, created_at DESC)` for inbox.
- `(expires_at)` for cleanup.

---

## 12.3 `notif.delivery_log`

| Column             |           Type | Required | Description                            |
| ------------------ | -------------: | -------: | -------------------------------------- |
| `id`               |         `UUID` |      Yes | Delivery log ID                        |
| `notification_id`  |         `UUID` |      Yes | FK to `notif.notifications`            |
| `channel`          |  `VARCHAR(30)` |      Yes | `in_app`, `email`, `push`, `sms`       |
| `provider`         |  `VARCHAR(80)` |       No | SendGrid, FCM, Twilio, etc.            |
| `destination_hash` | `VARCHAR(128)` |       No | Hashed destination for privacy         |
| `status`           |  `VARCHAR(30)` |      Yes | `pending`, `sent`, `failed`, `skipped` |
| `attempts`         |          `INT` |      Yes | Delivery attempts                      |
| `last_error`       |         `TEXT` |       No | Last error                             |
| `sent_at`          |  `TIMESTAMPTZ` |       No | Sent time                              |
| `created_at`       |  `TIMESTAMPTZ` |      Yes | Creation time                          |

---

## 12.4 `notif.consumed_events`

### Purpose

Deduplicates Kafka events consumed by notification workers.

| Column          |           Type | Required | Description       |
| --------------- | -------------: | -------: | ----------------- |
| `event_id`      |         `TEXT` |      Yes | Kafka event ID    |
| `consumer_name` | `VARCHAR(100)` |      Yes | Consumer identity |
| `event_type`    | `VARCHAR(100)` |      Yes | Event type        |
| `processed_at`  |  `TIMESTAMPTZ` |      Yes | Processing time   |

Primary key: `(event_id, consumer_name)`

---

# 13. `ai` Schema Design

The `ai` schema stores durable state for AI planning assistance, usage tracking, and quota enforcement.

## 13.1 `ai.prompt_configs`

| Column              |           Type | Required | Description                   |
| ------------------- | -------------: | -------: | ----------------------------- |
| `id`                |         `UUID` |      Yes | Prompt config ID              |
| `name`              | `VARCHAR(100)` |      Yes | Prompt name                   |
| `version`           |          `INT` |      Yes | Prompt version                |
| `model_name`        | `VARCHAR(100)` |      Yes | LLM model, e.g. Gemini        |
| `system_prompt`     |         `TEXT` |      Yes | System prompt                 |
| `tool_schema_jsonb` |        `JSONB` |      Yes | Structured tool/action schema |
| `temperature`       | `NUMERIC(3,2)` |       No | Model temperature             |
| `is_active`         |      `BOOLEAN` |      Yes | Active version flag           |
| `created_at`        |  `TIMESTAMPTZ` |      Yes | Creation time                 |

Unique: `(name, version)`

---

## 13.2 `ai.sessions`

| Column             |          Type | Required | Description                                  |
| ------------------ | ------------: | -------: | -------------------------------------------- |
| `id`               |        `UUID` |      Yes | Session ID                                   |
| `user_id`          |        `UUID` |      Yes | User owning the session                      |
| `trip_id`          |        `UUID` |       No | Related trip ID; no FK                       |
| `prompt_config_id` |        `UUID` |       No | FK to active prompt config                   |
| `status`           | `VARCHAR(30)` |      Yes | `active`, `completed`, `failed`, `cancelled` |
| `metadata_jsonb`   |       `JSONB` |      Yes | Context snapshot metadata                    |
| `created_at`       | `TIMESTAMPTZ` |      Yes | Creation time                                |
| `updated_at`       | `TIMESTAMPTZ` |      Yes | Last update time                             |
| `closed_at`        | `TIMESTAMPTZ` |       No | Close time                                   |

---

## 13.3 `ai.messages`

| Column             |          Type | Required | Description                           |
| ------------------ | ------------: | -------: | ------------------------------------- |
| `id`               |        `UUID` |      Yes | Message ID                            |
| `session_id`       |        `UUID` |      Yes | FK to AI session                      |
| `role`             | `VARCHAR(30)` |      Yes | `user`, `assistant`, `system`, `tool` |
| `content`          |        `TEXT` |       No | Message content                       |
| `structured_jsonb` |       `JSONB` |      Yes | Structured output/actions             |
| `created_at`       | `TIMESTAMPTZ` |      Yes | Message time                          |

---

## 13.4 `ai.usage_logs`

| Column           |            Type | Required | Description                          |
| ---------------- | --------------: | -------: | ------------------------------------ |
| `id`             |          `UUID` |      Yes | Usage log ID                         |
| `session_id`     |          `UUID` |       No | Related session                      |
| `user_id`        |          `UUID` |      Yes | User ID                              |
| `model_name`     |  `VARCHAR(100)` |      Yes | LLM model                            |
| `operation`      |   `VARCHAR(80)` |      Yes | `plan_suggest`, `plan_chat`          |
| `input_tokens`   |           `INT` |      Yes | Input tokens                         |
| `output_tokens`  |           `INT` |      Yes | Output tokens                        |
| `total_tokens`   |           `INT` |      Yes | Total tokens                         |
| `estimated_cost` | `NUMERIC(12,6)` |      Yes | Estimated cost                       |
| `status`         |   `VARCHAR(30)` |      Yes | `success`, `failed`, `quota_blocked` |
| `error_message`  |          `TEXT` |       No | Error summary                        |
| `created_at`     |   `TIMESTAMPTZ` |      Yes | Usage time                           |

---

## 13.5 `ai.quota_counters`

### Purpose

Durable source of truth for AI usage limits.

| Column          |            Type | Required | Description                  |
| --------------- | --------------: | -------: | ---------------------------- |
| `user_id`       |          `UUID` |      Yes | User ID                      |
| `period_start`  |          `DATE` |      Yes | Month/day quota period start |
| `period_end`    |          `DATE` |      Yes | Period end                   |
| `tokens_used`   |        `BIGINT` |      Yes | Tokens used this period      |
| `cost_used`     | `NUMERIC(12,6)` |      Yes | Estimated cost used          |
| `request_count` |           `INT` |      Yes | Request count                |
| `updated_at`    |   `TIMESTAMPTZ` |      Yes | Last update time             |

Primary key: `(user_id, period_start, period_end)`

---

## 13.6 `ai.tool_invocations`

| Column           |           Type | Required | Description                    |
| ---------------- | -------------: | -------: | ------------------------------ |
| `id`             |         `UUID` |      Yes | Tool invocation ID             |
| `session_id`     |         `UUID` |      Yes | FK to AI session               |
| `tool_name`      | `VARCHAR(100)` |      Yes | Tool/API action name           |
| `request_jsonb`  |        `JSONB` |      Yes | Redacted request               |
| `response_jsonb` |        `JSONB` |      Yes | Redacted response              |
| `status`         |  `VARCHAR(30)` |      Yes | `success`, `failed`, `blocked` |
| `duration_ms`    |          `INT` |       No | Duration                       |
| `created_at`     |  `TIMESTAMPTZ` |      Yes | Invocation time                |

---

# 14. Outbox Pattern Standard

Every producing schema should have an `outbox` table with the same shape.

Applicable schemas:

- `trip.outbox`
- `iam.outbox`
- `ev.outbox`
- `social.outbox`

## 14.1 Outbox Write Rule

Domain write and outbox insert must happen in the same database transaction.

Example:

```txt
Copy trip transaction:
1. Insert new trip
2. Insert first trip revision
3. Insert trip_copies analytics row
4. Insert TripCopied.v1 into trip.outbox
5. Commit
```

If Kafka is down, the transaction still commits. The outbox publisher retries later.

## 14.2 Outbox Event Envelope

```json
{
  "eventId": "evt_01J...",
  "eventType": "TripCopied.v1",
  "occurredAt": "2026-05-07T10:00:00Z",
  "producer": "trip-media-service",
  "partitionKey": "trip_...",
  "trace": {
    "traceId": "...",
    "spanId": "..."
  },
  "payload": {}
}
```

## 14.3 Outbox Indexes

- Unique index on `event_id`.
- Partial index on unpublished rows: `WHERE published = false`.
- Cleanup index on `(published, published_at)`.

---

# 15. Search Strategy

## 15.1 Trip Search

Trip search uses `trip.trips.search_vector` and optional trigram search on title.

Searchable fields:

- Trip title
- Trip description
- Optional denormalized stop names if added later

Recommended search query:

```sql
SELECT *
FROM trip.trips
WHERE owner_user_id = :currentUserId
  AND deleted_at IS NULL
  AND search_vector @@ plainto_tsquery('simple', :query)
ORDER BY ts_rank(search_vector, plainto_tsquery('simple', :query)) DESC;
```

Visibility must be enforced in application logic and/or SQL filters.

## 15.2 Community Post Search

Community search uses `social.posts.search_vector`.

Searchable fields:

- Post title
- Post body
- Tags

## 15.3 Charger Search

Charger search uses two different search modes:

1. Geo search with PostGIS for nearby chargers.
2. Text search with trigram index for charger name/operator.

Example radius search:

```sql
SELECT *
FROM ev.chargers
WHERE status IN ('active', 'unknown')
  AND deleted_at IS NULL
  AND ST_DWithin(
    location,
    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
    :radiusMeters
  )
ORDER BY ST_Distance(
    location,
    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
  ) ASC
LIMIT 100;
```

---

# 16. Data Integrity Rules

## 16.1 Cross-Service References

| Table                     | Column              | References              | FK? | Reason                                        |
| ------------------------- | ------------------- | ----------------------- | --: | --------------------------------------------- |
| `trip.trips`              | `owner_user_id`     | `iam.users.id`          |  No | Avoid cross-schema FK; service code validates |
| `social.posts`            | `trip_id`           | `trip.trips.id`         |  No | Community cannot depend on Trip schema        |
| `social.posts`            | `author_user_id`    | `iam.users.id`          |  No | Soft user reference                           |
| `ev.charger_reviews`      | `user_id`           | `iam.users.id`          |  No | EV service stores soft user reference         |
| `ev.charger_review_media` | `media_id`          | `media.media_assets.id` |  No | EV cannot FK media schema                     |
| `notif.notifications`     | `recipient_user_id` | `iam.users.id`          |  No | Notification uses soft reference              |
| `ai.sessions`             | `trip_id`           | `trip.trips.id`         |  No | AI uses APIs only                             |

## 16.2 Internal Schema Foreign Keys

Foreign keys are allowed inside the same schema, for example:

- `trip.trip_revisions.trip_id -> trip.trips.id`
- `ev.charger_reviews.charger_id -> ev.chargers.id`
- `social.comments.post_id -> social.posts.id`
- `notif.delivery_log.notification_id -> notif.notifications.id`
- `ai.messages.session_id -> ai.sessions.id`

---

# 17. Retention and Cleanup Policy

| Data                      | Retention                           | Cleanup Method                |
| ------------------------- | ----------------------------------- | ----------------------------- |
| Trip revisions            | Latest 100 or 90 days, pinned kept  | Scheduled job                 |
| Published outbox rows     | 24–72 hours after publish           | Scheduled job                 |
| Notification inbox        | 90 days default                     | Scheduled job                 |
| Delivery logs             | 90–180 days                         | Scheduled job                 |
| Provider request logs     | 30–90 days                          | Scheduled job                 |
| AI usage logs             | 180 days or project policy          | Scheduled job                 |
| Audit logs                | Keep long-term                      | Do not delete unless required |
| Soft-deleted user content | 30 days before hard delete optional | Scheduled job                 |

---

# 18. Migration Strategy

Use Flyway with one migration path per service.

Recommended structure:

```txt
trip-media-service/src/main/resources/db/migration/
  V001__create_trip_schema.sql
  V002__create_iam_schema.sql
  V003__create_media_schema.sql

ev-service/src/main/resources/db/migration/
  V001__create_ev_schema.sql

community-service/src/main/resources/db/migration/
  V001__create_social_schema.sql
  V002__create_notif_schema.sql

ai-service/src/main/resources/db/migration/
  V001__create_ai_schema.sql
```

Rules:

- Use expand-contract migrations.
- Never drop or rename columns in the same deployment where code still depends on them.
- Add nullable columns first, backfill, then enforce `NOT NULL` later.
- Prefer `CHECK` constraints over PostgreSQL enums for easier evolution in capstone projects.

---

# 19. Backup and Restore Plan

## 19.1 Backup

Recommended nightly backup:

```bash
pg_dump -Fc -d tripplanner_ev -f /backups/tripplanner_ev_$(date +%F).dump
```

Also back up:

- Object storage files or MinIO data directory.
- Kafka topic configuration.
- Config Server Git repository.
- Environment variable/secrets file.

## 19.2 Restore

```bash
createdb tripplanner_ev_restored
pg_restore -d tripplanner_ev_restored /backups/tripplanner_ev_YYYY-MM-DD.dump
```

Validate restore by checking:

- Schema count.
- Row counts for critical tables.
- Sample trip read.
- Sample charger radius query.
- Notification inbox query.

---

# 20. Security and Privacy Notes

- Store only hashed share tokens.
- Avoid storing raw external API responses if they contain unnecessary PII.
- Redact AI logs and tool invocation payloads.
- Hash notification delivery destinations where possible.
- Audit sensitive administrative actions.
- Keep private media inaccessible unless user has permission.
- Never rely only on frontend authorization; every service must enforce permissions.

---

# 21. Implementation-Ready DDL Starter

This is a starter DDL. It is suitable as a foundation for Flyway migrations, but service-specific DTO validation and update triggers should still be added during implementation.

```sql
-- ==========================================================
-- Extensions
-- ==========================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- ==========================================================
-- Schemas
-- ==========================================================
CREATE SCHEMA IF NOT EXISTS trip;
CREATE SCHEMA IF NOT EXISTS iam;
CREATE SCHEMA IF NOT EXISTS media;
CREATE SCHEMA IF NOT EXISTS ev;
CREATE SCHEMA IF NOT EXISTS social;
CREATE SCHEMA IF NOT EXISTS notif;
CREATE SCHEMA IF NOT EXISTS ai;

-- ==========================================================
-- trip.trips
-- ==========================================================
CREATE TABLE IF NOT EXISTS trip.trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    title VARCHAR(160) NOT NULL,
    description TEXT,
    visibility VARCHAR(20) NOT NULL DEFAULT 'private'
        CHECK (visibility IN ('private', 'unlisted', 'public')),
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'archived', 'deleted')),
    start_date DATE,
    end_date DATE,
    timezone VARCHAR(64),
    cover_media_id UUID,
    currency CHAR(3) NOT NULL DEFAULT 'THB',
    budget_amount NUMERIC(12,2),
    stops_jsonb JSONB NOT NULL DEFAULT '[]'::jsonb
        CHECK (jsonb_typeof(stops_jsonb) = 'array'),
    route_legs_jsonb JSONB NOT NULL DEFAULT '[]'::jsonb
        CHECK (jsonb_typeof(route_legs_jsonb) = 'array'),
    route_summary_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb
        CHECK (jsonb_typeof(route_summary_jsonb) = 'object'),
    ev_profile_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb
        CHECK (jsonb_typeof(ev_profile_jsonb) = 'object'),
    metadata_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb
        CHECK (jsonb_typeof(metadata_jsonb) = 'object'),
    copied_from_trip_id UUID,
    copied_from_post_id UUID,
    copied_from_title VARCHAR(160),
    copied_from_author_display_name VARCHAR(120),
    copied_at TIMESTAMPTZ,
    search_vector TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(description, ''))
    ) STORED,
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_trip_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date),
    CONSTRAINT chk_trip_budget_non_negative CHECK (budget_amount IS NULL OR budget_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_trip_trips_owner_created ON trip.trips(owner_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trip_trips_visibility ON trip.trips(visibility) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trip_trips_search ON trip.trips USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS idx_trip_trips_title_trgm ON trip.trips USING GIN(title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_trip_trips_stops_jsonb ON trip.trips USING GIN(stops_jsonb);
CREATE INDEX IF NOT EXISTS idx_trip_trips_copied_from_trip ON trip.trips(copied_from_trip_id);

-- ==========================================================
-- trip planning child tables added for OpenAPI v1.1
-- ==========================================================
CREATE TABLE IF NOT EXISTS trip.trip_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trip.trips(id) ON DELETE CASCADE,
    title VARCHAR(120) NOT NULL,
    section_type VARCHAR(30) NOT NULL DEFAULT 'CUSTOM'
        CHECK (section_type IN ('PLACES_TO_VISIT', 'RESTAURANTS', 'LODGING', 'ACTIVITIES', 'CUSTOM')),
    sort_order INT NOT NULL DEFAULT 0,
    is_collapsed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_trip_sections_trip_order ON trip.trip_sections(trip_id, sort_order) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_trip_sections_title_active ON trip.trip_sections(trip_id, lower(title)) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS trip.trip_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trip.trips(id) ON DELETE CASCADE,
    section_id UUID NOT NULL REFERENCES trip.trip_sections(id) ON DELETE CASCADE,
    provider VARCHAR(20) NOT NULL CHECK (provider IN ('GOOGLE', 'MANUAL')),
    provider_place_id VARCHAR(255),
    name VARCHAR(200) NOT NULL,
    address TEXT,
    lat NUMERIC(9,6),
    lng NUMERIC(9,6),
    phone VARCHAR(80),
    website TEXT,
    photo_url TEXT,
    notes TEXT,
    planned_date DATE,
    start_time TIME,
    end_time TIME,
    sort_order INT NOT NULL DEFAULT 0,
    metadata_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata_jsonb) = 'object'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_trip_place_times CHECK (end_time IS NULL OR start_time IS NULL OR end_time >= start_time)
);

CREATE INDEX IF NOT EXISTS idx_trip_places_section_order ON trip.trip_places(trip_id, section_id, sort_order) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trip_places_planned_date ON trip.trip_places(trip_id, planned_date) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trip_places_name_trgm ON trip.trip_places USING GIN(name gin_trgm_ops);
CREATE UNIQUE INDEX IF NOT EXISTS uq_trip_places_provider_active ON trip.trip_places(trip_id, provider, provider_place_id)
WHERE deleted_at IS NULL AND provider_place_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS trip.trip_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trip.trips(id) ON DELETE CASCADE,
    target_type VARCHAR(30) NOT NULL CHECK (target_type IN ('TRIP', 'PLACE', 'DAY', 'RESERVATION')),
    target_id UUID,
    target_date DATE,
    content TEXT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_by_user_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_trip_note_day_target CHECK (
        (target_type = 'DAY' AND target_date IS NOT NULL)
        OR (target_type <> 'DAY')
    )
);

CREATE INDEX IF NOT EXISTS idx_trip_notes_trip_target ON trip.trip_notes(trip_id, target_type, target_id, target_date, sort_order) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS trip.itinerary_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trip.trips(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    item_type VARCHAR(30) NOT NULL CHECK (item_type IN ('PLACE', 'RESERVATION', 'NOTE', 'TRANSPORT', 'CUSTOM')),
    ref_id UUID,
    title VARCHAR(200) NOT NULL,
    start_time TIME,
    end_time TIME,
    notes TEXT,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_trip_itinerary_times CHECK (end_time IS NULL OR start_time IS NULL OR end_time >= start_time)
);

CREATE INDEX IF NOT EXISTS idx_trip_itinerary_trip_date_order ON trip.itinerary_items(trip_id, date, sort_order) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trip_itinerary_ref ON trip.itinerary_items(trip_id, item_type, ref_id) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS trip.reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trip.trips(id) ON DELETE CASCADE,
    category VARCHAR(30) NOT NULL CHECK (category IN ('FLIGHT', 'LODGING', 'RENTAL_CAR', 'RESTAURANT', 'ACTIVITY', 'OTHER')),
    title VARCHAR(200) NOT NULL,
    provider_name VARCHAR(160),
    confirmation_number VARCHAR(120),
    start_datetime TIMESTAMPTZ,
    end_datetime TIMESTAMPTZ,
    location_name VARCHAR(200),
    address TEXT,
    lat NUMERIC(9,6),
    lng NUMERIC(9,6),
    cost_amount NUMERIC(12,2),
    currency CHAR(3),
    notes TEXT,
    metadata_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata_jsonb) = 'object'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT chk_trip_reservation_times CHECK (end_datetime IS NULL OR start_datetime IS NULL OR end_datetime >= start_datetime),
    CONSTRAINT chk_trip_reservation_cost CHECK (cost_amount IS NULL OR cost_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_trip_reservations_trip_start ON trip.reservations(trip_id, start_datetime) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trip_reservations_category ON trip.reservations(trip_id, category) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS trip.trip_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trip.trips(id) ON DELETE CASCADE,
    media_id UUID NOT NULL,
    target_type VARCHAR(30) NOT NULL CHECK (target_type IN ('TRIP', 'PLACE', 'RESERVATION', 'EXPENSE', 'NOTE')),
    target_id UUID,
    label VARCHAR(160),
    created_by_user_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_trip_attachments_trip_target ON trip.trip_attachments(trip_id, target_type, target_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trip_attachments_media ON trip.trip_attachments(media_id) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS trip.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trip.trips(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    category VARCHAR(30) NOT NULL CHECK (category IN ('FLIGHT', 'LODGING', 'FOOD', 'TRANSPORT', 'ACTIVITY', 'SHOPPING', 'OTHER')),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    currency CHAR(3) NOT NULL DEFAULT 'THB',
    paid_by_user_id UUID NOT NULL,
    expense_date DATE NOT NULL,
    place_id UUID,
    reservation_id UUID,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_trip_expenses_trip_date ON trip.expenses(trip_id, expense_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trip_expenses_category ON trip.expenses(trip_id, category) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trip_expenses_payer ON trip.expenses(trip_id, paid_by_user_id) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS trip.expense_splits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID NOT NULL REFERENCES trip.expenses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    split_type VARCHAR(30) NOT NULL CHECK (split_type IN ('EQUAL', 'EXACT', 'PERCENTAGE')),
    percentage NUMERIC(5,2),
    status VARCHAR(20) NOT NULL DEFAULT 'OWED' CHECK (status IN ('OWED', 'PAID', 'WAIVED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_trip_expense_split_amount CHECK (amount >= 0),
    CONSTRAINT chk_trip_expense_split_percentage CHECK (percentage IS NULL OR (percentage >= 0 AND percentage <= 100))
);

CREATE INDEX IF NOT EXISTS idx_trip_expense_splits_expense ON trip.expense_splits(expense_id);
CREATE INDEX IF NOT EXISTS idx_trip_expense_splits_user ON trip.expense_splits(user_id);

CREATE TABLE IF NOT EXISTS trip.trip_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trip.trips(id) ON DELETE CASCADE,
    user_id UUID,
    email VARCHAR(255),
    display_name VARCHAR(120) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('OWNER', 'EDITOR', 'VIEWER')),
    invite_status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (invite_status IN ('ACCEPTED', 'PENDING')),
    invited_by_user_id UUID,
    joined_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    removed_at TIMESTAMPTZ,
    CONSTRAINT chk_trip_member_identity CHECK (user_id IS NOT NULL OR email IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_trip_members_trip ON trip.trip_members(trip_id) WHERE removed_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_trip_members_user ON trip.trip_members(user_id) WHERE removed_at IS NULL AND user_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_trip_members_user_active ON trip.trip_members(trip_id, user_id) WHERE removed_at IS NULL AND user_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_trip_members_email_active ON trip.trip_members(trip_id, lower(email)) WHERE removed_at IS NULL AND email IS NOT NULL;

-- ==========================================================
-- trip.trip_revisions
-- ==========================================================
CREATE TABLE IF NOT EXISTS trip.trip_revisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trip.trips(id) ON DELETE CASCADE,
    revision_no INT NOT NULL,
    snapshot_jsonb JSONB NOT NULL CHECK (jsonb_typeof(snapshot_jsonb) = 'object'),
    change_summary VARCHAR(255),
    created_by_user_id UUID NOT NULL,
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (trip_id, revision_no)
);

CREATE INDEX IF NOT EXISTS idx_trip_revisions_trip_created ON trip.trip_revisions(trip_id, created_at DESC);

-- ==========================================================
-- trip.share_links
-- ==========================================================
CREATE TABLE IF NOT EXISTS trip.share_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trip.trips(id) ON DELETE CASCADE,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    permission VARCHAR(20) NOT NULL DEFAULT 'view'
        CHECK (permission IN ('view', 'copy')),
    created_by_user_id UUID NOT NULL,
    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    max_uses INT,
    use_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (max_uses IS NULL OR max_uses > 0)
);

CREATE INDEX IF NOT EXISTS idx_trip_share_links_trip ON trip.share_links(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_share_links_active ON trip.share_links(token_hash) WHERE revoked_at IS NULL;

-- ==========================================================
-- trip.trip_copies
-- ==========================================================
CREATE TABLE IF NOT EXISTS trip.trip_copies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    new_trip_id UUID NOT NULL REFERENCES trip.trips(id) ON DELETE CASCADE,
    copied_by_user_id UUID NOT NULL,
    source_trip_id UUID,
    source_post_id UUID,
    source_title VARCHAR(160),
    source_author_display_name VARCHAR(120),
    copy_context VARCHAR(30) NOT NULL CHECK (copy_context IN ('public_trip', 'community_post', 'share_link')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trip_copies_new_trip ON trip.trip_copies(new_trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_copies_source_trip ON trip.trip_copies(source_trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_copies_user_created ON trip.trip_copies(copied_by_user_id, created_at DESC);

-- ==========================================================
-- iam.users
-- ==========================================================
CREATE TABLE IF NOT EXISTS iam.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_subject VARCHAR(128) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL,
    display_name VARCHAR(120) NOT NULL,
    avatar_media_id UUID,
    status VARCHAR(30) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'deactivated', 'banned')),
    locale VARCHAR(20),
    country_code CHAR(2),
    preferences_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(preferences_jsonb) = 'object'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_iam_users_email_lower ON iam.users(lower(email));
CREATE INDEX IF NOT EXISTS idx_iam_users_status ON iam.users(status);

CREATE TABLE IF NOT EXISTS iam.user_roles (
    user_id UUID NOT NULL REFERENCES iam.users(id) ON DELETE CASCADE,
    role VARCHAR(30) NOT NULL CHECK (role IN ('user', 'moderator', 'admin')),
    granted_by_user_id UUID,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, role)
);

CREATE TABLE IF NOT EXISTS iam.user_bans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES iam.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    banned_by_user_id UUID NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ends_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iam_user_bans_active ON iam.user_bans(user_id) WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS iam.acl_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_type VARCHAR(50) NOT NULL,
    resource_id UUID NOT NULL,
    principal_type VARCHAR(20) NOT NULL CHECK (principal_type IN ('user', 'role', 'public')),
    principal_id VARCHAR(128),
    permission VARCHAR(30) NOT NULL CHECK (permission IN ('viewer', 'editor', 'owner')),
    granted_by_user_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_iam_acl_resource ON iam.acl_entries(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_iam_acl_principal ON iam.acl_entries(principal_type, principal_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_iam_acl_active
ON iam.acl_entries(resource_type, resource_id, principal_type, coalesce(principal_id, ''), permission)
WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS iam.audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id UUID,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id UUID,
    ip_address INET,
    user_agent TEXT,
    before_jsonb JSONB,
    after_jsonb JSONB,
    metadata_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iam_audit_resource ON iam.audit_log(resource_type, resource_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_iam_audit_actor ON iam.audit_log(actor_user_id, created_at DESC);

-- ==========================================================
-- media
-- ==========================================================
CREATE TABLE IF NOT EXISTS media.media_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    bucket VARCHAR(80) NOT NULL,
    object_key TEXT NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    mime_type VARCHAR(120) NOT NULL,
    size_bytes BIGINT NOT NULL CHECK (size_bytes >= 0),
    checksum_sha256 CHAR(64),
    status VARCHAR(30) NOT NULL DEFAULT 'requested'
        CHECK (status IN ('requested', 'uploaded', 'scanning', 'ready', 'blocked', 'deleted')),
    visibility VARCHAR(20) NOT NULL DEFAULT 'private'
        CHECK (visibility IN ('private', 'public')),
    safe_url TEXT,
    thumbnail_object_key TEXT,
    scan_result_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    metadata_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    UNIQUE (bucket, object_key)
);

CREATE INDEX IF NOT EXISTS idx_media_assets_owner ON media.media_assets(owner_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_media_assets_status ON media.media_assets(status, created_at);

CREATE TABLE IF NOT EXISTS media.upload_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL REFERENCES media.media_assets(id) ON DELETE CASCADE,
    owner_user_id UUID NOT NULL,
    upload_url_expires_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'issued'
        CHECK (status IN ('issued', 'completed', 'expired', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_media_upload_sessions_owner ON media.upload_sessions(owner_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_media_upload_sessions_expiry ON media.upload_sessions(upload_url_expires_at) WHERE status = 'issued';

-- ==========================================================
-- ev.chargers
-- ==========================================================
CREATE TABLE IF NOT EXISTS ev.chargers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    operator_name VARCHAR(160),
    lat NUMERIC(9,6) NOT NULL CHECK (lat BETWEEN -90 AND 90),
    lng NUMERIC(9,6) NOT NULL CHECK (lng BETWEEN -180 AND 180),
    location GEOGRAPHY(Point, 4326) NOT NULL,
    address TEXT,
    province VARCHAR(100),
    connector_types_jsonb JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(connector_types_jsonb) = 'array'),
    max_kw NUMERIC(7,2),
    total_connectors INT CHECK (total_connectors IS NULL OR total_connectors >= 0),
    available_connectors INT CHECK (available_connectors IS NULL OR available_connectors >= 0),
    price_text TEXT,
    opening_hours_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    source VARCHAR(40) NOT NULL CHECK (source IN ('GOOGLE_PLACES', 'OPENCHARGEMAP', 'ADMIN_IMPORT', 'USER_SUBMITTED', 'PARTNER_API')),
    source_external_id VARCHAR(255),
    google_place_id VARCHAR(255),
    source_url TEXT,
    confidence_score NUMERIC(5,2) NOT NULL DEFAULT 50 CHECK (confidence_score BETWEEN 0 AND 100),
    verification_status VARCHAR(40) NOT NULL DEFAULT 'UNVERIFIED'
        CHECK (verification_status IN ('UNVERIFIED', 'PENDING_VERIFICATION', 'GOOGLE_CACHED', 'USER_VERIFIED', 'ADMIN_VERIFIED', 'REJECTED', 'STALE')),
    status VARCHAR(30) NOT NULL DEFAULT 'unknown'
        CHECK (status IN ('active', 'temporarily_closed', 'closed', 'unknown')),
    rating_avg NUMERIC(3,2) NOT NULL DEFAULT 0 CHECK (rating_avg BETWEEN 0 AND 5),
    rating_count INT NOT NULL DEFAULT 0 CHECK (rating_count >= 0),
    report_count INT NOT NULL DEFAULT 0 CHECK (report_count >= 0),
    last_seen_at TIMESTAMPTZ,
    last_provider_refreshed_at TIMESTAMPTZ,
    last_user_verified_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_by_user_id UUID,
    metadata_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ev_chargers_location ON ev.chargers USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_ev_chargers_status_verification ON ev.chargers(status, verification_status);
CREATE INDEX IF NOT EXISTS idx_ev_chargers_name_trgm ON ev.chargers USING GIN(name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_ev_chargers_expires_at ON ev.chargers(expires_at);
CREATE INDEX IF NOT EXISTS idx_ev_chargers_google_place_id ON ev.chargers(google_place_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_ev_chargers_source_external
ON ev.chargers(source, source_external_id)
WHERE source_external_id IS NOT NULL;

-- ==========================================================
-- ev.charger_tiles
-- ==========================================================
CREATE TABLE IF NOT EXISTS ev.charger_tiles (
    tile_key VARCHAR(80) NOT NULL,
    provider VARCHAR(40) NOT NULL,
    last_refreshed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    charger_count INT NOT NULL DEFAULT 0,
    confidence_score NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (confidence_score BETWEEN 0 AND 100),
    refresh_status VARCHAR(30) NOT NULL DEFAULT 'stale'
        CHECK (refresh_status IN ('fresh', 'stale', 'refreshing', 'failed', 'low_confidence')),
    last_error TEXT,
    metadata_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tile_key, provider)
);

CREATE INDEX IF NOT EXISTS idx_ev_charger_tiles_expiry ON ev.charger_tiles(expires_at, refresh_status);

-- ==========================================================
-- ev reviews/comments/reports/suggestions
-- ==========================================================
CREATE TABLE IF NOT EXISTS ev.charger_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    charger_id UUID NOT NULL REFERENCES ev.chargers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    visit_date DATE,
    charging_successful BOOLEAN,
    wait_time_minutes INT CHECK (wait_time_minutes IS NULL OR wait_time_minutes >= 0),
    connector_used VARCHAR(40),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ev_reviews_user_charger_active
ON ev.charger_reviews(user_id, charger_id)
WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ev_reviews_charger_created ON ev.charger_reviews(charger_id, created_at DESC);

CREATE TABLE IF NOT EXISTS ev.charger_review_media (
    review_id UUID NOT NULL REFERENCES ev.charger_reviews(id) ON DELETE CASCADE,
    media_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (review_id, media_id)
);

CREATE TABLE IF NOT EXISTS ev.charger_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    charger_id UUID NOT NULL REFERENCES ev.chargers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    parent_comment_id UUID REFERENCES ev.charger_comments(id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'deleted_by_user', 'deleted_by_mod')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ev_comments_charger_created ON ev.charger_comments(charger_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ev_comments_parent_created ON ev.charger_comments(parent_comment_id, created_at);

CREATE TABLE IF NOT EXISTS ev.charger_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    charger_id UUID NOT NULL REFERENCES ev.chargers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    report_type VARCHAR(50) NOT NULL,
    description TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'reviewing', 'resolved', 'rejected')),
    reviewed_by_admin_id UUID,
    resolution_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ev_reports_status_created ON ev.charger_reports(status, created_at);
CREATE INDEX IF NOT EXISTS idx_ev_reports_charger ON ev.charger_reports(charger_id);

CREATE TABLE IF NOT EXISTS ev.charger_suggestions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    charger_id UUID REFERENCES ev.chargers(id) ON DELETE SET NULL,
    user_id UUID NOT NULL,
    suggestion_type VARCHAR(30) NOT NULL CHECK (suggestion_type IN ('missing_charger', 'edit_charger')),
    suggested_name VARCHAR(200),
    suggested_address TEXT,
    suggested_connector_types_jsonb JSONB NOT NULL DEFAULT '[]'::jsonb,
    suggested_max_kw NUMERIC(7,2),
    suggested_opening_hours_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    suggested_lat NUMERIC(9,6),
    suggested_lng NUMERIC(9,6),
    status VARCHAR(30) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by_admin_id UUID,
    review_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ev_suggestions_status_created ON ev.charger_suggestions(status, created_at);
CREATE INDEX IF NOT EXISTS idx_ev_suggestions_charger ON ev.charger_suggestions(charger_id);

-- ==========================================================
-- social
-- ==========================================================
CREATE TABLE IF NOT EXISTS social.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_user_id UUID NOT NULL,
    trip_id UUID,
    title VARCHAR(180) NOT NULL,
    body TEXT,
    post_type VARCHAR(30) NOT NULL DEFAULT 'general'
        CHECK (post_type IN ('trip_share', 'general')),
    status VARCHAR(30) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'hidden', 'deleted_by_user', 'deleted_by_mod')),
    tags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    trip_snapshot_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    score INT NOT NULL DEFAULT 0,
    upvote_count INT NOT NULL DEFAULT 0,
    downvote_count INT NOT NULL DEFAULT 0,
    comment_count INT NOT NULL DEFAULT 0,
    bookmark_count INT NOT NULL DEFAULT 0,
    search_vector TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(body, '') || ' ' || array_to_string(tags, ' '))
    ) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_social_posts_search ON social.posts USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS idx_social_posts_title_trgm ON social.posts USING GIN(title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_social_posts_tags ON social.posts USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_social_posts_new_feed ON social.posts(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_social_posts_top_feed ON social.posts(status, score DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_social_posts_trip_id ON social.posts(trip_id);

CREATE TABLE IF NOT EXISTS social.comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES social.posts(id) ON DELETE CASCADE,
    author_user_id UUID NOT NULL,
    parent_comment_id UUID REFERENCES social.comments(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'deleted_by_user', 'deleted_by_mod')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_social_comments_post_created ON social.comments(post_id, created_at);
CREATE INDEX IF NOT EXISTS idx_social_comments_parent_created ON social.comments(parent_comment_id, created_at);

CREATE TABLE IF NOT EXISTS social.post_votes (
    post_id UUID NOT NULL REFERENCES social.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    direction SMALLINT NOT NULL CHECK (direction IN (-1, 0, 1)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_social_post_votes_user ON social.post_votes(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS social.bookmarks (
    post_id UUID NOT NULL REFERENCES social.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_social_bookmarks_user_created ON social.bookmarks(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS social.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES social.posts(id) ON DELETE CASCADE,
    comment_id UUID REFERENCES social.comments(id) ON DELETE CASCADE,
    reporter_user_id UUID NOT NULL,
    report_type VARCHAR(50) NOT NULL,
    description TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'reviewing', 'resolved', 'rejected')),
    reviewed_by_user_id UUID,
    resolution_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_at TIMESTAMPTZ,
    CHECK ((post_id IS NOT NULL AND comment_id IS NULL) OR (post_id IS NULL AND comment_id IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_social_reports_status_created ON social.reports(status, created_at);

-- ==========================================================
-- notif
-- ==========================================================
CREATE TABLE IF NOT EXISTS notif.notification_preferences (
    user_id UUID PRIMARY KEY,
    in_app_enabled BOOLEAN NOT NULL DEFAULT true,
    email_enabled BOOLEAN NOT NULL DEFAULT false,
    push_enabled BOOLEAN NOT NULL DEFAULT false,
    sms_enabled BOOLEAN NOT NULL DEFAULT false,
    event_settings_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    quiet_hours_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notif.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_user_id UUID NOT NULL,
    actor_user_id UUID,
    type VARCHAR(80) NOT NULL,
    title VARCHAR(180) NOT NULL,
    body TEXT,
    resource_type VARCHAR(50),
    resource_id UUID,
    status VARCHAR(30) NOT NULL DEFAULT 'unread'
        CHECK (status IN ('unread', 'read', 'archived')),
    metadata_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notif_notifications_inbox ON notif.notifications(recipient_user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_notifications_expiry ON notif.notifications(expires_at);

CREATE TABLE IF NOT EXISTS notif.delivery_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL REFERENCES notif.notifications(id) ON DELETE CASCADE,
    channel VARCHAR(30) NOT NULL CHECK (channel IN ('in_app', 'email', 'push', 'sms')),
    provider VARCHAR(80),
    destination_hash VARCHAR(128),
    status VARCHAR(30) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'sent', 'failed', 'skipped')),
    attempts INT NOT NULL DEFAULT 0,
    last_error TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notif.consumed_events (
    event_id TEXT NOT NULL,
    consumer_name VARCHAR(100) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (event_id, consumer_name)
);

-- ==========================================================
-- ai
-- ==========================================================
CREATE TABLE IF NOT EXISTS ai.prompt_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    version INT NOT NULL,
    model_name VARCHAR(100) NOT NULL,
    system_prompt TEXT NOT NULL,
    tool_schema_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    temperature NUMERIC(3,2),
    is_active BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (name, version)
);

CREATE TABLE IF NOT EXISTS ai.sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    trip_id UUID,
    prompt_config_id UUID REFERENCES ai.prompt_configs(id) ON DELETE SET NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'completed', 'failed', 'cancelled')),
    metadata_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ai_sessions_user_created ON ai.sessions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_sessions_trip ON ai.sessions(trip_id);

CREATE TABLE IF NOT EXISTS ai.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES ai.sessions(id) ON DELETE CASCADE,
    role VARCHAR(30) NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'tool')),
    content TEXT,
    structured_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_messages_session_created ON ai.messages(session_id, created_at);

CREATE TABLE IF NOT EXISTS ai.usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES ai.sessions(id) ON DELETE SET NULL,
    user_id UUID NOT NULL,
    model_name VARCHAR(100) NOT NULL,
    operation VARCHAR(80) NOT NULL,
    input_tokens INT NOT NULL DEFAULT 0,
    output_tokens INT NOT NULL DEFAULT 0,
    total_tokens INT NOT NULL DEFAULT 0,
    estimated_cost NUMERIC(12,6) NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL CHECK (status IN ('success', 'failed', 'quota_blocked')),
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_user_created ON ai.usage_logs(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS ai.quota_counters (
    user_id UUID NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    tokens_used BIGINT NOT NULL DEFAULT 0,
    cost_used NUMERIC(12,6) NOT NULL DEFAULT 0,
    request_count INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, period_start, period_end)
);

CREATE TABLE IF NOT EXISTS ai.tool_invocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES ai.sessions(id) ON DELETE CASCADE,
    tool_name VARCHAR(100) NOT NULL,
    request_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    response_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(30) NOT NULL CHECK (status IN ('success', 'failed', 'blocked')),
    duration_ms INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================================
-- generic outbox tables
-- ==========================================================
CREATE TABLE IF NOT EXISTS trip.outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id TEXT NOT NULL UNIQUE,
    event_type VARCHAR(100) NOT NULL,
    aggregate_type VARCHAR(50) NOT NULL,
    aggregate_id UUID NOT NULL,
    partition_key TEXT NOT NULL,
    payload_jsonb JSONB NOT NULL,
    headers_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
    published BOOLEAN NOT NULL DEFAULT false,
    published_at TIMESTAMPTZ,
    publish_attempts INT NOT NULL DEFAULT 0,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS iam.outbox (LIKE trip.outbox INCLUDING ALL);
CREATE TABLE IF NOT EXISTS ev.outbox (LIKE trip.outbox INCLUDING ALL);
CREATE TABLE IF NOT EXISTS social.outbox (LIKE trip.outbox INCLUDING ALL);

CREATE INDEX IF NOT EXISTS idx_trip_outbox_unpublished ON trip.outbox(created_at) WHERE published = false;
CREATE INDEX IF NOT EXISTS idx_iam_outbox_unpublished ON iam.outbox(created_at) WHERE published = false;
CREATE INDEX IF NOT EXISTS idx_ev_outbox_unpublished ON ev.outbox(created_at) WHERE published = false;
CREATE INDEX IF NOT EXISTS idx_social_outbox_unpublished ON social.outbox(created_at) WHERE published = false;
```

---

# 22. Service-Level Database Access Matrix

| Service                 | Can Read               | Can Write              | Must Not Access                                 |
| ----------------------- | ---------------------- | ---------------------- | ----------------------------------------------- |
| Trip & Media Service    | `trip`, `iam`, `media` | `trip`, `iam`, `media` | `ev`, `social`, `notif`, `ai`                   |
| EV Intelligence Service | `ev`                   | `ev`                   | `trip`, `iam`, `media`, `social`, `notif`, `ai` |
| Community Service       | `social`, `notif`      | `social`, `notif`      | `trip`, `iam`, `media`, `ev`, `ai`              |
| AI Orchestrator Service | `ai`                   | `ai`                   | `trip`, `iam`, `media`, `ev`, `social`, `notif` |

For cross-service data:

- Use REST APIs for synchronous reads/writes.
- Use Kafka events for asynchronous updates.
- Store denormalized display snapshots when needed.

---

# 23. Recommended Implementation Order

1. Create database extensions and schemas.
2. Implement `iam.users`, `iam.user_roles`, and basic user sync from Keycloak.
3. Implement `trip.trips`, `trip.trip_revisions`, and `trip.share_links`.
4. Implement OpenAPI v1.1 trip-planning child tables: `trip.trip_sections`, `trip.trip_places`, `trip.trip_notes`, `trip.itinerary_items`, `trip.reservations`, `trip.trip_attachments`, `trip.expenses`, `trip.expense_splits`, and `trip.trip_members`.
5. Implement copy-trip flow with `trip.trip_copies`, safe child-record copying, and `trip.outbox`.
6. Implement `media.media_assets` and upload sessions.
7. Implement `ev.chargers` and PostGIS radius search.
8. Implement `ev.charger_tiles` and local-first refresh behavior.
9. Implement charger reviews, reports, and suggestions.
10. Implement `social.posts`, comments, votes, bookmarks, and reports.
11. Implement `notif.notifications`, preferences, and delivery logs.
12. Implement outbox publishers and consumer deduplication.
13. Implement AI tables only after core trip + EV + community flow works.

---

# 24. Final Recommendation

This database design is appropriate for the approved v1.0 architecture. It keeps the operational footprint low by using one PostgreSQL instance, but preserves professional service boundaries through schema ownership rules. It supports the finalized copy-trip model, the OpenAPI v1.1 detailed trip workspace, Thailand-friendly EV charger data strategy, charger community reviews, community trip sharing, PostGIS charger search, Postgres full-text search, notification delivery, media metadata, and optional AI planning assistance.

For the capstone, the most important implementation discipline is to avoid shortcut cross-schema joins. Even though all schemas are physically inside one PostgreSQL instance, the codebase should behave as if every schema belongs to a separate database.
