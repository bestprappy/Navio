# Navio — Progress Report

**Status:** As-built audit of the whole repository, 2026-09-09
**Method:** Every claim below was read out of the code, migrations, deploy config, or git history — not from planning documents. Where a planning document and the code disagree, the code wins and the drift is called out in §6.
**Baseline for "%":** the v1 scope defined in [Navio Architecture](<Navio%20Architecture.md>), [Navio Api Documentation](<../api/Navio%20Api%20Documentation.md>), and [Navio Database](<../database/Navio%20Database.md>). A feature at 100% would be fully implemented, tested, and deployed.

---

## 1. One-paragraph summary

Navio's **platform layer is essentially finished** — Config Server, Eureka, Spring Cloud Gateway with real JWT validation, Keycloak with Google + email/password, NGINX/TLS, and a self-hosted observability stack all run in production on the VM. **Trip Planning is the mature domain**: trips, itinerary blocks, items, budget, and EV optimization are persisted and wired end-to-end to a large Next.js planner. The three weak spots are all *breadth*, not quality: **Mobility & EV has no database at all** (it is a Google passthrough, so the entire charger domain — cache, reviews, reports, admin verification — is missing), **Community has groups but no posts** (the whole discussion feature is mock data in the browser), and **Explore is 100% mock data** with no backing service. **AI Planning does not exist** as a project. Kafka is wired but only one service produces to it and **nothing consumes**, so cross-service eventing is not yet real.

**Overall v1 completion: roughly 55%.** The remaining 45% is concentrated in four buildable pieces: `social.posts`, the `ev` schema, trip sharing/public Explore, and the AI service.

---

## 2. Feature status table

