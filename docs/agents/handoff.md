# Handoff

Current state for the next agent. Overwrite sections as they change; keep it short. History belongs in [session-log.md](session-log.md).

**Last updated:** 2026-09-26 by Codex

## Current: admin dashboard and shared-plan title release

The account dashboard, admin-managed global vehicle catalog, global activity feed, public catalog picker for members and guests, and custom shared-plan title are committed and merged through each child repository's `dev` to `main`. Root `main` is `eb00cff` (Actions run `36241742100`); its pins are client `465720e` and server `de5bd91`, with IAM `8056fb6` and trip-planning `a79a085`.

The first release (`78ea743`, run `36241081199`) passed but live public shared-plan and vehicle-model routes still returned the gateway's 404. Production config-server mounts `.deploy/config/api-gateway.yml` from the root repo, which lacked routes added to the server image's bundled development YAML. Root fix `2051204` adds those routes to the mounted file and adds deployment smoke checks for both public endpoints and the protected activity endpoint. Follow-up run `36241742100` completed successfully.

Verification: IAM 138 tests plus real PostgreSQL schema/catalog tests; trip-planning 150 tests with PostgreSQL; gateway 11 and configuration-server 1; isolated client typecheck, scoped lint, 12 admin API tests and fixture-backed Chrome workflows for account moderation, catalog draft creation, and activity. Live `/v1/shared-plans` returns 200 with a listed plan, `/explore` renders its card, and that plan's API, Explore detail, and share-link pages all return 200. Public `/v1/vehicle-models` returns three published cars; anonymous admin activity returns 401; `/health` returns 200. Invalid share tokens now return the trip service's expected 404. No live Keycloak/two-account acceptance yet.

The original `client/` worktree remains on old dirty `feat/admin-console` with concurrent Explore/planner edits. The release client was assembled from `origin/dev` in a separate clean worktree at `%TEMP%/navio-client-admin-release-20260926`, committed and merged; do not reset the original dirty worktree. Root deployment/observability edits, `docs/agents/plan-link-sharing-plan.md`, and `docs/research/` remain unstaged and were not part of this release. Agent notes were already dirty from prior sessions; this session's entry is at the top of `session-log.md`.

The sections below predate this release and are retained as historical notes. Use the current section above for deployed state.


## Latest assessment: production observability (2026-09-23)

Follow-up screenshot shows warning icons and no data in all visible metric panels. Dashboard datasource UID matches provisioning. Found likely proxy issue: Grafana location declares Upgrade/Connection headers, suppressing inheritance of server-level proxy headers including Host; this can cause Grafana origin checks to reject POST queries. Await exact panel error before attributing live failure; no proxy edit made.

User asked how Grafana and Zipkin work in production; guidance only, no deployment/application changes. Grafana public `/grafana/api/health` returns HTTP 200, database ok, version 12.3.2 when certificate verification is bypassed for diagnosis; normal Windows curl rejects the certificate chain (untrusted root). Metrics ingestion/dashboards were not authenticated or verified. Production Compose already deploys Grafana/Prometheus/Loki/Alloy and provisions dashboards. Zipkin intentionally absent; common Java env sets sampling 0.0 and export false. To enable: add internal Zipkin with bounded/persistent storage, enable export and positive sampling, set MANAGEMENT_TRACING_EXPORT_ZIPKIN_ENDPOINT=http://zipkin:9411/api/v2/spans (covers hardcoded localhost configs), provision Grafana Zipkin source, redeploy and verify cross-service traces. Both agent notes already dirty; preserved prior work and left notes uncommitted. Other active edits include gateway/config and trip publication implementation; do not include them in observability changes.

## Latest assessment: Community next step (2026-09-23)

User invoked `llm-council` for advice, not implementation. Five independent advisor passes and five anonymous peer reviews recommend a narrow milestone: publish a sanitized real saved itinerary, attach its authorized publication reference to a community post, and let a second user read it; revocation shows an unavailable attachment without breaking discussion. First define the two-account acceptance scenario and attachment/audience contract using `plan-link-sharing-plan.md`, then implement publication before community integration. Community posting broadens discovery beyond an unlisted link and needs explicit owner consent. Defer persistent copying to a follow-up; notifications follow when discussion activity warrants them. No usage or deadline evidence was supplied.

