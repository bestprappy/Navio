# Handoff

Current state for the next agent. Overwrite sections as they change; keep it short. History belongs in [session-log.md](session-log.md).

**Last updated:** 2026-09-22 by Claude

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

## In progress: EV energy simulation (committed on `feat/ev-simulation`, not merged)

- **client** `feat/ev-simulation` = `9ae6f5a` (pushed; cut from `main` = `dev` = `4622b54`). Codex's simulation model, panel and shared constants, plus the real-world range factor restored in `vehicle-mappers.ts` (NEDC/CLTC 0.7, WLTP 0.85, EPA 0.9) as a documented calibration assumption.
- **mobility-and-ev-service** `feat/ev-simulation` = `eb72b37` (pushed). Codex's backend part, previously unlogged: `simulation/model-v1.json` (same constants as the client JSON; no automated parity check), `EvSimulationModel`, `OptimizedRouteVerifier`, optimizer changes. `./mvnw -o test` passed.
- Merged (fast-forward) to `dev` in client and mobility. Server `dev` = `cdcd736` pins mobility `eb72b37`; root `dev` pins client `9ae6f5a` and server `cdcd736`. **Not on any `main`, not deployed.** Releasing requires the `release.md` flow (child `main`s first, then root `main`).
- Agreed next steps (LLM council, 2026-09-22): the chart and itinerary share one energy source, with the backend as the source of truth; an "Arrive with at least __%" setting passed to the optimizer; a battery-along-route chart; move `EnergySimulationPanel` out of the garage to a reachable `/research/energy` route; no driving-conditions preset; an evaluation against public reference data with elevation, with error measured by charging decisions.
- Not browser-checked.
- **Energy-path map (2026-09-22, Claude):** displayed SOC comes from client `projectTripCharging` (routed legs, shared constants), which does the same arithmetic as backend `OptimizedRouteVerifier`, so the display already agrees with the backend. The real split is **two stop planners in the EV side panel**: client `planAutoEvChargers` ("Auto add chargers": straight-line distance × road factor, comfort top-ups; works for guests) and backend preview/apply ("Optimize the whole EV route": saved trips only). **Resolved (user chose backend only):** client `dev` `eb8c757` removes `planAutoEvChargers` and `autoAddEvChargersToBlockAtom`. The EV panel has a single "Plan charging stops" action (backend preview/apply) that sends `AUTO_MIN_ARRIVAL_PCT` as reserve and the day's projected start SOC. Guests can no longer auto-plan stops; they are asked to sign in and save the trip, and can still add stations by hand. Root `dev` `257734d` pins it. Not browser-checked.
- **Arrival reserve (client `dev` `4d6a90e`):** `arrivalReservePctAtom` in `garage.atoms.ts` (options 10/12/15/20, `atomWithStorage` key `navio:arrival-reserve-pct`, defaults to the model's 12). Set by `ArrivalReserveControl` in the EV panel's charging preferences. Read by the optimizer payload, the reserve lines in `route-estimate`/`vehicle-usage-overview`, and `getBatteryTone(pct, reservePct)` (the second argument is now required). Per browser, not saved to the account. `route-estimate.tsx` and `charge-segment-info.tsx` became client components.
- **Battery chart (client `dev` `9bd8ccb`):** `garage/battery-route-chart.tsx` in `RouteEstimate` (replaces the day-end bar when the day has distance). Data is the new `DayEvProjection.profile` (per-stop cumulative km, arrival/departure) from `projectTripCharging`. Checked visually in light and dark mode with a temporary preview page (deleted). Not yet checked inside the real planner with live routes. Note: `projectTripCharging` clamps SOC at 0, so an energy deficit plots as 0%.
- **Panel removed (client `dev` `7dee312`):** the user decided the garage's Energy simulation panel isn't needed, not even as a `/research/energy` page. `energy-simulation.ts` (physics model) and `tests/simulation/reference-v1.json` stay for an offline evaluation script.
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
