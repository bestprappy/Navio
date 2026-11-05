# Discovery and Saved Guides implementation

Status: implemented in isolated feature branches; new VM release pending. Custom Cover and custom categories remain on hold. Existing user checkout, uncommitted configuration and running dev:vm server were preserved.

## Implementation

Shared Plan discovery now has Trending, Recently shared, All-time popular, Seasonal and Event sections, each with six initial cards and independent Load more. Reuses SharedPlanCard and the current search API. Sorting uses real recent activity, publication time, lifetime copies/views, rating averages/counts and visible comment counts. Filters offer Seasonal/Events and supported nature/scenery, food, culture and EV evidence; all membership checks happen before ranking/counts/pagination. Country and duration alone keep the landing layout; query/theme selection uses the existing smart-search result layout. Draft filters preserve newer search edits. Stale-revision pagination resets only its affected collection and preserves user criteria.

Trending records new daily activity rather than relabeling lifetime views. It starts accumulating after release; there is no invented historical backfill. Seasonal currently uses shared month/day overlap, explicitly without weather claims. The event registry currently supports Christmas, New Year and Western Easter with affirmative owner evidence, compatible public dates and calendar rollover handling. Event tie ordering uses travel-date proximity to the event itself. Unknown unsupported facets are rejected; no speculative City facet is exposed.

Saved Guides integrates public traveler and publicly addressable curated guides with the existing bookmark button, auth, cache, covers and Saved page. Guides has a separate 50-active-item quota and joins mixed Recents/All/search/recently opened/trash/restore. Metadata is resolved on the server, ownership remains mandatory, and an unpublished guide leaves a removable bookmark. Existing guide writer, planner, Community and Admin flows were not redesigned.

Trip V28 adds daily activity. IAM V13 adds separate guide bookmark storage, with explicit guide-inclusive read opt-in. Old library responses remain PLAN/PLACE-only, and the previous released ORM validates against the new schema, including guide rows. Existing place bridge triggers and previously merged migrations were not rewritten. No new gateway route, infrastructure dependency or production fixture write.

## Verification

- Frontend: 698 tests passed, zero failures/skips. Final TypeScript, touched-file ESLint and whitespace checks passed. Production Turbopack build passed. The isolated build needed a temporary root path because its node_modules is a shared junction; that test-only configuration was restored exactly before committing.
- Trip: complete PostgreSQL-enabled suite, 650 tests, zero failures/errors; five existing opt-in/skipped tests remain excluded (My List append persistence and separate fixture-bound smart-search HTTP checks). New daily activity/idempotence, fresh migration and upgrade checks ran on actual PostgreSQL.
- IAM: complete PostgreSQL-enabled suite, 317 tests, zero failures/errors, two existing excluded checks (opt-in picture storage and application context smoke). Guide-specific integration covers server reference resolution, duplicate saves, quota, ownership, legacy opt-in, paging, trash/restore/expiry and upgrade compatibility.
- Previous released Trip and IAM ORM/schema checks passed against the new migrated disposable database; no production database was used.
- Integrated browser acceptance passed twice, including after final UI changes. Actual Next proxies, actual Trip/IAM and disposable PostgreSQL used a real encrypted synthetic test session and signed JWT. No business API mocks. Verified six-card discovery, genuine activity mutation, 409 pagination recovery and further loading, strict Events/theme/rating selection, guide card/reader saved state, Saved quota/trash/restore, unpublished-guide retention, guest401, mobile390px and light/dark layouts. No page runtime errors occurred.
- Provider imagery was not configured for synthetic test place IDs, so screenshot cards use the existing fallback. This is not a claim of full Google Maps/photo-provider integration coverage or zero provider-console warnings. Maps/provider behavior was unchanged.

## Test setup corrections

One final run started before its new disposable database was created; the reported errors were database-not-found. After readiness was explicitly verified, concurrent full suites exhausted the disposable PostgreSQL connection limit in IAM. An attempted two-connection pool was insufficient for migration startup. The successful final IAM run used normal pools, ran alone, and bounded the test context cache to two contexts. None of these test setup corrections changed application code, production settings or VM services.

## Release boundary

Code is not yet installed into the user's running dev:vm checkout or VM. Release requires changed child branches through dev/main, child-first pins and the root-main deployment after explicit approval. User configuration hash and unrelated work remain preserved. API details are in `docs/api/Shared Plan Discovery.md` and `docs/api/saved-content.md`.

Verified/pushed feature revisions: client `599ee7e` on `feat/discovery-saved-guides-20261105`, Trip `b0f6c24` on `feat/discovery-collections-20261105`, IAM `ce72041` on `feat/saved-guides-20261105`. No parent pins or main branches changed. Temporary test services were stopped; worktrees remain available for release/review. User node PID43460 remains present and its configuration hash is unchanged.
