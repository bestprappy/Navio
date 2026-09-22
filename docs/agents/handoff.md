## 2026-09-22 - Codex - Pre-Phase-3 vehicle settings cleanup complete

**Approved and implemented:** Nickname (Optional); divider below Starting Battery; sole Save settings action for nickname/consumption in both guest/account flows; three Energy Consumption choices: Vehicle Default, NAVIO Estimate, Custom. Suitable authoritative battery-side direct consumption is displayed read-only in kWh/100 km; Vehicle Default is disabled without it. NAVIO Estimate selects explicit RATED_RANGE and shows the rated-range basis plus hover/focus/touch information, never a fabricated consumption number. Custom persists user-observed provenance with unknown measurement basis. Legacy values remain untouched until an explicit energy selection is saved; nickname-only saves do not reclassify them. Standalone legacy confirmation button removed; old API remains backward compatible.

**Starting Battery:** Immediately updates active vehicle/trip calculations through a local overlay, independent of form save. No garage write or saved vehicle specification change. Trip-keyed provider/session cleanup prevents carrying the override into another trip. Existing day-to-day projection is unchanged. This overlay is currently in-memory and resets on leaving/reloading; it is not a saved-trip field. Numerical RATED_RANGE projections remain deferred to Phase 3.

**Contract change:** Added USE_RATED_RANGE to frontend/guest and backend selection commands so explicit estimate selection does not revert to direct default. Backend resolves catalogue data and stores null consumption; preserves range standard/capacity basis. API documentation updated. No migrations, calculation arithmetic, standard factors, backend 1.12, routing/charger semantics or Phase 3 implementation.

**Verified:** 34 focused frontend tests; TypeScript; targeted ESLint; diff whitespace checks; 39 backend garage/service/API tests passed. Two conditional PostgreSQL checks skipped (no disposable DB). Chrome guest browser scenario passed with mocked public data, including disabled Vehicle Default, tooltip keyboard access, immediate battery change without enabling Save settings, custom/estimate saves, catalogue/custom flows and no account requests/browser errors. Authenticated flow tested through callbacks/service/API, not live authenticated browser deployment.

**Files:** garage vehicle-settings-form.tsx, energy-selection.ts, vehicle-api.ts, guest-vehicles.ts, garage.atoms.ts, garage-provider.tsx; planner-detail.tsx trip provider key; frontend garage/guest tests; backend VehicleRequests, VehicleEnergyProfile, UserVehicleService, VehicleGarageTests; existing API/handoff/session documentation. Source remains uncommitted alongside Phase 1/1.1/2 changes. Preserve unrelated tsconfig flag, CLAUDE.md, service logs. No push/deployment; deploy new backend command before this client. Local root dev and origin/dev diverge; no remote merge attempted as part of this UI scope.

**Locked Phase 3 requirement ? optional observed SoC checkpoint:** For each normal itinerary stop, add a secondary Set battery level / Update battery level action (no stop UI redesign). Optional 0?100% observed SoC seeds predictions only after that stop; earlier legs stay unchanged. Without a checkpoint, propagate normally. Removing/resetting returns to normal predictions. It belongs to stop/trip, never permanent vehicle/garage; guest temporary, saved trips persist with the stop. Clearly distinguish observed battery from charging; no charging is implied. Implement with the canonical chronological energy/SoC projection in Phase 3, before downstream reachability integration, with tests for earlier-leg invariance, later-day carry-forward, removal, 0/100 bounds, guest state and saved-stop reload. This requirement is recorded only, not implemented. Phase 3 still awaits approval.

## 2026-09-22 - Codex - Phase 2 energy selection implementation

**Approved boundary:** User supplied the exact full-plan Phase 2 section: direct selection, range fallback and override UI; backend explicit default/override/reset with server-resolved defaults; Phase 1 profiles; preserve legacy values and require confirmation before automatic application. PLAN 2.md was Phase 1-only, not the full redesign. Do not start Phases 3-5.

**Done:** Removed standard-factor consumption derivation from the selection path. Catalogue default resolves suitable independently evidenced battery-side direct consumption, else explicit RATED_RANGE with null consumption; user-observed override wins, reset resolves the default again. Added USE_DEFAULT/USER_OVERRIDE/RESET_DEFAULT/CONFIRM_LEGACY commands, separate legacy confirmation metadata, null-profile round-trip support, optional custom consumption, shared guest/account settings and selection UI. Guest state remains temporary. Active vehicle identity/connectors are separate from the existing positive-consumption calculation adapter. Legacy numbers/provenance are unchanged without explicit commands; client automatic application requires confirmation. No calculator arithmetic, backend 1.12, schema migration, reachability algorithm or Trip Energy redesign changes.