| Core feature                      | Grouped subfeature                                                       | Status      | Progress | Note                                                                                                                         |
| --------------------------------- | ------------------------------------------------------------------------ | ----------- | -------: | ---------------------------------------------------------------------------------------------------------------------------- |
| **Platform & infra**        | Config Server, Eureka, Spring Cloud Gateway                              | Done        |      95% | Routes for all 4 domains present in`.deploy/config/api-gateway.yml`                                                        |
|                                   | Gateway JWT validation + identity propagation                            | Done        |      95% | Strips client`X-User-*`, re-injects from token                                                                             |
|                                   | Keycloak realm, Google IdP, email/password                               | Done        |      90% | Custom`navio` login theme; realm imported from `navio-realm.json`                                                        |
|                                   | NGINX edge, TLS, production compose                                      | Done        |      90% | Full 16-service stack deploys via`.deploy/scripts/deploy.sh`                                                               |
|                                   | Observability (Alloy, Prometheus, Loki, Grafana)                         | In progress |      70% | Self-hosted in prod compose;**no trace backend (Tempo/Zipkin) deployed**                                               |
|                                   | CI/CD                                                                    | In progress |      40% | Only`deploy-backend.yml`; no test/lint/build gate for client or server                                                     |
| **User Management**         | Profile, preferences,`GET/PATCH /v1/users/me`                          | Done        |      90% | Reads identity from JWT directly, not headers                                                                                |
|                                   | Saved vehicles CRUD (`/v1/users/me/vehicles`)                          | Done        |      85% | **Backend complete but the client never calls it** — see Garage below                                                 |
|                                   | Admin: list, suspend, reactivate, role grant/revoke                      | Done        |      85% | Keycloak Admin API facade working                                                                                            |
|                                   | Transactional outbox + relay                                             | Done        |      80% | Only producer in the system; publishes`user.events.v1`                                                                     |
|                                   | Public user search / avatar upload                                       | Incomplete  |      10% | Documented in API spec, no endpoint                                                                                          |
| **Trip Planning**           | Trip CRUD + list/pagination                                              | Done        |      90% | `trip.trip`, 7 Flyway migrations                                                                                           |
|                                   | Itinerary blocks + block items + checklists                              | Done        |      90% | `list_block`, `block_item`, `checklist_sub_item`                                                                       |
|                                   | Planner autosave (`GET/PUT /planner`)                                  | Done        |      90% | Whole-plan read/write; drives the client planner                                                                             |
|                                   | Budget, expenses, currency conversion                                    | Done        |      85% | `trip.expense`, live FX rate endpoint                                                                                      |
|                                   | EV optimization preview + apply                                          | Done        |      85% | Calls Mobility`internal/v1/ev-route/optimize`                                                                              |
|                                   | Revisions and rollback                                                   | Incomplete  |       0% | Documented (`/revisions`, `/rollback`); no table, no controller                                                          |
|                                   | Visibility change, share links, copy-to-my-trips                         | Incomplete  |       5% | `TripVisibility` enum + repo query exist; **no endpoints**                                                           |
|                                   | Trip permissions / tripmates (owner-editor-viewer)                       | Incomplete  |       0% | Every trip is single-owner today                                                                                             |
|                                   | Public Explore catalogue (`/v1/public-trips`)                          | Incomplete  |       0% | Gateway route exists and resolves to nothing                                                                                 |
|                                   | Reservations, attachments                                                | Incomplete  |       0% | Deferred                                                                                                                     |
| **Mobility & EV**           | Place autocomplete, details, search, nearby                              | Done        |      85% | Google Places adapter, in-process stale-aware cache                                                                          |
|                                   | Route directions + polyline decoding                                     | Done        |      85% | Google Routes adapter                                                                                                        |
|                                   | EV route optimization (internal API)                                     | Done        |      80% | Best-tested area of the service                                                                                              |
|                                   | Charger search (`/v1/ev/chargers/near`)                                | In progress |      40% | Live provider passthrough only                                                                                               |
|                                   | **Charger persistence: `ev` schema**                             | Incomplete  |       5% | `V1__initialize_ev_schema.sql` creates **PostGIS and a comment — zero tables**. No entities, no repositories.       |
|                                   | Charger cache, geo-tiles, PostGIS queries                                | Incomplete  |       0% | Blocked on the schema above                                                                                                  |
|                                   | Charger reviews, comments, reports, suggestions                          | Incomplete  |       0% | ~15 documented endpoints, none built                                                                                         |
|                                   | Admin charger verification + tile refresh                                | Incomplete  |       0% | Gateway route`/v1/admin/ev/**` resolves to nothing                                                                         |
| **Community**               | Groups: create, list, search, detail, slug routing                       | Done        |      90% | 4 migrations, 18 endpoints on`GroupController`                                                                             |
|                                   | Membership: join, leave, mute, member list                               | Done        |      85% | `joined`/`muted`/`left` states working                                                                                 |
|                                   | Moderation: moderators, rules, flairs, resources, owner transfer, status | Done        |      80% | See the open findings in[Community Roles and Authorization](<../security/Navio%20Community%20Roles%20and%20Authorization.md>) |
|                                   | Group banner upload (`media.group_media`)                              | Done        |      75% | Only media path that exists                                                                                                  |
|                                   | **Posts, comments, votes, bookmarks, reports, feed**               | Incomplete  |       0% | **`social.posts` does not exist.** All post UI in the client is mock data.                                           |
|                                   | ir (`tsvector`)                                                        | Incomplete  |       0% | Only group search, via`LIKE`-style query                                                                                   |
|                                   | Notifications module (`notif` schema)                                  | Incomplete  |       0% | No schema, no controller, no code                                                                                            |
|                                   | Media upload sessions (`/v1/media/**`)                                 | Incomplete  |      10% | Group banner only; no generic upload-URL flow                                                                                |
| **Cross-service events**    | Kafka broker + topics + outbox pattern                                   | In progress |      30% | User Management produces;**zero `@KafkaListener` in the repo** — no consumer anywhere                               |
| **AI Planning**             | Entire service (`:8085`, Spring AI, Ollama/hosted)                     | Incomplete  |       0% | No project directory exists                                                                                                  |
| **Client — shell**         | Auth.js + Keycloak sign-in/up, route protection                          | Done        |      90% | Rebuilt on shadcn primitives                                                                                                 |
|                                   | App shell, navbar, sidebar, theming, error boundaries                    | Done        |      85% | Dark/light, Jotai + TanStack Query providers                                                                                 |
|                                   | Authenticated BFF proxies (`app/api/**`)                               | Done        |      85% | Trips, groups, geo, routes, users                                                                                            |
| **Client — Planner**       | Planner home, setup wizard, trip dashboard                               | Done        |      85% | 107 files; real API via`planner-api.ts`                                                                                    |
|                                   | Itinerary blocks, items, notes, checklists, drag-order                   | Done        |      85% | Persisted through`/planner` autosave                                                                                       |
|                                   | Budget + expenses UI                                                     | Done        |      85% | Wired to real endpoints                                                                                                      |
|                                   | Maps (Google + Mapbox), route overlay, place search                      | Done        |      85% | Both adapters present                                                                                                        |
|                                   | EV charger panel + optimization                                          | In progress |      70% | UI complete; depends on passthrough charger data                                                                             |
|                                   | **My Garage (vehicles)**                                           | In progress |      55% | **UI reads `vehicle.data.ts` mock data. The real `/v1/users/me/vehicles` API is built and unused.**                |
| **Client — Community**     | Group pages, create, discovery, membership, settings                     | Done        |      80% | Backed by the real group API                                                                                                 |
|                                   | **Posts, comments, voting, feed**                                  | In progress |      45% | Full UI built against`data.ts` mocks; **no backend to connect to**                                                   |
| **Client — Explore**       | Trip discovery, plan view, share dialog, copy                            | In progress |      30% | **Zero `fetch`/`useQuery` in the feature — entirely mock `PLANS` data**                                         |
| **Client — Settings**      | Profile page + autosave                                                  | Done        |      85% | Real`/v1/users/me`                                                                                                         |
| **Client — Notifications** | Any notification UI                                                      | Incomplete  |       0% | Not started                                                                                                                  |
| **Testing**                 | Backend unit/integration tests                                           | In progress |      55% | 27 test classes; strongest in Trip + Community, weakest in Mobility persistence (none to test)                               |
|                                   | Frontend tests                                                           | Incomplete  |      10% | One file:`tests/community/api.test.mjs`; no test runner script in `package.json`                                         |

