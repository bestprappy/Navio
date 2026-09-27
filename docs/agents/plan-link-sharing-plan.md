# Plan link sharing — implementation proposal

Date: 2026-09-23. Status: proposed; no feature code implemented.

## Outcome and recommended scope

From a saved plan's three-dot menu, the owner chooses **Publish plan as a link**. A short dialog explains access and previews the exact content recipients will receive. Publishing produces an unlisted, read-only snapshot at `/share/plans/<opaque-token>`. Guests can open it without signing in. Only the owner can change the original, update the published snapshot, replace the link, or stop sharing.

Publishing is explicit: later edits remain private until **Update published plan**. This matches the word “publish” and prevents a new personal note or overnight stop from silently becoming visible. Keep one active link per trip in the first version. Do not add editor invitations, comments, public Explore discovery, passwords, or expiry controls to this release.

These are recommended product decisions, not descriptions of existing behavior.

## Required skill use during implementation

Before each phase, discover relevant installed and repository-local skills, open the applicable `SKILL.md`, read its referenced material needed for the task, and apply it to the actual work. Do not merely list a skill or assume its instructions from its name. Announce first use briefly and record which guidance was applied with the phase's verification evidence. Reuse instructions already read in the same session unless they changed. User instructions and the established Navio product direction take precedence over generic skill defaults.

Repository-local skills were located on 2026-09-23, including `frontend-design` even though it was absent from the session's advertised skill catalog. These paths are local and may be absent in another checkout; check before starting. If a named skill is missing, search other configured skill locations, report the gap accurately and use applicable repository guidance where sufficient. Do not claim to have used a missing skill or install one silently. A necessary missing skill blocks only the work depending on it.

| Work | Skill to read and apply | Required supporting context | Concrete output |
| --- | --- | --- | --- |
| Design publishing dialog, link management and recipient page | [frontend-design](../../.claude/skills/frontend-design/SKILL.md) | `client/AGENTS.md`, relevant installed Next.js guides, `client/DESIGN.md`, `client/app/globals.css`, `.claude/rules/ui.md`, client code/style rules and existing Base UI primitives | Brief design rationale, token/component mapping, wireframes and complete interaction states before UI code; screenshots and self-critique after |
| Design/review permissions, public access, copying and revocation | [security-review](../../.claude/skills/security-review/SKILL.md) | Actual BFF/gateway/service/deployment path, server API/testing rules and OpenAPI contract | Actor/action matrix, traced trust boundaries and abuse-case tests; evidence-backed findings separated from assumptions |
| Review completed dialog and shared page | [anti-ai-ui-review](../../.claude/skills/anti-ai-ui-review/SKILL.md) | Real rendered screens, current brand tokens and the owner's/recipient's tasks | Small targeted fixes for hierarchy, excess decoration, confusing copy and dead controls; preserve permissions and behavior |
| Investigate measured rendering, query or route-request bottlenecks if encountered | [optimization-review](../../.claude/skills/optimization-review/SKILL.md) | Request/render/query evidence from the affected paths | Minimal measured fix and regression check; no speculative optimization or caching that defeats revocation |
| Schema/service implementation, tests and release | Discover any additional genuinely relevant skills available at execution time; no dedicated database skill was identified for this plan | `docs/agents/database-changes.md` before migrations/entities, `.claude/rules/server/{api-conventions,code-style,testing}.md`, Git rules, and `docs/agents/release.md` before release | Additive schema, typed contracts, authorization/exception tests and real Postgres startup evidence; release only within authorized scope |

These instructions do not authorize deployment or application implementation during this planning session. Skill discovery must not expand this feature into a whole-app redesign or unrelated audit. In particular, do not apply the old `ui-depth` direction: the user previously requested its removal.

## UI design rehearsal

Apply `frontend-design` in two passes: first lay out the information and states, then critique against this brief before building. Preserve Navio's existing palette and typography through its semantic tokens; `globals.css` wins when DESIGN.md is stale. Use Paper/navy neutrals, the existing primary action color, existing text styles and restrained semantic status colors. Do not create a replacement palette or font system for this feature.

The owner's main question is “What will people see, and can they change my plan?” Put that answer directly below the title, with plain permission rows followed by content choices. Keep one primary action per state. The recipient page should lead with the real itinerary and map. All content is left-aligned except where existing action placement dictates otherwise.

