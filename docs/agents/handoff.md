# Handoff

Current state for the next agent. Overwrite sections as they change; keep it short. History belongs in [session-log.md](session-log.md).

**Last updated:** 2026-09-14 by Claude

## Live in production

Root `3fb68c4` (deploy run 34826778768, success).

- **Structured trip location.** Trips store `destinationCity`, `destinationRegion`, `destinationCountryCode`, and `destinationCountry`, resolved server-side from `destinationId` through mobility-and-ev-service. `displayName` is optional; responses include a derived `title` (name -> city -> country). Clients send only `destinationId` (plus dates/name).
- Copying a premade plan resolves a place id from the destination name before creating the trip (`resolveDestinationPlaceId` in `client/app/feature/planner/_components/destination-api.ts`).

## In progress

- **Shared agent context** (this setup): `AGENTS.md`, `docs/agents/*`.
- **Pre-deploy database check**: a CI job that runs migrations and Hibernate validation against real Postgres before images are built. Not merged yet.

## Uncommitted work in `client/` (not mine — review before committing)

About 57 files from an earlier Codex session, never reviewed or tested beyond a full-tree type-check:

- Sidebar and recent plans: `sidebar-trips.tsx`, `recent-plan-sidebar*.ts(x)`, `components/sidebar/*`, `sidebar-account-actions.tsx`
- Dashboard and navigation: `app/dashboard/`, `trip-dashboard*.tsx`, `planner-home.tsx`, `navbar.tsx`, `logo.tsx`, `profile-menu.tsx`
- Theme and styling: `components/theme/`, `globals.css`, `dropdown-menu.tsx`, `country-flag.tsx`, small card/map edits
- Other: `plan-preview-card.tsx`, `plan-tag.tsx`, `guest-welcome-prompt.tsx`, `package.json` (+1 dependency)
- `planner-detail.tsx` still has two uncommitted `RecentPlanSidebarSync` lines that depend on the sidebar work.

The user has not yet decided whether to commit these on their own branch.

## Known gaps

- Existing trips created before 2026-09-14 have null city/region/country code until the backfill runs. It is off by default: `navio.trip-location-backfill.enabled=true` (rate limited, retries failed places on the next run).
- Premade-plan copy resolves the destination by name; not tested in a browser yet.
- `docs/api/Navio Open API.yaml` trip schemas describe a planned design and do not match the current trip DTOs.
- trip-planning-service `@SpringBootTest` and `@WebMvcTest` tests need the configuration server on port 8888 (no test `application.yml`).
- user-management-service full-context test is `@Disabled` (needs Keycloak); mobility and community default tests run on H2.

## Next steps

1. Finish and merge the pre-deploy database check.
2. Decide what to do with the uncommitted client work.
3. Run the trip location backfill in production once, then verify a sample of old trips.
