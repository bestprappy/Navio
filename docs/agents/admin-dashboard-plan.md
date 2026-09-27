# Admin dashboard and shared vehicle catalog

Proposed implementation plan, 2026-09-23. Planning only; no application changes authorized by this document.

## Product scope

Add an **Admin** section to the existing sidebar with **Dashboard**, **Users**, **Vehicle catalog**, and **Activity log**. Dashboard lives at `/admin`, separate from the travel dashboard at `/dashboard`. Admins manage platform accounts and publish vehicle specifications that everyone can select in the planner without typing specifications manually.

"Global vehicles" means a shared catalog, not a shared personal garage. Each person still chooses their own vehicle, battery level, nickname and real-world consumption. Start with the current Thailand catalog; support market as a field so more countries can be added later.

First release: real user counts, search/filter users, ban/unban, catalog create/edit/publish/archive, selection for signed-in users and guests, and an audited activity view. Later: report moderation, bulk catalog import, explicit role-management UI and operational analytics. Avoid account deletion, impersonation and bulk bans in the first release.

## Existing implementation to reuse

Paths below are relative to the repository root.

| Evidence | Implication |
| --- | --- |
| `client/components/sidebar/sidebar.tsx` and `sidebar.menu.tsx` | Extend the existing compound sidebar and collapsed/mobile behavior. |
| `client/auth.ts` | Session currently exposes identity/access token but no explicit typed admin capability contract. Add a trusted capability response for UI gates. |
| `server/user-management-service/.../controller/AdminUserController.java` | Already provides paginated user search, suspend/reactivate and role grant/revoke endpoints. |
| `server/user-management-service/.../service/UserModerationService.java` | Already records bans/audits/events, disables Keycloak accounts, logs out sessions and evicts its local ban cache. Cross-service enforcement still requires verification. |
| `server/user-management-service/.../security/NavioRole.java` | Keycloak owns USER/MODERATOR/ADMIN roles; database role rows are a mirror. |
| `server/user-management-service/.../service/VehicleCatalogService.java` | Catalog is loaded at startup from `src/main/resources/vehicles/thailand.json`; it cannot currently be edited through an admin panel. |
| `server/user-management-service/.../controller/UserVehicleController.java` | Existing authenticated catalog list and add-to-garage endpoints should remain compatible. |
| `server/user-management-service/.../service/UserVehicleService.java` | Catalog specifications are resolved on the server and copied into a personal vehicle with catalog metadata. Preserve snapshot behavior. |
| `client/app/feature/planner/planId/_components/garage/vehicle-catalog-picker.tsx`, `vehicle-api.ts`, `guest-vehicles.ts` | Reuse the picker/API types. Guests currently cannot select catalog vehicles; add a local-only selection path. |
| `client/DESIGN.md`, `client/app/globals.css` | Reuse the current Navio design system, not a separate admin theme. |

Java `...` above expands to `src/main/java/com/navio/usermanagementservice`.

At inspection: root/client/server are on `dev`, user-management is clean on `main`. Root agent notes and many client UI files already contain unfinished changes. Preserve them; implementation branches must start from each repo's `dev` with safe isolation if needed.

## Skills and how to use them

Read each skill when executing its stage; these are explicit implementation instructions, not a claim that every workflow has already run.

| Stage | Skill | Required result |
| --- | --- | --- |
| UI planning and construction | `/frontend-design`, local `.claude/skills/frontend-design/SKILL.md` | First produce a compact design brief and wireframes, critique against Navio's actual workflow, then implement. This skill exists locally even though it is absent from the session's advertised catalog. |
| Optional GSD phase setup | `$gsd-plan-phase <phase>` then `$gsd-ui-phase <phase>` | If using a configured GSD roadmap, create executable tasks and a UI contract before frontend work. Establish phase context first; do not assume an existing admin phase. |
| Security verification | `/security-review`, local `.claude/skills/security-review/SKILL.md` | Trace browser proxy, gateway, JWT roles, target permissions and account suspension across services; findings require evidence. |
| Visual review | `/anti-ai-ui-review`, local `.claude/skills/anti-ai-ui-review/SKILL.md`; optional `$gsd-ui-review <phase>` | Review actual screens for useful hierarchy, appropriate density, mobile behavior and accessibility. |
| Acceptance | `$gsd-verify-work <phase>` when using GSD | Walk through administrator and normal-user scenarios with real APIs. |