**Verified:** 32 focused frontend tests pass (API, picker/dialog/settings callbacks, provenance/selection, guest state, active-vehicle and local application guard, charger filtering); full TypeScript and targeted lint pass. 39 backend garage/service/API/security tests pass; 2 conditional PostgreSQL tests skipped (no disposable DB configured). Chrome guest browser scenario passed with mocked public data: catalogue default, observed override, reset, Custom EV, no account writes/browser errors and refresh cleanup. Authenticated behavior covered by callback/API/service tests, not live authenticated browser/backend integration. Diff whitespace checks clean.

**Working tree:** Phase 1/1.1/2 application source and tests remain uncommitted; preserve prior tsconfig flag, CLAUDE.md and service logs. Phase 2 additionally touches garage energy-selection.ts, data.ts, garage.atoms.ts, garage-section.tsx, day-route-overview.tsx, use-trip-charging.ts; charger selection/application consumers; trip-builder automatic insertion guard; new energy-selection tests and expanded browser/controller/garage/Postgres tests. Existing vehicle API/types/mappers/forms/DTO/service/mapper files carry stacked Phase 1/2 changes. API/database documentation and agent reporting committed separately locally on docs branch, merged to dev; no push/deployment.

**Limitations / next phase:** RATED_RANGE selection is represented honestly but numeric rated-range route/SoC projections and optimizer previews await Phase 3; no zero/derived-consumption adapter is sent to the old calculator. Existing positive-consumption arithmetic still uses its prior capacity semantics until Phase 3. Existing custom required declared capacity/reference-range fields remain unchanged; unknown usable capacity remains null. Automatic eligibility guards are client selection behavior, not new backend optimizer enforcement (Phase 4). Deploy user-service commands before client. Run disposable PostgreSQL and live authenticated integration checks before release. Stop after Phase 2; await Phase 3 approval. The approved Phase 5 requirement below remains locked and deferred.

## 2026-09-21 - Codex - Approved Phase 5 requirement and Phase 2 authorization

**Approved deferred requirement:** "Consolidate the professional Trip Energy UI with the useful information depth from the old Usage Overview after the energy and routing model is stable."

**Phase 5 acceptance criteria:** Keep the current Trip Energy design as the visual foundation. Preserve useful vehicle identity/image, Catalogue/Custom identity, specifications/connectors, average distance per planned day and date-based daily usage details without duplicate summary cards. Use concise primary metrics with accessible, responsive secondary details shared by guest catalogue/custom and signed-in catalogue/custom flows. Preserve Phase 1.1 catalogue-first selection and temporary guest vehicles.

All energy/SoC, range, charging and reserve displays must consume the canonical model established by Phases 2-4; do not restore old calculations or separate Planner/Explore calculation paths. Keep total driving energy (kWh) distinct from consumption (kWh/100 km), and label planned distance rather than mileage. Unknown/unavailable results must not appear as confirmed zero. Show direct/user-observed provenance, rated-range preview restrictions, unavailable and legacy-unknown states honestly; keep range/consumption standards and evidence separate. Reserve is not uncertainty. Do not restore decorative battery segments, missing-data zero charts or duplicate vehicle imagery.

**Implementation gate:** Defer consolidation to Phase 5 after route results, sequential stop/day projections and reachability semantics are stable and validated. Phase 4 may correct misleading result states but must not restore/redesign Usage Overview. Eventual checks cover model states, units/provenance, missing/partial routes, charger targets/compatibility, reserve violations, date carry-forward, shared Planner/Explore results, four account/vehicle flows, narrow drawers, both themes and accessibility.

**Historical Phase 2 handoff:** The approved Phase 2 section was initially unavailable. The user subsequently clarified that PLAN.md is the full redesign and PLAN 2.md is Phase 1-only, and supplied the exact Phase 2 scope. See the September 22 entry for implementation and checks; no UI consolidation was performed.

## 2026-09-21 - Codex - Phase 1.1 guest catalogue correction