Source findings: composer selects `explorePlanSharedTrips`; feed/detail attachments call local `getTripById`; `PostService` stores `sharedTripId` without publication validation. Groups/posts/comments/votes/moderation already have API implementations. The mock copied-trip panel has no consumers found, so do not describe it as live UI. `best` and `top` share score ordering despite the "For you" label. All 20 client community API/posts/upload-proxy tests passed; no live browser/backend or Postgres checks in this assessment. Existing browser script stubs API responses. Root/client/server are `dev`, community is clean on `main`; trip-planning is `dev` with pre-existing untracked `dto/publication/` work. Coordinate before overlapping implementation. Existing dirty agent notes and unrelated application edits were preserved; notes remain uncommitted.

## Latest proposal: admin dashboard and shared vehicles (2026-09-23)

User requested a plan, not implementation. See [admin-dashboard-plan.md](admin-dashboard-plan.md): role-aware Admin sidebar (Dashboard, Users, Vehicle catalog, Activity log), reuse existing user search/suspend/reactivate APIs, verify cross-service bans, move bundled vehicle catalog into IAM persistence, preserve garage/trip snapshots, and enable published catalog selection for guests and accounts. Six delivery phases, API/data contracts and acceptance tests included. Explicit skill assignments include repository-local `.claude/skills/frontend-design/SKILL.md`, security/UI reviews and optional GSD workflows. Root/client/server remain `dev`; user-management was inspected clean on `main`. Application code unchanged. Plan and notes remain uncommitted because both agent notes already contained prior unfinished changes that cannot be committed without authorization.

## Latest proposal: publish plan as a link (2026-09-23)

User subsequently required relevant skills to be read and applied during implementation. The proposal now maps each phase to repository-local `frontend-design`, `security-review`, `anti-ai-ui-review`, and conditionally `optimization-review`, plus database/client/server/release rules. `frontend-design` was found at `.claude/skills/frontend-design/SKILL.md` and applied to a UI rehearsal covering tokens, dialog wireframe, owner/recipient tasks and interaction states. Discover skills again when executing; do not merely cite their names or restore the removed depth design. This remains planning only.

User requested an implementation review and feature plan, not implementation. See [plan-link-sharing-plan.md](plan-link-sharing-plan.md) for the current-code evidence, owner/guest/viewer permission matrix, exact dialog flow, snapshot/privacy contract, API proposal and phased verification. Recommendation: unlisted read-only published snapshot, explicit updates, owner-only link management, optional independent copying off by default, no editor invites or Explore listing in v1. Must strip saved-place anchors and their derived routes; flush pending autosave/metadata before version-bound preview/publication. Root/client/server/trip-planning are on `dev`. Application code unchanged. Both notes already had uncommitted edits; this plan and note updates remain uncommitted to avoid committing prior work without authorization.
## Committed 2026-09-23: garage and EV charger redesign (client `dev` `ffd252a`, root `dev` `bda8c20`)

Four `feat` commits on `feat/garage-ev-redesign`, merged `--no-ff` to client `dev` and pushed; root `dev` pins it through `chore(submodule)` `ed02ac2` (merge `bda8c20`). **Not on any `main`, not deployed.** 30 files, +1328/-538.

- `ac46d10` real-world range: the card leads with "Real range" (battery ÷ consumption) above the official figure, and `garage/range-efficiency-field.tsx` lets the driver enter their own full-charge range or kWh/100 km (settings form and add dialog), starting from the estimate (`estimateRealWorldRange`, `consumptionForRange` in `garage/vehicle-mappers.ts`). Battery capacity stays declared so the loss is not counted twice. Factors and sources: [docs/research/ev-range-test-standards.md](../research/ev-range-test-standards.md) — **still untracked in the root repo, see Known gaps.**
- `8c7a457` garage: featured vehicle card plus a switcher strip (`vehicle-switcher.tsx`), a draggable battery (`battery-gauge.tsx`) and in-place renaming (`vehicle-name-editor.tsx`); the Nickname field is gone. Route estimate and battery chart redesigned (Chart/Table toggle). New shared `garage/spec-tile.tsx`.
- `ddf900e` charger: one shared `StationOpeningHours` widget renders hours in the EV charger preview, station specifications and place preview — grouped day rows, each with a 24-hour track showing the open span, today highlighted. Parser is `getOpeningHoursSchedule` in `opening-hours.ts` (old `formatOpeningHours` removed). `ev-station-list-card.tsx` is rebuilt around a max-kW power tile and no longer uses stock photos. New `connector-chips.tsx`; `spec-cell.tsx` deleted in favour of `SpecTile`.
- `8bf23ba` tokens and cleanup: `--connector-*` / battery / charging-state tokens with dark equivalents in `globals.css`, dark-mode tint overrides on the block action buttons, trip member controls removed from `trip-info-card.tsx` and `planner-detail.tsx` (they were never wired to a real membership flow).

