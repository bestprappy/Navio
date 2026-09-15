# Handoff

Current state for the next agent. Overwrite sections as they change; keep it short. History belongs in [session-log.md](session-log.md).

**Last updated:** 2026-09-15 by Codex

## Latest fix: block accent colors

TripBlock.Root in client block/trip-block.tsx now scopes --primary, --primary-foreground and --ring to its selected palette entry. This makes primary icons, links, borders and focus states follow each block color. Chrome verified Rose-to-Teal updates across six primary elements, with global theme unchanged; TypeScript and ESLint pass. Application edit remains uncommitted alongside prior work.

## Latest fix: route and battery row alignment

Client route status rows now use layout divs instead of paragraphs so AccordionContent's `[&_p:not(:last-child)]:mb-4` rule cannot shift the first row upward. Applies to normal/loading/fallback drive rows and discharge details. Browser verified equal row positions and zero margins, plus clean wrapping at 390px. TypeScript and targeted ESLint pass. Both route component files remain uncommitted alongside prior work; no deployment.

## In progress: delete trip (client, uncommitted)

"⋯" trip options menu with Delete trip + confirmation dialog on dashboard cards (`trip-summary-card.tsx`) and in the planner beside the trip name (`trip-info-card.tsx`, redirects to `/dashboard`). New files: `client/app/feature/planner/_components/trip-actions-menu.tsx`, `use-delete-trip.ts`; `deleteTrip` added to `planner-api.ts`. Type-check and lint pass; not browser-tested. Do not make the delete hook refetch `["planner", tripId]`: a 404 there makes `PlannerPersistence` create the trip again.

## Latest investigation

Sidebar flags repaired in production data: initially 9/10 trips lacked country codes. Ran the deployed opt-in backfill in a temporary container (6 repaired), then resolved three legacy numeric destination IDs through mobility and updated them through the trip service (Phuket, Chiang Mai, Chiang Rai). Backup: VM `/home/adminnav/navio-maintenance/flags-2026-09-15/trip-before-backfill.sql`. Temporary container removed; service stayed healthy. Concurrent user activity reduced the trip count; final live API check verified all 6 remaining trips have codes, and SQL found zero null codes.

Local client fix, uncommitted: `planner-setup.tsx` and `planner-persistence.tsx` invalidate trip-list queries after creation so the sidebar refreshes. Full type-check and targeted lint pass. User also reported a new trip without a country; requested destination and whether localhost/deployed, awaiting clarification. Browser rendering not verified. Other agents' client/backend edits preserved.

## Live in production

Root `0a4acc4` (deploy run 34829001804, success). Application code is unchanged since root `3fb68c4`; later releases added only tests, CI, and docs.

- **Structured trip location.** Trips store `destinationCity`, `destinationRegion`, `destinationCountryCode`, and `destinationCountry`, resolved server-side from `destinationId` through mobility-and-ev-service. `displayName` is optional; responses include a derived `title` (name -> city -> country). Clients send only `destinationId` (plus dates/name).
- Copying a premade plan resolves a place id from the destination name before creating the trip (`resolveDestinationPlaceId` in `client/app/feature/planner/_components/destination-api.ts`).

## Recently added (not in production code paths)

- **Shared agent context**: `AGENTS.md` (committed; Codex loads it, Claude loads it via local `CLAUDE.md` = `@AGENTS.md`) and `docs/agents/*`. Every session must update this file and the session log.
- **Pre-deploy database check**: `PostgresSchemaTests` in all four JPA services plus the `verify-database-schema` job in `deploy-backend.yml`, which must pass before images build. Verified locally against PostGIS 16, including that it fails on the 2026-09-14 `char(2)` bug, and passed its first CI run (deploy run 34829001804, root `0a4acc4`, success).

## Uncommitted work in `client/` (not mine — review before committing)

About 57 files from an earlier Codex session, never reviewed or tested beyond a full-tree type-check:

- Sidebar and recent plans: `sidebar-trips.tsx`, `recent-plan-sidebar*.ts(x)`, `components/sidebar/*`, `sidebar-account-actions.tsx`
- Dashboard and navigation: `app/dashboard/`, `trip-dashboard*.tsx`, `planner-home.tsx`, `navbar.tsx`, `logo.tsx`, `profile-menu.tsx`
- Theme and styling: `components/theme/`, `globals.css`, `dropdown-menu.tsx`, `country-flag.tsx`, small card/map edits
- Other: `plan-preview-card.tsx`, `plan-tag.tsx`, `guest-welcome-prompt.tsx`, `package.json` (+1 dependency)
- `planner-detail.tsx` still has two uncommitted `RecentPlanSidebarSync` lines that depend on the sidebar work.

The user has not yet decided whether to commit these on their own branch.

## Known gaps

- Trip country backfill completed on 2026-09-15; zero remaining null country codes at verification. The runner remains disabled by default.
- Premade-plan copy resolves the destination by name; not tested in a browser yet.
- `docs/api/Navio Open API.yaml` trip schemas describe a planned design and do not match the current trip DTOs.
- trip-planning-service `@SpringBootTest` and `@WebMvcTest` tests need the configuration server on port 8888 (no test `application.yml`).
- user-management-service full-context test is `@Disabled` (needs Keycloak); mobility and community default tests run on H2.

## Next steps

1. Decide what to do with the uncommitted client work.
2. Confirm the sidebar after browser refresh; investigate the reported new trip if the flag is still missing (need destination/environment).