Skill command notation describes the intended workflow; an agent without slash-command registration should open the corresponding SKILL.md and follow it. GSD files stay local under `.planning/` per repository rules; commit the durable specification under `docs/`. Do not create a separate Higgsfield website for an admin feature inside the existing Next.js application.

## UI contract

Apply `/frontend-design` to an operations workspace for Navio staff: quick account lookup, clear moderation consequences and trustworthy vehicle specifications. Keep the current Plus Jakarta Sans typography, navy/Paper palette, semantic colors and shared controls. Resolve actual token values from `globals.css` during implementation and document the palette/scale in the UI brief. Use destructive color only for consequential actions; status must also have a text label.

```text
Existing sidebar          Admin dashboard
  Travel                  Users: total | active accounts | banned | joined 30d
  Discover                Vehicle catalog: published | drafts | needs review
  Admin                   Recent admin actions
    Dashboard             Quick actions: Find user / Add vehicle
    Users
    Vehicle catalog
    Activity log
```

Dashboard: compact summary band, catalog review queue and recent activity. Counts link to corresponding filtered lists. Show source timestamps and retryable errors; never turn failed requests into zero counts. "Active accounts" means account status, not daily active usage. No invented growth charts or fake system-health indicators.

Users: searchable paginated table with name, email, role, status and joined date; use a detail drawer for account context and moderation history. Ban dialog names the target, requires a reason and explains the effect. First release uses indefinite bans with explicit unban; add timed bans only when expiration and Keycloak re-enablement are verified end to end. Keep user-facing "Ban/Unban" terminology consistent while mapping to existing suspend/reactivate APIs.

Vehicle catalog: searchable table with make/model/trim/year/market, publication status and verification date. Dedicated create/edit page with Identity, Battery and range, Charging, Image, and Sources sections. Include a preview using the existing picker card. Save draft, Publish, Save changes and Archive should say exactly what happens. Publishing is an explicit action after validation.

Activity: filter by actor, action, resource and date. Show before/after changes without credentials or unnecessary personal data. No audit edit/delete controls.

All screens: loading/empty/error/forbidden states, keyboard operation, labeled controls, visible focus, light/dark modes, narrow viewport layouts and accessible dialogs with focus return. Search/filter/page state belongs in the URL; TanStack Query owns API state and Jotai only owns appropriate transient UI state. Mock fixtures go in `data.ts` and must not ship as live counts.

## Access and ban semantics

| Capability | Guest / USER | MODERATOR | ADMIN |
| --- | --- | --- | --- |
| Read published vehicle catalog | Yes | Yes | Yes |
| Save personal garage | Signed-in USER only | Yes | Yes |
| Admin user list and user summary | No | Yes | Yes |
| Ban/unban ordinary users | No | Yes | Yes |
| Manage catalog and full activity log | No | No | Yes |
| Moderate privileged accounts | No | No | Yes, with safeguards |
| Change roles | No | No | Existing backend only initially |

Moderators see the Admin section with only authorized destinations and a reduced dashboard. Do not expose catalog drafts through public reads or confidential global audit information through moderator history.

Keep Keycloak authoritative. Use a backend capability endpoint such as `GET /v1/users/me/capabilities` for navigation and page gates; revalidate after session refresh. Backend method/service checks remain authoritative for every request. Protect the Next.js page and proxy as well as gateway/service routes; hidden links alone provide no protection.