**Browser-verified this session** (Playwright against `next dev` on 3000, live Google Places/Maps, real Bangkok trip): planner renders; garage redesign correct in light, dark and at 390px; EV charger panel list cards, power tiles, connector chips and the opening-hours track all render correctly; block action button tints correct in dark. Zero console errors and zero uncaught exceptions across the whole run. The charger preview panel's dark tokens were confirmed by computed style (`bg lab(11.1%)` / `fg lab(98.6%)`) — an earlier white-panel screenshot was a repaint artifact from toggling emulated `prefers-color-scheme` after paint, not a bug. `tsc --noEmit` and ESLint both clean on the committed tree, including the six new files.

Still unverified in a browser: authenticated flows (catalog picker, save-to-garage), the battery route chart with real leg distances, drag interaction on the battery gauge, and keyboard-only dialog traversal.

## Latest assessment: EV simulation proposal

User requested validation and an adoption recommendation, not implementation. See [ev-simulation-proposal-review.md](ev-simulation-proposal-review.md). Recommendation: adopt the simulation research scope and extend existing planner; first align frontend/backend energy and charging calculations, then add a bounded route-aware model and independent evaluation. Review identifies capacity/consumption boundary issues, synthetic speed assumptions, circular validation, approximate detours, and incorrect section 24 SOC arithmetic. No application changes or experiments. Root is on `main`, client on `feat/ui-reworked`, server on `main`; existing UI changes remain. Both agent notes already contained uncommitted work at session start, so notes were updated but not committed without authorization to include that prior work.

## Latest release: dashboard, brand theme, planner redesigns, country-first titles

On 2026-09-15 all previously uncommitted client work and the trip-planning-service title change were committed, merged to `dev` and `main`, and released via root `main`. Check the deploy run for the root release commit before assuming it is live (see [release.md](release.md)).

- **client** `main` = `4622b54` (four stacked commits over `19e7bf1`):
  - `44386d8` chore(deps): `flag-icons`, `@google/design.md`, and the Next.js-generated `client/AGENTS.md`.
  - `279dfac` docs(design): `client/DESIGN.md`. It mirrors `globals.css`, which stays the source of truth; update both together. Lint with `npx -p @google/design.md designmd lint DESIGN.md` from `client/`. Known contrast warnings: light primary with Paper text (3.27:1), dark destructive with white text (3.76:1).
  - `406468c` style(planner): brand theme tokens (`--brand-paper`, `--brand-pine` which now holds navy, blue-gray neutrals, single neutral color theme), token swaps for hardcoded colors (scrim, on-media, map pin, rating, tag, note, checklist, premade), battery tokens and `.battery-*` utilities, garage card / Trip energy redesign, charging stop card and boxless route leg rows, shared `garage/route-estimate.tsx`, block-scoped `--primary` in `TripBlock.Root`, blurred garage photo backdrop, sidebar active state on `--sidebar-accent`.
  - `4622b54` feat(dashboard): `/dashboard` route (`/planner` redirects there), dashboard with upcoming/past trips and explore previews, trip delete menu (`trip-actions-menu.tsx`, `use-delete-trip.ts`, `deleteTrip`), sidebar redesign with profile menu, trip list and recent-plan blocks, guest welcome prompt, sign-in callbacks default to `/dashboard`, trip-list invalidation after creation, `withDefaultTripTitle` on the client.
- **trip-planning-service** `main` = `fde94e0`: `TripResponse.getTitle()` is now name -> country -> city (was name -> city -> country). Client `withDefaultTripTitle` applies the same order.
- The split between style and feat commits is by file; some files carry both kinds of change, and intermediate commits were not type-checked on their own (only the final tree).

Do not make the delete hook refetch `["planner", tripId]`: a 404 there makes `PlannerPersistence` create the trip again.

## Reverted: depth rework (2026-09-22)

The user asked to return the UI to `main` with no 3D depth. All depth work was removed from the client working tree (`app/depth.css` deleted, 26 files restored to `main`, `surface-*` classes removed from `route-estimate.tsx` and `vehicle-usage-overview.tsx`). A backup is in client `git stash` as `backup: depth rework before revert 2026-09-22`. Do not reapply it unless asked.

## Released 2026-09-22: EV planner rework (root `main` `28b6d7e`)

