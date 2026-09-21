## 2026-09-21 - Codex - Phase 1.1 guest catalogue correction

**Done:** Both vehicle-add flows default to Catalogue with Custom EV available. Guest catalogue selections copy validated catalogue specifications/identity/profile into temporary guest state; no account writes. Signed-in saving remains unchanged. Exact GET /v1/users/me/vehicles/catalog is public in the Next proxy, gateway and user service; controller no longer resolves/provisions a current user for this read. All private garage/account operations stay authenticated. Phase 1 provenance preserved; no Phase 2 or energy/charger/optimizer changes.
**Verified:** 22 frontend tests (garage API, actual component render/callback harness, picker filtering, exact proxy rules, guest selection and Phase 1 regression); 33 user-service garage/security tests; 9 gateway security/identity tests passed. TypeScript and targeted lint passed. Existing guest browser script updated for catalogue selection plus Custom EV, but full browser/live-backend integration not run. Phase 1 real PostgreSQL persistence check remains pending; no schema change in Phase 1.1.
**Working tree:** Phase 1 and 1.1 application changes remain uncommitted in client, server/api-gateway and user-management-service. Preserve pre-existing tsconfig flag, CLAUDE.md and logs. Additional 1.1 files: vehicle proxy route; add-vehicle-dialog, guest-vehicles, vehicle-api; garage API/energy-profile/catalogue-flow tests and guest/browser-check; GatewaySecurityConfig/GroupPublicRoutesTest; user SecurityConfig/UserVehicleController/UserVehicleControllerTests. Required documentation committed separately on a docs branch and merged locally to dev. No push/deployment.
**Next:** Deploy gateway/user-service changes before relying on public catalogue in the client. Browser-check guest and signed-in flows together. Stop here; Phase 2 still requires approval.

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
