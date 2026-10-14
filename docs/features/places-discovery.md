# Places discovery

Implemented locally on 2026-10-15. Application source is uncommitted on client/server/mobility `feat/places-discovery` and trip `feat/places-list-append`.

## Behavior

Explore has URL-backed Plans, Guides, and Places navigation. The tabs stay below the site header; each introduction and search area scrolls. Plans and Guides retain separate in-memory search text. New search algorithms are deferred. Places uses destination/month selection and the existing destination lookup, not a new search engine.

Places offers seasonal, popular, hidden-gem, worth-a-visit, scenic, food, and activity collections. Each collection loads four cards, with bounded pagination up to the provider's 20-result candidate pool. Empty evidence-dependent collections are omitted. A collection request failure remains an error with retry rather than fabricated recommendations.

Popular preserves Google's POPULARITY order. Other collections use Bayesian ratings `(v*R + m*C)/(v+m)` where C is the rated candidate mean and m the median review count. Hidden gems require rating >=4.3, reviews >=20, and reviews below the candidate median. Unrated places sort after rated candidates; they are never interpreted as zero-star ratings. Permanently closed places and duplicate provider IDs are excluded. This does not represent recent trends or prove quietness, exclusivity, or universal quality.

Seasonal profiles apply only to coordinate-matched Bangkok, Chiang Mai, Phuket, Krabi, and Samui. TMD regional climate guidance informs indoor/outdoor suggestions. These are typical seasonal conditions, not forecasts, event calendars, safety advice, or guaranteed opening conditions. Unknown destinations retain ordinary discovery without a seasonal claim. Source: https://tmd.go.th/info/ภูมิอากาศของประเทศไทย-หน้า-2.

Place readers use a full-height split information/map workspace from 1024px. Below that, Place/Map controls switch panes. The divider supports pointer and keyboard resizing, bounded35–60% and double-click reset45%. Resize observation recenters the Google map after size/visibility changes. Provider summaries remain unmodified; missing information is omitted or clearly marked. Photographer credit, source-photo links, and official unmodified Google Maps attribution assets accompany provider content.

## APIs

- `GET /v1/geo/places/discovery`: destination, lat, lng, month1–12, collection, page0–19, size1–12. Returns `{items:[{place,reason,businessStatus,photoAttributions,photoGoogleMapsUri}],hasMore,seasonal}`.
- `GET /v1/geo/places/{id}/reader`: same item envelope, nullable reason, live provider details.
- `POST /v1/trips/{tripId}/planner/my-list/places`: `{providerPlaceId,provider?:"GOOGLE",listBlockId?,expectedVersion}`. Returns `{blockId,itemId,version,alreadyAdded}`.

The browser proxies discovery/reader through Mobility and append through the existing authenticated Trip proxy. Gateway permits only the new public GET paths. Ownership is enforced in Trip Planning before resolving a place. A missing list is created; multiple lists require explicit selection. Dedupe is scoped to the chosen list. Snapshot saves and narrow appends acquire the trip row lock before child rows. Append checks version before writing; client refreshes and retries409 once. No entity/schema/migration changes.

Planner Explore all flushes autosave before navigating with an explicit `plan` query parameter. No last-opened trip is silently targeted. Account-scoped queries validate the connected plan; signed-out visitors must sign in to add. Unconnected visitors explicitly select a plan. Saved statuses synchronize across matching cards; server acknowledgement is required before success. Only reference IDs/UI acknowledgement and navigation state remain in memory; no persistent Google photo/content mirror was added. The existing provider detail DTO lacks closure status, so append cannot independently recheck closure; reader disables adding permanently closed places and discovery excludes them.

## Request controls and rollout

Google discovery uses one bounded candidate request per collection, minimal existing search fields plus business/photo metadata, then resolves photo media only for visible page cards. Rich details load only when the reader opens. No provider result cache was added. The browser limits Places requests to2 concurrently and removes cancelled queued work. Backend discovery/reader share a per-instance request budget, default60/minute and max4 concurrent requests, returning429 before a provider call when exceeded. Configure `navio.discovery.requests-per-minute` and `navio.discovery.max-concurrent` in YAML. This is an instance budget, not a distributed per-user quota.

Places is enabled by default in `next dev` unless `NEXT_PUBLIC_PLACES_ENABLED=false`. Production builds require `NEXT_PUBLIC_PLACES_ENABLED=true`. This is a frontend rollout flag, not endpoint authorization. Restart/rebuild Mobility, Trip Planning, and Gateway before live preview; the current source cannot add these endpoints to already-running old services. Existing environment values were not changed. Provider API keys and billing must already be configured.

Official attribution files in client/public/attribution came unchanged from Google's attribution archive: https://developers.google.com/static/maps/documentation/images/Google_Maps_Attribution_Assets.zip.

## Verification and remaining review gate

-12 client tests pass, including response validation, dangerous-link rejection, request cancellation/concurrency, existing planner carousel behavior, and sidebar navigation. Scoped ESLint and TypeScript pass. Production build with Places enabled passes.
-19 Mobility tests pass: ranking, closure/deduplication, seasonal bounds, provider fields/attribution, HTTP contracts/failures, rate and concurrency budgets.
-29 Trip tests pass: append service/controller and existing snapshot service checks.7 gateway security tests pass.
-3 real PostgreSQL concurrency tests are present but skipped: Docker Desktop engine is unavailable and `NAVIO_APPEND_TEST_DB_URL` is absent. Run them against a disposable PostgreSQL database with `NAVIO_TEST_DB_USERNAME`/`NAVIO_TEST_DB_PASSWORD`.
- Browser automation cannot initialize its Node runtime (OS error3). Actual mobile/tablet/desktop light/dark screenshots, keyboard interaction, map resize, back-scroll restoration, and end-to-end add/save/reopen remain unverified. Do not enable production until these are exercised against the rebuilt local stack.

No push, main merge, production deployment, shared service restart, account change, or database mutation was performed.