Client `main` `7dee312`, server `main` `cdcd736`, mobility `main` `eb72b37`. Includes everything in the section below. **Live:** deploy run 35700267438 succeeded (all jobs); after the deploy `/health` returned 200, `/v1/trips` 401, and `/` 200. The whole flow was never checked in the real planner with live routes.

- **Production bug found after release: "Plan charging stops" failed.** trip-planning built the mobility route from the day's block items only, ignoring the day's start and end anchors. A day with one place between its anchors was rejected with 422 ("could not be optimized"), and other days were optimized on a different route from the one the planner displays. **Fixed on `dev`, not deployed:** trip-planning `c6d5b8c` (resolves anchors like the client's `resolveDayAnchors`: own anchor, else the previous day's end; sends them as `<blockClientId>:start/:end` stops; the applier appends chargers planned before `:end`; limit of 25 stops; logs mobility's status and body on failure), server `dev` `1657da2`, client `dev` `a4ab4b1` (shows the 422 `error` detail). trip-planning tests: 48/50 pass with a local config server; the 2 full-context tests need Postgres on 5432 (Docker was not running). The earlier "temporarily unavailable" 503 (14:49:58) has no recorded cause; mobility logged nothing, so it was probably a silent mobility 400. The new logging will show it if it recurs.
- **Open question for the user:** the "Charge each stop to" slider (`chargeStopTargetPctAtom`) is almost meaningless now. The backend optimizer already tries every 5% target up to 92% and picks the fastest; the slider only adds one more candidate. The user was offered its removal and has not answered yet.

## EV energy simulation work (history; now on `main`)

- **client** `feat/ev-simulation` = `9ae6f5a` (pushed; cut from `main` = `dev` = `4622b54`). Codex's simulation model, panel and shared constants, plus the real-world range factor restored in `vehicle-mappers.ts` (NEDC/CLTC 0.7, WLTP 0.85, EPA 0.9) as a documented calibration assumption.
- **mobility-and-ev-service** `feat/ev-simulation` = `eb72b37` (pushed). Codex's backend part, previously unlogged: `simulation/model-v1.json` (same constants as the client JSON; no automated parity check), `EvSimulationModel`, `OptimizedRouteVerifier`, optimizer changes. `./mvnw -o test` passed.
- Merged (fast-forward) to `dev` in client and mobility. Server `dev` = `cdcd736` pins mobility `eb72b37`; root `dev` pins client `9ae6f5a` and server `cdcd736`. **Not on any `main`, not deployed.** Releasing requires the `release.md` flow (child `main`s first, then root `main`).
- Agreed next steps (LLM council, 2026-09-22): the chart and itinerary share one energy source, with the backend as the source of truth; an "Arrive with at least __%" setting passed to the optimizer; a battery-along-route chart; move `EnergySimulationPanel` out of the garage to a reachable `/research/energy` route; no driving-conditions preset; an evaluation against public reference data with elevation, with error measured by charging decisions.
- Not browser-checked.
- **Energy-path map (2026-09-22, Claude):** displayed SOC comes from client `projectTripCharging` (routed legs, shared constants), which does the same arithmetic as backend `OptimizedRouteVerifier`, so the display already agrees with the backend. The real split is **two stop planners in the EV side panel**: client `planAutoEvChargers` ("Auto add chargers": straight-line distance × road factor, comfort top-ups; works for guests) and backend preview/apply ("Optimize the whole EV route": saved trips only). **Resolved (user chose backend only):** client `dev` `eb8c757` removes `planAutoEvChargers` and `autoAddEvChargersToBlockAtom`. The EV panel has a single "Plan charging stops" action (backend preview/apply) that sends `AUTO_MIN_ARRIVAL_PCT` as reserve and the day's projected start SOC. Guests can no longer auto-plan stops; they are asked to sign in and save the trip, and can still add stations by hand. Root `dev` `257734d` pins it. Not browser-checked.
- **Arrival reserve (client `dev` `4d6a90e`):** `arrivalReservePctAtom` in `garage.atoms.ts` (options 10/12/15/20, `atomWithStorage` key `navio:arrival-reserve-pct`, defaults to the model's 12). Set by `ArrivalReserveControl` in the EV panel's charging preferences. Read by the optimizer payload, the reserve lines in `route-estimate`/`vehicle-usage-overview`, and `getBatteryTone(pct, reservePct)` (the second argument is now required). Per browser, not saved to the account. `route-estimate.tsx` and `charge-segment-info.tsx` became client components.
- **Battery chart (client `dev` `9bd8ccb`):** `garage/battery-route-chart.tsx` in `RouteEstimate` (replaces the day-end bar when the day has distance). Data is the new `DayEvProjection.profile` (per-stop cumulative km, arrival/departure) from `projectTripCharging`. Checked visually in light and dark mode with a temporary preview page (deleted). Not yet checked inside the real planner with live routes. Note: `projectTripCharging` clamps SOC at 0, so an energy deficit plots as 0%.
- **Panel removed (client `dev` `7dee312`):** the user decided the garage's Energy simulation panel isn't needed, not even as a `/research/energy` page. `energy-simulation.ts` (physics model) and `tests/simulation/reference-v1.json` stay for an offline evaluation script.
- **Council 2026-09-22 (calibration):** the recommended order is a browser check, then the evaluation (Thai routes × cars against published real-world data, thresholds fixed first, ±15% consumption sensitivity on whether the stops change), then sourced per-model consumption and usable kWh, HVAC as kW × route hours, and LFP/NMC charge curves. Test-cycle factors become a cited fallback only. Details are in the session log. Nothing implemented.
- **Remaining council step:** the evaluation harness (a script over fixed routes and cars, with elevation and public reference data, reporting energy error and changed charging decisions). Superseded plan, kept for history: move `EnergySimulationPanel` to `/research/energy`; the evaluation harness.

## Live in production (before this release)

Root `0a4acc4` (deploy run 34829001804, success).

- **Structured trip location.** Trips store `destinationCity`, `destinationRegion`, `destinationCountryCode`, and `destinationCountry`, resolved server-side from `destinationId` through mobility-and-ev-service. `displayName` is optional; responses include a derived `title` (name -> country -> city after this release). Clients send only `destinationId` (plus dates/name).
- Copying a premade plan resolves a place id from the destination name before creating the trip (`resolveDestinationPlaceId` in `client/app/feature/planner/_components/destination-api.ts`).
- Trip country backfill completed 2026-09-15 (backup on VM: `/home/adminnav/navio-maintenance/flags-2026-09-15/trip-before-backfill.sql`); zero null country codes at verification. The runner stays disabled by default.

## Shared agent context and CI

- `AGENTS.md` (committed; Codex loads it, Claude loads it via local `CLAUDE.md` = `@AGENTS.md`) and `docs/agents/*`. Every session must update this file and the session log.
- `PostgresSchemaTests` in all four JPA services plus the `verify-database-schema` job in `deploy-backend.yml` must pass before images build.

## Known gaps

- **Left uncommitted in the root repo on purpose (2026-09-23):** `docs/agents/admin-dashboard-plan.md`, `docs/agents/plan-link-sharing-plan.md`, `docs/research/` (including `ev-range-test-standards.md`, which the garage work cites), `.deploy/compose.production.yml`, `.deploy/nginx/navio.conf`, `.deploy/observability/*`, `grafana/dashboards/navio-overview.json`, and a dirty `server` submodule working tree. These belong to earlier Codex sessions; per AGENTS.md §1.3 they were not committed or discarded. Whoever owns them should commit them.
- `client/CLAUDE.md` is **not** in `client/.gitignore`, so it shows as untracked on every client session and must be excluded by hand. Adding it to `.gitignore` would remove the footgun.
- None of the released client UI work was checked end to end in a real browser session with the backend: theme in both modes, dashboard, delete trip, sidebar recent plan, charging slider thumb alignment and drag-and-drop, narrow widths.
- `components/theme/*` is committed but unused (color theme picker unwired).
- `components/profile/settings-sidebar.tsx` has `href="/dashboard"className=` with no space (compiles, cosmetic).
- ESLint warnings: unused `tripDateLabel` in `empty-itinerary-callout.tsx`, unused `RouteSegmentStatus` in `planner-map-google.tsx`.
- trip-planning-service `@SpringBootTest` and `@WebMvcTest` tests need the configuration server on port 8888; the two full-context tests also need Postgres on 5432 (no test `application.yml`).
- user-management-service full-context test is `@Disabled` (needs Keycloak); mobility and community default tests run on H2.
- Premade-plan copy resolves the destination by name; not tested in a browser yet.
- `docs/api/Navio Open API.yaml` trip schemas describe a planned design and do not match the current trip DTOs; `title` order change is not documented there.

## Next steps

1. Confirm the deploy run for the root release succeeded and production is healthy.
2. Browser-check the released client work (see Known gaps).
3. The user plans to add hardcoded colors and have an agent convert them into theme tokens; decide whether to darken light `--primary` for contrast.