---

## 3. Where the effort has actually gone

| Service                 | Main`.java` files | Controllers | Tests | Flyway migrations | Tables created |
| ----------------------- | ------------------: | ----------: | ----: | ----------------: | -------------: |
| trip-planning-service   |                  62 |           6 |     9 |                 7 |              5 |
| mobility-and-ev-service |                  59 |           4 |     8 |                 1 |    **0** |
| user-management-service |                  59 |           3 |     7 |                 1 |              6 |
| community-service       |                  55 |           2 |     7 |                 4 |              7 |
| api-gateway             |                   5 |           0 |     3 |                — |             — |
| configuration-server    |                   1 |           0 |     1 |                — |             — |
| discovery-server        |                   1 |           0 |     1 |                — |             — |

The Mobility row is the important one: 59 files and 8 tests, but **no tables**. All that code is provider adapters, DTOs, and the optimization algorithm. Everything the architecture calls "the charger domain" is still ahead.

---

## 4. What to do next

### Tier 1 — highest value per unit of work

1. **Connect My Garage to the real vehicles API.**
   The backend (`/v1/users/me/vehicles`, `iam.user_vehicles`, `UserVehicleService` + tests) is finished and unused; the client garage reads `constants/vehicle.data.ts`. This needs one BFF proxy route (`app/api/users/me/vehicles/[[...path]]/route.ts`) and a TanStack Query hook. It is the cheapest way to turn a mock feature into a real one, and it makes EV optimization use the user's actual car.
2. **Build `social.posts` — posts, comments, votes.**
   This is the single largest hole and the client UI already exists in full (`community-post-card`, `community-comment-thread`, `community-discussion`, `community-feed`). Do the security prerequisites first, in this order, exactly as §7 of the [authorization audit](<../security/Navio%20Community%20Roles%20and%20Authorization.md>) lays out:

   - Fix **F1** (a moderator can currently demote the owner) — two lines in `GroupAccessService`.
   - Add `requireActiveMember` — the seam every posting rule hangs from.
   - Block writes on non-`active` groups.
   - Then `V5__create_social_posts.sql` + `PostController`, and swap `data.ts` for real queries.
3. **Create the `ev` schema and the charger cache.**
   `V1__initialize_ev_schema.sql` creates PostGIS and nothing else. Add `ev.charger`, `ev.charger_tile`, and a PostGIS `GIST` index, then have `EvChargerService` read-through-cache instead of hitting Google on every request. This unblocks charger detail, reviews, reports, and admin verification, and it cuts provider quota burn immediately.

### Tier 2 — completes the product story

4. **Trip visibility → share links → copy → public Explore.**
   These four are one chain, and the whole Explore feature is mock data waiting on them. `TripVisibility` and `findByUserIdAndVisibility` already exist, so start with `POST /v1/trips/{id}/visibility`, then `/v1/public-trips`, then share links, then copy. Explore's client code is already shaped for it.