```text
Publish plan as a link                              Close
Anyone with the link can view this published version.

You                         Edit and manage sharing
Anyone with the link        View only
People can forward this link.

Shared: itinerary, places and charging stops
Private saved locations are always hidden.
[ ] Include travel dates
[ ] Include notes and checklists
[ ] Include budget and expenses
[ ] Let viewers make their own copy

Preview shared plan
                              Cancel    Publish link
```

After publication, retain the access summary and replace the main action area with a selectable URL and Copy link. Keep update, replacement and revocation distinct; do not make a destructive action the default. A selected content setting describes the draft publication until Update succeeds. On mobile, use the existing responsive dialog with a scrollable body and reachable actions; avoid a second nested modal for the preview. Give the preview a Back action that retains selections.

Design all states before implementation: private, loading settings, preview loading/error, saving, publishing, active, unpublished changes, updating, copy success/failure, expired session, offline/save failure, version conflict, rotating, stopped and unavailable. Never enable Publish while its save/preview is stale. A conflict directs the owner to refresh and review; failed operations retain their selections and the last successful published state.

Review the design for recognizability as Navio, permission comprehension without color, readable grouping and actionable errors. Remove placeholder invitations/social buttons and any decorative elements that compete with itinerary content. Verify keyboard focus, dialog announcements, narrow/short screens and reduced motion using the actual rendered implementation.

## What exists today

- `client/app/feature/planner/_components/trip-actions-menu.tsx` has only Delete trip. Both the dashboard's trip card and planner header reuse it, so put the entry point there.
- `planId/_components/overview/trip-info-card.tsx` currently hides that menu unless the viewer is authenticated and trip metadata exists for a persisted ID. Guest publishing needs an explicit sign-in/save entry path.
- Explore's `share-dialog.tsx` copies `getPlanHref(plan)` from local `data.ts`. Invite and social buttons are placeholders; this is not a saved-trip publishing implementation.
- Explore's `view/[id]/[slug]/_components/plan-view.tsx` has read-only presentation, but depends on premade Plan data, mock authors and template EV assumptions. Extract useful presentation rather than passing a private planner response into that model wholesale.
- `TripService` creates PRIVATE trips and reads/updates/deletes by trip ID plus owner ID. Its update DTO accepts visibility, and the enum contains PRIVATE/UNLISTED/PUBLIC, but visibility alone does not implement shared access. `PlannerService` also checks ownership.
- Next's `app/api/_lib/public-planner-request.ts` and the gateway's `GatewaySecurityConfig` do not permit anonymous saved-trip reads.
- Planner persistence uses an autosave mutation scope and delayed saves; metadata and planner snapshots share a version. The delete hook already uses that scope. Queue ordering alone does not flush a pending debounce.
- Migration V9 explicitly requires stripping SAVED_PLACE day anchors from shared snapshots. PLACE and MANUAL anchors travel, so preview must expose exactly what those contain.

## Owner flow and exact copy

1. Three-dot menu: **Publish plan as a link**, above the destructive delete action. Opening the dialog changes nothing.
2. Title: **Publish plan as a link**. Description: “Anyone with the link can view this published version. They cannot change your original plan. Your plan will not appear in Explore.”
3. Access summary, always visible: **You — Owner: edit and manage sharing**; **Anyone with the link — Viewer: view only**. Add “People can forward this link.” Do not display an editable Viewer/Editor selector when only viewing exists.
4. Content summary: itinerary, places and charging stops included; saved personal locations excluded. Dates, notes/checklists, and budget are off by default and individually opt-in. Labels are **Include travel dates**, **Include notes and checklists**, and **Include budget and expenses**. Warn adjacent to notes that they may contain personal details. Allow copying is off by default: **Let viewers make their own copy**.
5. **Preview shared plan** shows the server-sanitized result, including all visible names, descriptions, manual locations and map pins. Explain that titles and manual pins can still contain information the owner entered. Private anchors appear only as “Private start location” or “Private end location”; never expose their IDs, labels, addresses or coordinates.
6. Primary action: **Publish link**. Flush pending itinerary and metadata changes, obtain the final saved version, then generate/confirm its sanitized preview. If the preview version changed, refresh it before publication. Show “Saving plan…” then “Publishing…”. If save or publish fails, retain the dialog and choices; never claim that a link exists.
7. Success remains in the same dialog: **Link published**, selectable URL, **Copy link**, **Open shared plan**, publication time. Show “Changes to your original stay private until you update the published plan.” Clipboard failures leave a selectable link and inline feedback. Optional native device sharing is a progressive enhancement.
8. Reopening the menu shows **Manage published link**. Actions: Copy link, Preview, Update published plan, Replace link, Stop sharing. Show **Unpublished changes** when the source version differs (a conservative indicator; private-only edits may also trigger it).
9. Update previews and publishes the selected current version atomically at the same URL. Changing inclusion settings takes effect with Update; changing the copy permission takes effect immediately and is checked server-side.
10. Replace link confirms “The old link will stop working.” Preserve the currently published snapshot and copy setting; generate a new token. Stop sharing confirms “People with this link will no longer be able to open the plan.” Re-publishing after stopping always creates a new token, so old links never reactivate.