Preserve self-ban and moderator-to-staff restrictions. Verify and add race-safe protection against suspending or demoting the last enabled administrator. Provision the first admin through the existing trusted Keycloak operator process, never a public signup flag or browser-supplied role.

Before shipping, trace ban enforcement for user, trip, community and mobility operations. An unexpired token issued before suspension must not authorize further account actions after the documented enforcement point. Prefer a shared account-status check at authenticated gateway ingress backed by an internal IAM contract, with bounded caching/invalidation, multi-instance behavior, failure semantics and tests defined before implementation. Services must remain inaccessible through a bypass ingress. Do not assume session logout invalidates all locally verified JWTs. Role revocation needs equivalent treatment for privileged actions. Test IAM/Keycloak partial failures and recovery; do not show successful moderation before authoritative success.

## API and data design

Keep ownership in user-management for this release because it already owns the catalog and garage. Do not move it to mobility merely because it contains EV data. Other services must not query IAM tables directly.

Reuse:

- `GET /v1/admin/users?term=&status=&page=&size=` (currently capped at 100).
- `POST /v1/admin/users/{id}/suspend` and `/reactivate` with existing moderation DTOs.
- Existing personal garage list/add/update/default endpoints and authenticated catalog compatibility route.

Add proposed contracts:

- `GET /v1/admin/statistics`: bounded database aggregates for total non-deleted profiles, active, suspended and joined within the last 30 days. Return `asOf` and explicit date boundaries. These are provisioned Navio profiles, not necessarily every Keycloak identity. Add published/draft/catalog-review counts for admins only.
- `GET /v1/admin/users/{id}` and `/{id}/moderation-events`: minimum account detail/history required by the drawer, scoped by caller permission.
- `GET /v1/admin/audit-events`: paginated, filterable, ADMIN-only read access to existing audit records; extend existing audit actions for catalog changes.
- `GET/POST /v1/admin/vehicle-models`; `GET/PATCH /v1/admin/vehicle-models/{id}`; `POST /{id}/publish` and `/{id}/archive` under the same prefix.
- `GET /v1/vehicle-models`: bounded public search/filter/pagination for published entries only; include market/make/model/year filters. Explicitly configure both gateway and service public access without opening admin endpoints.

Use typed DTOs, stable pagination, validated filters, consistent mapped errors and concurrency versions. Catalog writes return conflicts when two admins edit an outdated version. Scope browser proxy routes explicitly, preserve auth/error behavior and protect cookie-authenticated writes against cross-site requests. Sensitive admin responses use private/no-store caching.

Add an IAM catalog table with stable existing string IDs, make/model/trim/year/market, battery kWh and gross/usable/unknown basis, official range and test standard, connectors, AC/DC limits, image reference, source URL, verified date, draft/published/archived state, timestamps, actor IDs and a concurrency version. Add optional sourced real-world consumption with provenance; retain the current documented fallback when absent. Do not conflate official range, real-world range and usable capacity or silently recalibrate the optimizer.

Use database constraints and DTO validation for positive specifications, valid connector enums, required source information on publish and duplicate make/model/trim/year/market identities. Allow incomplete drafts but block publication until usable specifications are present. Keep reference URLs separate from server-side fetching; first release can reuse existing assets or approved HTTPS images with a placeholder. Upload processing and remote scraping are separate scope.

Create a new additive Flyway migration using the next free version across branches; local highest observed is V4, not a reservation of V5. Seed current JSON entries with the same IDs and values. Add new migrations for later seed corrections rather than changing merged SQL. Test old-image compatibility after migration; document that a rolled-back file-backed application will not display new catalog entries until the newer application is restored.

Preserve existing garage and saved-trip specifications as snapshots. Catalog edits/archiving affect future selections, not users' saved values or private range overrides. Archived cars disappear from new selection but existing garages/trips still work. Add source ID/version to new snapshots without requiring old snapshots to change. Explicit spec-update previews can be a later feature.

