# Places Release 2 handoff

Prepared 2026-11-16 for the next maintainer and their coding agent. This document is self-contained; do not assume access to the conversation that produced Release 1.

## Status 2026-11-16: RELEASED switched off (root `50811fb`, run 43763256389)

Shipped to production with both switches off; behaviour is Release 1 plus the corrected footer and Saved links until the owner enables it (see "To enable" below).

### Implementation record

The owner chose **option 1 (catalogue + explicit search)** and **"ship disabled for now"**: build and test everything, keep the paid path off until a spend ceiling and Google Cloud daily quotas exist. Everything below is on `dev` only; root `main` was not touched.

| Repo | Commit | Merge on dev |
| --- | --- | --- |
| Mobility | `909e65e` feat(places): add explicit bounded Google place search | `a6dbeb9` |
| server pin | `19dea02` | `b64efd2` |
| client | `0b7008a` feat(places): add explicit Search beyond Navio's catalogue | `3e778c6` |
| root | pins on `chore/places-release-2-pins`; OpenAPI + these docs on `docs/places-release-2` | root `dev` |

What exists:

- **Backend** `GET /v1/geo/place-searches` (`PlaceProviderSearchController` / `PlaceProviderSearchService` / `GooglePlacesAdapter.providerSearch`). Deliberately outside `/v1/geo/places/**` because the gateway lets guests read `/v1/geo/places/{placeId}`; this path falls under the gateway's deny-by-default rule, and the service refuses a missing `X-User-Id` again (401). One Text Search call per request, Pro-tier field mask (id, name, address, location, type, address components, `googleMapsUri`; no photos, ratings, hours, editorial), page size 10, max 3 pages via a stateless `"<page>.<token>"` cursor, no fallback query, no retry. Guards in order: switch -> identity -> input -> 20/min + 2 concurrent per instance -> 10 per user + 30 total per billing day per instance (in memory) -> monthly `PLACES_TEXT_SEARCH` meter (exhaustion becomes 429 "month", not an outage). Items claiming `NAVIO:` are dropped. `no-store`, nothing cached.
- **Switches.** Mobility `navio.places.provider-search.enabled: ${NAVIO_PLACES_PROVIDER_SEARCH_ENABLED:false}` (separate from `navio.discovery.enabled`, which stays false). Client `NEXT_PUBLIC_PLACES_PROVIDER_SEARCH=true` shows the panel (build-time). Both default off, so a release with no env change ships Release 1 behaviour plus the corrected footer and Saved links.
- **Client.** `ProviderSearch` compound (`provider-search.tsx`), `ProviderPlaceCard`, `provider-search-api.ts`, BFF `app/api/geo/place-searches/route.ts` (validates before proxying; not in `isPublicPlannerRequest`). The panel renders under catalogue *results* only (query of 2-120 chars). Only the button press (signed in, via `requireAuth`) enables the TanStack query: `retry: false`, no refetch on focus/reconnect/mount, `gcTime: 0`, keyed by query+country so a new search starts unrequested and the old one aborts. Text cards, no photo area; Google Maps attribution logo under results; links go to the result's `googleMapsUri` (free). Save and Add to Plan keep the raw Google ID (`google:<id>` saved identity; My List `provider: GOOGLE`).
- **Saved fix.** `savedPlaceDestination`: only `NAVIO:` places open the catalogue reader; Google places open Google Maps (they previously hit the reader's 404).

Terms decision (checked 2026-11-16; re-check before enabling): Navio stores no search results. Google allows place IDs to be stored indefinitely; coordinates may be cached up to 30 days. Save / Add to Plan store name, address and coordinates exactly as the planner's existing Google search already does; that pre-existing retention is NOT solved by Release 2 and needs an owner/legal decision before scale.

**To enable (owner decision required):** set a monthly/daily ceiling; configure Google Cloud daily quotas for Text Search (Pro/Enterprise); snapshot `/admin/google-usage`; set `NAVIO_PLACES_PROVIDER_SEARCH_ENABLED=true` on Mobility and `NEXT_PUBLIC_PLACES_PROVIDER_SEARCH=true` for the client build; release per `release.md`; run one authorized canary search and confirm the `PLACES_TEXT_SEARCH` counter moved by exactly one per press.

Known follow-ups: (1) a Google place in Saved, My List or a Shared Plan still lazy-loads one cached Place Details + photo when shown (existing planner path, `ReaderStopPhoto`/`usePlaceDetails`); more saved Google places means more of those calls. (2) Daily limits are per instance and reset on restart; Cloud quotas are the real ceiling. (3) Add to Plan from a Google result was not driven end to end in a browser (payload code path is the existing one).

## Authority and decision boundary

The owner asked a friend to take over and "do Release 2." Treat that as authorization to own the phase, implement it, and use Navio's normal release process once its acceptance checks pass. It is not an unlimited provider-spend authorization and it does not define a billing ceiling.

The repository never recorded one final Release 2 product specification. It records Release 2 as expanding Places coverage and/or restoring a paid Google Places lookup path. Before implementation, confirm which of these the owner wants:

1. **Recommended default:** keep the free Navio catalogue as the normal experience and add an explicit user action such as **Search beyond Navio's catalogue**. Only that action may start paid provider search.
2. Expand the fixed, source-tracked Navio catalogue without runtime provider lookup.
3. Restore provider-backed discovery automatically. This is the highest-cost option and must not be inferred from "Release 2" alone.

If the owner is unavailable, use option 1 as the design proposal but do not enable paid production calls until a concrete monthly/daily spend ceiling and Google Cloud quota are confirmed. Never silently fall back to Google merely because the local catalogue has no result.

## What is already live

Release 1 is complete and must not be re-released as new work:

- First catalogue release: root `1b31aa02d8bca69a286c0df0bf5a030f758568e2`, client `076b47c89774562d8b92233b3f07491e310a77f8`, Actions run `43685663127` succeeded.
- It serves ten Bangkok venues from a fixed Navio-owned snapshot with independently sourced descriptions, approximate coordinates, official reference links, and bundled licensed Wikimedia Commons photos.
- Explore discovery, suggestions, place reader and catalogue details are local. The legacy provider discovery BFF returns `410`. Unknown `NAVIO:` identities fail closed and are never converted into provider requests.
- Saved Location, My List, itinerary JSON and public Shared Plan readers preserve the canonical `NAVIO:` identity and resolve it locally.
- Release verification passed 833 client tests, TypeScript, the exact production build, eight browser fixtures and 28 read-only live checks. Those checks made no provider requests or production account writes.
- Live signed-in Save -> reopen -> Add to Plan -> reload -> publish was not exercised against a real production account. Automated payload, state, serialization and public-reader coverage passed.

Release 1 intentionally does **not** promise worldwide coverage, current opening hours, live ratings, continuous editorial maintenance, or zero total Google Maps cost. Maps, routes, EV charging and legacy provider-backed places are separate consumers.

## Start from current remote state, not the ordinary checkouts

The ordinary local worktrees are old and dirty. Do not reset them, commit their unrelated files, or use their submodule pins as a release baseline. At handoff time the verified remote refs were:

| Repository | `origin/dev` = `origin/main` |
| --- | --- |
| root | `ec9f3269c23372e78fd56881279a2ab460a9730b` |
| client | `45c390e762b3c92e6887100dadadb5f272e704ea` |
| server | `bf776108c4e535b36f564b7a991d843c0a12c525` |
| IAM | `a0cb118adbf52ec6cd49712c265019ea5a3b7dba` |
| Trip | `868c374c653f14959a04dc5623bee89bfc4aa2db` |
| Mobility | `8cc53d1cdac2330402082d31faa8bbe519c101ec` |
| Community | `8b46397fa2b6a5dcda3c6db4903ce3dcf4099ea1` |

Fetch again and verify these before work; they are evidence from 2026-11-16, not permanent pins. Prefer fresh linked worktrees from the latest `origin/dev`. The ordinary root checkout was 94 commits behind `origin/dev`; client was 30 behind and had a user `tsconfig.json` edit plus `CLAUDE.md`; server was 29 behind; Mobility and Community had untracked logs. Preserve all of that.

## Existing implementation entry points

Client Release 1:

- `client/app/feature/explore/places/catalogue.data.ts` — the ten source-tracked records and photo licences.
- `client/app/feature/explore/places/catalogue.ts` — canonical IDs, local search/suggestions/details and Saved Location mapping.
- `client/app/api/geo/places/explore/route.ts` and `explore/suggestions/route.ts` — catalogue-only BFF routes.
- `client/app/api/geo/places/discovery/route.ts` — intentionally returns `410`.
- `client/app/api/geo/places/[providerPlaceId]/route.ts` and `reader/route.ts` — local catalogue resolution/fail-closed behavior.
- `client/app/feature/planner/planId/_components/place/use-place-details.ts` and Shared Plan reader place data — local resolution after save/reload/publication.
- `client/tests/explore/places-catalogue*.test.mjs` — Release 1 contract and journey coverage.

Existing paid backend path (currently disabled):

- `server/mobility-and-ev-service/src/main/resources/application.yml` sets `navio.discovery.enabled: false` and says not to enable it without a cache and Google Cloud daily quota. It was disabled after uncached photo lookup exceeded the free tier.
- `PlaceExploreController`, `PlaceExploreService` and `GooglePlacesAdapter` already contain provider search, suggestions, detail and photo behavior.
- `DiscoveryRequestLimiter` is only a per-instance limiter (currently 60 requests/minute, 4 concurrent), not a global billing boundary.
- `GoogleFreeTierBudget` and `ev.provider_monthly_usage` enforce per-SKU monthly limits and fail closed when accounting is unavailable. `GoogleUsageMeter` defaults are approximately 5% below published free-tier buckets. An admin override can ignore limits for a month; Release 2 must not depend on that override.
- The current provider explore service can make up to two search calls per request and then enrich returned items with photos. Its continuation state is process-local and provider content is not cached. Simply changing `enabled` to `true` is not a complete or safe Release 2.

## Recommended Release 2 contract

Unless the owner deliberately chooses another option, implement a catalogue-first hybrid:

- Keep the existing catalogue landing shelves, local search and local suggestions free and deterministic.
- Show an explicit provider-search action only after a meaningful query/destination and explain that results come from Google. Do not start provider requests on page load, shelf visibility, empty local results, hover or focus.
- Debounce/cancel user-initiated suggestions and search. Bound provider calls, page depth, concurrency and retries. A failed, busy or exhausted provider leaves the local catalogue usable.
- Keep `NAVIO:` identities local and fail closed. Keep Google/provider identities distinct; do not rewrite one namespace into another.
- Preserve source/attribution, identity, coordinates and any allowed provider fields through Saved, My List, itinerary reload and Shared Plan publication. Do not claim a bundled Navio photo is a live provider photo or vice versa.
- Label local editorial ordering honestly. Do not add long-form Places articles: `[DEFERRED][EXCLUDE_FROM_REPORT] PLACES_EDITORIAL` remains disabled and excluded.
- Do not call the experience worldwide or complete. Coverage and freshness must be visible.
- Count Places search, autocomplete, detail and photo separately from Maps, Routes and EV calls.

Before storing or caching Google content, re-check the current Google Maps Platform terms and decide exactly which fields may be cached, for how long, and with which attribution. A safe design may cache only Navio state/opaque continuation data and let provider responses remain transient. Document the decision and tests.

## Cost and operational prerequisites

Do not enable the paid path in production until all are true:

- The owner states an acceptable monthly/daily ceiling or confirms that the existing per-SKU limits are the ceiling.
- Google Cloud daily quotas are configured for every Places SKU Release 2 can call. Repository monthly counters are defense in depth, not a substitute for cloud billing controls.
- The normal server/browser keys remain separate and restricted to their required APIs/origins.
- `/admin/google-usage` or the corresponding admin API shows current counts and limits, and a before-release snapshot is recorded.
- Quota exhausted, counter database unavailable, 429, provider 4xx/5xx, timeout and circuit-open paths are visibly graceful and make no unbounded retry loop.
- Photo behavior is deliberately budgeted. Do not restore eager photo/gallery fetching across shelves.

## Implementation and verification sequence

1. Re-read root `AGENTS.md`, `client/AGENTS.md`, `docs/agents/release.md`, and this handoff. Verify every repository/changed service status.
2. Confirm the Release 2 option and spend boundary with the owner. Record the decision in the plan before coding.
3. Write failing tests for the chosen boundary. At minimum cover: no automatic provider call, the explicit paid action, request debouncing/cancellation, page/call bounds, quota exhaustion, local fallback, canonical IDs, unknown local-ID denial, attribution, Saved/My List reload and public reader.
4. Implement on feature branches from fresh `origin/dev`. If Mobility changes, test it independently before pinning `server`; if only client changes, do not bump backend pins unnecessarily.
5. Run the full touched suites. For client: full tests, TypeScript, scoped lint and an exact committed production build. For Mobility: full `./mvnw -o test`; run real PostgreSQL schema/startup checks if entity, migration, usage accounting or configuration binding changes. No schema change is expected merely to expose a bounded lookup.
6. Browser-check desktop/mobile, light/dark, keyboard access, local catalogue, explicit provider search, provider error/exhaustion, Save, Add to Plan, reload and Shared Plan. Intercept provider traffic for deterministic tests and assert exact call counts. A controlled real-provider canary comes only after quotas and spend approval.
7. Run a fresh review focused on hidden provider calls, identity mixing, missing attribution, retries and rollout/rollback compatibility.
8. Release child-first under `docs/agents/release.md`: changed service feature -> `dev` -> `main`; server pins -> `dev` -> `main`; client -> `dev` -> `main`; root pins -> `dev` -> `main`. The root `main` push deploys every service.
9. Monitor the workflow through revision checks, real PostgreSQL schema checks, all image builds and VM deployment. Do not rerun a failed deployment without diagnosing it.
10. Post-release, verify health/protected routes, free catalogue behavior, one explicitly authorized provider canary, provider error handling, canonical detail/reader routes and usage-meter increments by SKU. If a production account is available and the owner authorizes mutation, verify Save -> reopen -> Add to Plan -> reload -> publish. Otherwise state that signed-in persistence remains unverified.

## Acceptance criteria

Release 2 is complete only when:

- Release 1 still works without provider access.
- Paid calls happen only inside the approved interaction boundary and stay within measured limits.
- Local and provider identities survive every supported save/publish path without collision.
- Credits/attribution remain present, readable and tied to the correct content source.
- Provider outage or quota exhaustion degrades to a useful catalogue experience.
- Test/build/schema evidence is recorded against exact committed revisions.
- Child/main pins equal their remote `main` revisions before the root release.
- The deployment run succeeds and the production smoke results, provider-call counts and remaining verification limits are logged.

## Do not fold in unrelated work

Release 2 is not permission to revive long-form Places editorial, change Maps/Routes/EV billing policy, mutate maintained Team sample plans, re-enable old discovery wholesale, or release unrelated dev-only features. Preserve newer concurrent work already on remote `dev/main`; never reset or force-push to make the old Release 1 branch look current.