Guest authors see the publish entry with **Sign in to publish**. Preserve the local draft through authentication, save it into the signed-in account through the existing guest/save flow, then reopen the dialog. Do not publish automatically after sign-in. If offline or a draft cannot be saved, keep the draft and explain that publication needs a saved plan.

## Permission contract

| Action | Owner | Guest with link | Signed-in non-owner with link |
| --- | --- | --- | --- |
| View published snapshot | Yes | Yes, while active | Yes, while active |
| View private original or excluded fields | Yes | No | No |
| Edit/delete original; change dates, stops, budget or checklists | Yes | No | No |
| Run optimization on original | Yes | No | No |
| Publish/update/replace/revoke link | Yes | No | No |
| Forward link | Yes | Yes | Yes |
| Create independent private copy | Via copy flow if offered | Sign in first, if allowed | Only if owner enabled copying |
| Edit their independent copy | If they own it | No saved copy without sign-in | Yes; never affects original |

UI should reflect these rules, but service authorization enforces them. A link grants read access only. Signing in does not grant editing rights. Turning off copying or revoking a link cannot erase screenshots or independent copies already made; explain this in the relevant control, without claiming to prevent manual copying.

## Recipient experience and privacy contract

- Dedicated read-only page: title, “Published plan · View only”, last published time, day itinerary, map and charging stops. Day 1/Day 2 replace calendar dates unless included. Missing private anchors do not inherit or reveal a neighboring private location.
- No drag handles, inline editing, completion toggles, account garage, invite controls or autosave. Do not mount `PlannerPersistence` or write to the owner's/recipient's current planner atoms. Use isolated view state.
- Show **Make my own copy** only when allowed; guest authentication returns to this shared plan and rechecks active status/permission. Owner viewing their own link gets **Open my plan** separately.
- Clone server-side from the published sanitized revision, with fresh trip/block/item IDs, PRIVATE visibility, recipient ownership, no publication token and no link back granting original access. Ask the recipient for their dates and private start location. Reset visited/checklist completion and exclude personal garage/vehicle identifiers. Recompute routes and EV estimates using their own inputs. Require a valid destination; if published destination resolution fails, let them choose one without creating a partial trip. Prevent duplicate copies from retries.
- Invalid, stopped, deleted or replaced links show the same “This shared plan is no longer available” page. Do not reveal the owner or private title on failure. No authentication loop or missing-trip creation.
- Build a public DTO from an explicit allowlist. Exclude ownership/account IDs, email, private saved-place fields, garage identifiers and nickname, initial battery state, raw private snapshot payloads and internal persistence metadata. Gate budget fields including per-stop cost behind the budget option; gate item notes, free-text note items and checklists together. Dates must be removed from all fields, not just visually hidden.
- Sanitize nested anchors and derived values too: route geometry, distances, durations and battery charts must not encode a removed location. Recompute on remaining public segments or mark the segment unavailable. Do not render misleading complete-route or EV totals after redaction. Charger details/targets may be included as itinerary information, but personalized battery projections are outside the first version.
- Preview uses the same server projector as publication. The browser never receives excluded fields on public routes. Allowlist media URLs/types and render text safely; private/protected media must not become reachable through this feature.

## Backend and integration design

Add an additive `trip`-owned publication table with a trip foreign key, unique random token (at least 128 bits of cryptographic randomness), sanitized snapshot JSONB, snapshot schema version, source trip version, inclusion settings, allow-copy flag, publication revision and timestamps. One row per trip; nullable/disabled token on revocation. The token is a bearer access secret: do not log it or send it to analytics. Store it under normal database access controls so owners can retrieve the current link. No changes to another service's schema.

Proposed routes, finalized in the API contract before implementation:

- `GET /v1/trips/{tripId}/publication`: owner-only state and current link.
- `POST /v1/trips/{tripId}/publication/preview`: owner-only sanitized preview for settings and expected source version; no publication side effect.
- `PUT /v1/trips/{tripId}/publication`: owner-only create/update from saved source and expected publication revision; idempotent retries preserve one URL and result. Repeated writes with stale versions return 409 rather than overwriting.
- `PATCH /v1/trips/{tripId}/publication`: owner-only allow-copy change with revision check.
- `POST /v1/trips/{tripId}/publication/rotation`: owner-only atomic token replacement with an idempotency key.
- `DELETE /v1/trips/{tripId}/publication`: owner-only, idempotent revocation.
- `GET /v1/shared-plans/{token}`: anonymous sanitized snapshot and public capabilities only.
- `POST /v1/shared-plans/{token}/copies`: authenticated, verifies active publication and allow-copy inside the copy transaction; idempotency key prevents duplicate trips.

Check ownership in every management service method. Snapshot creation must read a consistent saved trip and compare the expected source version within a transaction, coordinating concurrent saves/deletion; serialize publication updates with a lock or version condition. Never trust client-supplied owner IDs or a browser-created “sanitized” payload. Delete trip cascades to publication. Concurrent revocation/copy requests have a defined transaction order; a copy completed before revocation survives.

Keep original-trip access owner-only regardless of the legacy visibility field. Publication records are the sole access authority for this first version; do not automatically expose old UNLISTED/PUBLIC rows or use metadata PATCH to create links. Reserve PUBLIC/Explore integration for a separate feature. Return actual permissions separately from the existing planner `capabilities`, which are supported-format flags, not authorization.

Wire a dedicated Next proxy and explicit gateway routing for `/v1/shared-plans`; permit only its exact read route anonymously. Copy stays authenticated; every original saved-trip endpoint stays protected. Verify existing identity-header stripping and CSRF/origin protections still apply. Review deployed proxy/CDN configuration as well as app routes.

Public responses/pages use `Cache-Control: no-store`, no service-worker/offline persistence, no search indexing/sitemap inclusion and a restrictive referrer policy. Avoid third-party analytics on token routes and redact token paths from request logs. Use generic link-preview metadata for v1 so unfurl services do not retain itinerary details. Revocation blocks subsequent reads; already displayed/downloaded content cannot be recalled. Rate-limit public reads/copy operations and avoid exposing private data through error bodies.

## Implementation order and completion criteria

1. **Reconfirm context and skills.** Check current worktrees and applicable instructions. Discover/read the skills in the table for the work being started, preserving existing unfinished work. Record product assumptions from this proposal so implementation does not silently introduce collaboration or Explore listing.
2. **Contract, privacy and UI design.** Apply `security-review` to the planned trust boundaries and `frontend-design` to the design rehearsal above. Define public DTO, options, permission matrix and snapshot semantics. Finish owner/recipient wireframes and state handling before UI code. Add adversarial privacy fixtures including SAVED_PLACE, manual pins, nested costs, notes and derived route data. Update API/database documentation alongside the design.
3. **Publication service.** Read database-change and backend rules first; apply the security contract. Add the next unused Flyway migration after inspecting all branches, entity/repository/service/controller, exceptions, transactional version handling and owner authorization. Run schema/startup verification on disposable real Postgres, including rollback compatibility. Never modify V9 or another merged migration.
4. **Anonymous delivery and viewer.** Apply `security-review` to narrow gateway/BFF read rules and `frontend-design` to the isolated public route. Read relevant installed Next.js guidance before implementation. Extract reusable read-only cards from Explore; do not depend on mock authors/templates or the editable planner lifecycle. Verify payload, page HTML, metadata, map requests and error responses contain no excluded data.
5. **Owner controls.** Apply `frontend-design` to extend shared TripActionsMenu and build an accessible compound PublishPlanDialog with existing Dialog primitives. TanStack Query owns server state; Jotai owns dialog/view state. Add a real save-flush barrier covering pending debounces and metadata, with version-bound preview/publication. Test both dashboard and open-planner entry points and guest sign-in recovery. Check actual screenshots against the design brief.
6. **Independent copying and lifecycle.** Apply `security-review` to owner-controlled copy permission, authenticated sanitized cloning, retry protection, replacement and revocation. Apply `frontend-design` to copy/sign-in and link-management states. Exercise simultaneous save/publish, two owner tabs, deletion and expired sessions.
7. **Focused review and validation.** Read/apply `anti-ai-ui-review` to the rendered feature and `security-review` to the completed request paths. Fix evidenced issues and rerun the affected checks. Use `optimization-review` only if performance evidence warrants it. Run TypeScript/targeted lint; service authorization and mapped-exception tests (`*Tests`); gateway/BFF route tests; Postgres schema tests; browser journey with owner account A, unrelated account B and a signed-out browser. Verify mobile layout, light/dark themes, keyboard focus/trap/return, Escape, screen-reader status feedback and clipboard failure. Record which skill guidance shaped the result and what remains unverified.
8. **Handoff and authorized release.** Update session records and API/database documentation. Follow the documented child-to-parent dev/release process only when implementation/release is requested; read release instructions before any main merge. Preserve existing uncommitted work and do not commit local `.claude/` skill files.