**Done:** Both vehicle-add flows default to Catalogue with Custom EV available. Guest catalogue selections copy validated catalogue specifications/identity/profile into temporary guest state; no account writes. Signed-in saving remains unchanged. Exact GET /v1/users/me/vehicles/catalog is public in the Next proxy, gateway and user service; controller no longer resolves/provisions a current user for this read. All private garage/account operations stay authenticated. Phase 1 provenance preserved; no Phase 2 or energy/charger/optimizer changes.
**Verified:** 22 frontend tests (garage API, actual component render/callback harness, picker filtering, exact proxy rules, guest selection and Phase 1 regression); 33 user-service garage/security tests; 9 gateway security/identity tests passed. TypeScript and targeted lint passed. Existing guest browser script updated for catalogue selection plus Custom EV, but full browser/live-backend integration not run. Phase 1 real PostgreSQL persistence check remains pending; no schema change in Phase 1.1.
**Working tree:** Phase 1 and 1.1 application changes remain uncommitted in client, server/api-gateway and user-management-service. Preserve pre-existing tsconfig flag, CLAUDE.md and logs. Additional 1.1 files: vehicle proxy route; add-vehicle-dialog, guest-vehicles, vehicle-api; garage API/energy-profile/catalogue-flow tests and guest/browser-check; GatewaySecurityConfig/GroupPublicRoutesTest; user SecurityConfig/UserVehicleController/UserVehicleControllerTests. Required documentation committed separately on a docs branch and merged locally to dev. No push/deployment.
**Next:** Deploy gateway/user-service changes before relying on public catalogue in the client. Browser-check guest and signed-in flows together. Phase 2 is now authorized; see the latest entry for the missing approved-plan text. Phase 5 UI consolidation remains deferred.

## 2026-09-19 - Codex - Vehicle energy provenance Phase 1

**Goal:** Implement only the additive vehicle-consumption provenance contract; Phase 2 requires separate approval.
**Done:** User service exposes typed version-1 energyProfile metadata, stores explicit user-observed provenance in existing JSONB, and returns legacy/unknown profiles without read-time writes. Catalogue range standard/source remain separate from absent consumption evidence and unknown usable capacity. Frontend schemas/mappers carry profiles; explicit average-entry paths send USER_OBSERVED with UNKNOWN basis, including guest vehicles. Unrelated settings edits omit consumption so provenance is preserved. Existing scalar values, factors, battery calculations, optimizer multiplier and charger behaviour are unchanged.
**Verified:** 32 focused backend tests pass; 2 conditional PostgreSQL tests skipped (Docker unavailable/no disposable DB configured). 17 frontend garage/provenance/guest tests pass with Node 22.22; installed Node 22.14 lacks the test suite's registerHooks API. TypeScript and targeted ESLint pass; diffs have no whitespace errors. Root fast-forward-only pull reports already up to date.
**Uncommitted implementation:** client vehicle.types.ts; garage vehicle-api.ts, vehicle-mappers.ts, guest-vehicles.ts, add-vehicle-dialog.tsx, custom-vehicle-form.tsx, vehicle-settings-form.tsx; tests/garage/energy-profile.test.mjs. User service: new VehicleEnergyProfile.java; VehicleCatalogResponse, VehicleResponse, VehicleRequests, UserMapper, UserVehicleService; VehicleGarageTests, UserVehicleControllerTests, PostgresSchemaTests. Pre-existing client tsconfig flag/CLAUDE.md and service logs preserved. No push/deployment.
**Next:** Review Phase 1, run the PostgreSQL JSONB persistence test when a disposable database is available, and deploy backend support before the client sends new provenance fields. Do not start fallback selection, uncertainty/reserve changes, model eligibility, or Phase 2 without user approval. Required session/API/database documentation is recorded in the root docs branch and merged locally to dev.

## 2026-09-16 - Codex - Pull latest integrated release

**Goal:** Pull all latest Git changes and resolve conflicts while preserving local work.
**Done:** Fast-forwarded root to 3ee0228, client to 4622b54, server to 8eb47de; synchronized all four service gitlinks. Root/client/server on dev. Prior guest/drawer commits are ancestors of the incoming release. Backed up the local AGENTS files before accepting shared versions; no code conflicts. Installed incoming frontend dependencies and retained the upstream lockfile.
**Verified:** All six submodules equal origin/dev and their parent pins. TypeScript passes after regenerating route types and moving a malformed old generated validator out of .next/dev/types. 44 frontend tests pass; planner/anchor/overnight model checks pass; lint zero errors/two existing warnings. No unresolved index entries.
**Not done / left uncommitted:** Existing local client tsconfig working-tree flag (no textual diff), CLAUDE.md and service logs preserved. No production build, browser run, backend/PostgreSQL tests or deployment in this pull-only session.
**Follow-ups:** Runtime/production health and schema validation remain separate from Git synchronization. Session docs committed locally only per AGENTS.md; no push requested.
# Handoff

Current state for the next agent. Overwrite sections as they change; keep it short. History belongs in [session-log.md](session-log.md).

**Last updated:** 2026-09-15 by Claude

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
