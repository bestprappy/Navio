# Places discovery

Implemented locally on 2026-10-15. Application source is uncommitted on client/server/mobility `feat/places-discovery` and trip `feat/places-list-append`.

## Current search and presentation rework (2026-10-15)

This section supersedes the initial city-only frontend behavior described below; legacy city API/read links remain compatible. Approved design: `docs/superpowers/specs/2026-10-15-places-search-design.md`; implementation record: `docs/superpowers/plans/2026-10-15-places-search.md`.

- Toolbar: searchable Country (249 ISO countries/territories, Any country), submitted Search places with debounced provider/Navio suggestions, Filters with separate multi-select Interests and Place types and Apply/Cancel, and exclusive Month & season with Any time, Months and Seasons. Clear labels, wrapping chips, common field heights, restrained surfaces and consistent card geometry. Filters become a sheet below 640px.
- Country/time alone retain discovery sections; interests alone select sections. Search or any place type switches to Recommendations and Matching places. Country/type/interest groups intersect, while selections within each group are OR. Geography predictions submit searches rather than opening a country/city as a place card.
- Country locks use structured countryCode evidence. Time only influences supported regional discovery/recommendations, never excludes ordinary results by itself. Japanese temperate main-island season/calendar preferences and existing Thai city profiles are supported; unknown regions/seasons show a clear notice. Any time disables seasonal preference. No forecast, flowers/snow/events or global coverage claims.
- Recommendation eligibility: first provider page, rating at least4.5, at least50 reviews, matching scope/filters and not permanently closed. Provider relevance takes precedence, then supported time preference/Bayesian quality. Capacity five responsive rows; minimum two rows of strong candidates, otherwise keep them in normal matches. Partitioning never loses/duplicates items on paging/resize; later pages do not refill recommendations.
- With Any country and no query/type, prompt for country/search instead of presenting an IP-biased pool as global discovery. Broad searches remain provider-bounded, not an exhaustive world directory.
- Added public GET `/v1/geo/places/explore` and `/v1/geo/places/explore/suggestions`, with narrow Next proxies and gateway rules. Explore query: country, query, repeated interest/type, time, collection, optional legacy destination, cursor. Response: items (existing reader/attribution envelope), recommendationIds, cursor, mode, seasonalNotice, seasonalSources. Suggestions: items with kind/label/value/placeId/interest and providerAvailable.
- Provider text-search streams merge fairly with at most two calls per request; photo media resolves only returned items. Opaque UUID cursors bind the complete query, expire after ten minutes, hold only tokens/IDs/query state, and are bounded to256 entries. Existing rate/concurrency limits, no-store and cancellation remain. Expired continuation offers Start search again.
- Validation:16 client +33 Mobility +8 gateway tests pass, scoped lint/full TypeScript/Places-enabled production build pass. Live Next/Gateway search and suggestions succeed; Osaka sushi returned24 verified JP places, nine strong candidates; a continuation returned24 with zero duplicates. JP Autumn scenic discovery stayed in discovery mode with one climate source. Real response passed client Zod validation; temporary provider-content snapshot was removed.
- Fresh review findings on sparse pagination, type-stream ordering and legacy time edits were fixed. No production rollout, source commit, migration, account/data reset or broad restart. Selective local Mobility/Gateway reload only, prior logs backed up under output/places-search-runtime-before.
- Still open: browser tools expose no available browser; no mobile/tablet/desktop screenshots, actual filter/keyboard interactions or new live My List save/reopen verification. Do not claim glitch-free visual completion. Existing Trip append tests/implementation remain preserved.

## Initial city-only behavior (historical baseline)

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