Must-pass outcomes: B cannot edit A's original by calling APIs directly; an anonymous visitor can open only the sanitized shared snapshot; new private edits do not appear until update; published content matches its preview; included costs/notes/dates obey options; private anchor data never appears in network responses or route queries; revocation/replacement/deletion defeats a fresh fetch; an existing copy remains independently editable; failed saves never publish stale content; repeated clicks do not create duplicate links or trips.

## Addendum 2026-09-26: listing on Explore (implemented, uncommitted)

The user asked for published plans to be shareable to Explore, reversing "no Explore listing in v1" above. What was built:

- **Separate opt-in.** `trip_publication.listed_in_explore` (default false) and `listed_at` were added to the never-merged V13 in place. A CHECK constraint refuses a listed row that is REVOKED or has no `listed_at`; a partial index serves the feed. Listing reuses the frozen snapshot and the same token: it adds discovery, not content.
- **Owner API.** `PUT .../publication` takes `listInExplore` (absent means unlisted, so an Update never silently keeps a listing). `PATCH /v1/trips/{tripId}/publication {listedInExplore}` lists or unlists immediately without re-publishing; it returns 409 when nothing is published. Stop sharing also unlists. Re-listing keeps the original `listed_at`, so Update does not bump a plan to the top of the feed.
- **Anonymous feed.** `GET /v1/shared-plans?page&size` (page size capped at 48) returns `ExplorePlanSummary` cards built from each frozen snapshot by `ExplorePlanSummarizer`: title, destination, counts, the first place photo, up to three highlights, and per-day stop kinds for the route strip. The query selects only listed, active rows with a current sanitizer version. The gateway permits exactly `GET /v1/shared-plans` and `GET /v1/shared-plans/{token}`; `SharedPlanResponse` now carries `listedInExplore`.
- **Client.** The dialog has a "List on Explore" row plus an access row, "Anyone browsing Explore: View only". Explore shows a "Shared by travelers" section (server-fetched first page, TanStack infinite query for "Show more"), and search/filters merge shared plans into the same results grid. Cards open `/explore/shared/{token}`, which uses the same header and renderer as the link page but serves only plans that are listed right now.
- **Known trade-off, stated in the UI:** unlisting hides the plan from Explore but does not stop the link. Anyone who opened it from Explore keeps a working `/share/plans/{token}` URL until the owner stops sharing.
- **Author byline (added the same day at the user's request):** `trip_publication.author_display_name VARCHAR(120)` (also in V13) stores the owner's display name, frozen when they publish, like a byline. The client sends it from the owner's profile (`/api/users/me`, falling back to the session name) in `PUT` (replaced on every publish) and in `PATCH` (refreshed on listing; null keeps the stored name). `PlanPublicationSanitizer.sanitizeAuthorName` makes it one line, strips control characters, and caps it at 120 code points. Blank becomes null, which renders as "a Navio traveler". It appears on Explore cards, `/explore/shared` and `/share/plans` as "Shared by …" with an initials avatar. There's no photo: fetching one would need the owner's account id, which the anonymous routes never carry, and user-management profile lookups are authenticated-only by design. The dialog states "Shown as *name*" with a link to profile settings before anything is published. The name is owner-supplied display text, not verified identity, and is no more trusted than the profile display name, which owners can already set freely.
- **Not built:** moderation or reporting of listed plans, server-side search (search only covers pages already loaded), and copying from Explore.

## Worktree note

Inspected root/client/server/trip-planning on `dev`. Existing client UI work and both agent notes were already uncommitted. This session changes documentation only; no feature implementation, application tests or deployment. Preserve unrelated edits.