Signed-in users select a published model and reuse the current server-side specification lookup to add it to their garage. Guests read the same published catalog and create a local trip vehicle snapshot; account writes still require login. Keep "Custom vehicle" as a fallback. Invalidate catalog queries after publishing and define a short public-cache lifetime so other sessions see changes predictably; prevent archived models from being newly added even from stale pickers.

## Delivery sequence and completion criteria

1. **Confirm contracts and design.** Read repository/Next.js local guides, inspect deployment enforcement paths and establish metric definitions and capability matrix. Use `/frontend-design` for sidebar/screens/wireframes and document API/data changes. Done when page states, permissions and catalog snapshot behavior are specified with no placeholder product decisions.
2. **Authorization foundation and admin shell.** Implement capabilities, admin layouts/sidebar, safe proxy routes and cross-service ban/revocation behavior. Reuse existing moderation services. Done when guests/users cannot access any privileged API/page and already-issued tokens obey suspension. Apply `/security-review` before adding privileged workflows on top.
3. **User dashboard and moderation.** Implement aggregates, user search/filter/detail, ban/unban dialogs and history. Done when counts reconcile with fixtures/database queries, filters paginate correctly, failures remain retryable and successful actions refresh the row, totals and history. Verify privileged-target and last-admin rules.
4. **Persistent vehicle catalog.** Add/verify migration, seed data, CRUD, publication/archive and audit entries; implement editor using `/frontend-design`. Done when a valid admin-published model survives service restart and appears through the published API without a deployment, while drafts stay private and conflicting edits return 409.
5. **Global selection integration.** Switch picker reads to the shared catalog, preserve authenticated add-to-garage compatibility and add guest local selection. Done when a published model is selectable from a second session, custom cars still work and existing garages/trips survive edits/archive. Preserve the current uncommitted garage redesign.
6. **Activity, review and release preparation.** Finish audit UI, run `/security-review` and `/anti-ai-ui-review`, then the acceptance walkthrough (or `$gsd-verify-work`). Update API/database docs. Commit inner repositories first through type-matching branches into `dev`; release only through the documented release workflow when requested.

Phases 2-3 produce a useful user-management panel; phases 4-5 deliver the requested global vehicle workflow. Phase 6 completes the first-release acceptance gate. Implement this plan only after the user requests implementation.

## Verification requirements

- Backend `*Tests`: role matrix, direct unauthorized requests, target ownership/privilege rules, mapped exceptions, self/last-admin protection including concurrent actions, repeated/conflicting moderation, Keycloak failure, ban and role revocation with old access tokens, audit recording, catalog validation/publication/archive and stale edits.
- Real PostgreSQL: Flyway plus `ddl-auto: validate` on clean and upgraded representative schemas, preserved catalog IDs/snapshots, rollback-image compatibility. H2 and mocked tests are insufficient.
- Frontend: TypeScript and scoped ESLint; meaningful integration tests for guards/proxy authorization, URL filtering, ban failure/success, typed API responses, catalog publication and guest/authenticated selection.
- Browser: real API scenarios for guest, USER, MODERATOR and ADMIN; mobile/desktop, collapsed sidebar, light/dark, keyboard-only dialogs and focus; errors must not display as successful actions or zero metrics.
- End-to-end acceptance: admin publishes a car, another user selects it without manually entering specs, guest selects it locally, admin archives it, existing saved trip remains unchanged, archived car cannot be newly added. Admin bans a signed-in test user; that user's current token cannot perform protected actions across services; unban allows normal access again.

## Useful follow-up modules

After the first release: community report queue using community-owned APIs; catalog import with preview/validation and per-row errors; verification reminders for aging specifications; carefully scoped role-management UI; trip/charging usage analytics from service-owned aggregates. Add operational health only from measured checks, with freshness and unavailable states. Do not browse private itineraries or expose raw service logs just to populate an admin dashboard.