5. **Make Kafka real by adding one consumer.**
   There are zero `@KafkaListener` methods in the repository. The outbox and relay in User Management are correct but write into a void. Add a consumer of `user.events.v1` in Community (to keep author display names fresh) — one consumer proves the whole pattern, including `eventId` deduplication.
6. **Notifications module (`notif` schema) in Community.**
   Depends on posts and on at least one Kafka consumer. Nothing exists yet on either side.

### Tier 3 — quality and closing gaps

7. **Add a CI test gate.** `deploy-backend.yml` deploys but nothing runs `mvn test`, `next build`, or `eslint` on a PR. Add `client` scripts for `typecheck` and `test` while you are there — there is currently no test runner configured despite one test file existing.
8. **Deploy a trace backend.** The architecture mandates W3C trace propagation and sampled OTel traces; production has Prometheus + Loki + Grafana but no Tempo, so traces have nowhere to land.
9. **Give `community-service` a real `JwtDecoder` (finding F2).** It trusts `X-User-Id` with no `spring-boot-starter-security` on the classpath. That is safe only for as long as port 8084 is unreachable except through the gateway.
10. **Trip revisions/rollback, permissions/tripmates, reservations, attachments** — documented, unstarted, and the right place to stop if the capstone timeline tightens.
11. **AI Planning Service** — 0%, and the largest single remaining item. Decide explicitly whether it stays in v1 scope. If it does, the hosted-provider profile avoids the second VM entirely and is the faster path.

---

## 5. Suggested scope decision

If the capstone needs a defensible cut line, this is a coherent v1:

**Ship:** platform, auth, Trip Planning (+ garage wired, + visibility/share/copy), Mobility passthrough + charger cache, Community groups + posts/comments/votes, Explore backed by public trips.
**Defer with a written note:** AI Planning, notifications, charger reviews/reports/admin verification, trip revisions, tripmates, reservations.

That drops the four largest unstarted items while still delivering every feature the UI currently promises a user.

---

## 6. Documentation drift found during this audit

These are places where the docs describe something the code does not do. Worth fixing so the docs stay trustworthy:

| Document                                  | Claim                                                                                            | Reality                                                                                                                               |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| `README.md` §Observability             | "hosted centralized observability backend is required for the 8 GB profile"                      | Prometheus, Loki, Grafana, and Alloy are all**self-hosted** in `.deploy/compose.production.yml`                               |
| `README.md` §Repository structure      | `server/platform/…`, `server/mobility-service/`, `config-repository/`, `observability/` | Platform apps are flat under`server/`; the service is `mobility-and-ev-service`; config and observability live under `.deploy/` |
| `README.md` §Technology                | "Java 21+"                                                                                       | `.claude/rules/server/code-style.md` mandates Java 25, and the services build on it                                                 |
| `server/trip-planning-service/TODOS.md` | Lists Trip entity, DTOs, service, and controller as unchecked TODOs                              | All of it shipped several migrations ago; this file is stale and misleading                                                           |
| `docs/api/Navio Api Documentation.md`   | Documents ~40 endpoints for chargers, posts, notifications, revisions, sharing                   | Those are a specification, not an as-built record. Consider marking each section**Planned** vs **Implemented**.           |

Housekeeping: `hs_err_pid*.log` and `replay_pid*.log` (≈2.5 MB of JVM crash dumps) are sitting in the repo root and in `server/user-management-service/`. The commit rules say never commit logs — these should be deleted and covered by `.gitignore`.

---

## 7. How this report was verified

| Claim                                     | Source                                                                                                                     |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Endpoint surface per service              | `@RequestMapping`/`@*Mapping` extraction across all 15 controllers                                                     |
| Tables per schema                         | `CREATE TABLE` extraction from all 13 Flyway migrations                                                                  |
| No Kafka consumers                        | Repository-wide`@KafkaListener` search — zero matches                                                                   |
| Mobility has no persistence               | Empty`model/` and `repository/` packages; `V1__initialize_ev_schema.sql`                                             |
| Explore and community posts are mock-only | No`fetch`/`useQuery` in `app/feature/explore`; `data.ts` exports `mockCommunityPosts`, `mockCommunityComments` |
| Garage is not wired                       | No`/api/` call in `planner/planId/_components/garage/`; no vehicles proxy under `app/api/`                           |
| Production topology                       | `.deploy/compose.production.yml`, `.deploy/config/api-gateway.yml`                                                     |
| Group authorization findings              | [Navio Community Roles and Authorization](<../security/Navio%20Community%20Roles%20and%20Authorization.md>)                 |
