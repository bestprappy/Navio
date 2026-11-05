# Discovery and Saved Guides Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. Track verification in the execution ledger below.

**Goal:** Ship the approved five discovery sections, working filters/sorting and Saved Guides.
**Architecture:** Extend public publication evidence/ranking and IAM's existing bookmark lifecycle. Guide storage is additive and opt-in in mixed responses, protecting old clients and rollback. Reuse the existing UI/query/auth components.
**Tech Stack:** Next.js/React/TypeScript/TanStack Query; Java/Spring/JDBC/PostgreSQL/Flyway.
**Spec:** `docs/superpowers/specs/2026-11-05-shared-plan-discovery-saved-guides-design.md` (user approved).

## Global constraints

Custom Cover and custom categories stay on hold. No private date years, no fabricated activity or event eligibility, no per-card remote calls. Keep the running checkout/configuration unchanged. New root-main deployment requires separate release approval.

## Review focus

- Old clients receiving GUIDE must remain impossible without explicit opt-in.
- OR collections and AND dimensions must constrain all search buckets and alternatives.
- Calendar rollover and contrary public dates must not admit incorrect event plans.
- Trending and rating changes must not cause silently duplicated pagination.
- Unavailable guide references must retain private ownership and allow bookmark removal.

### Task 1: Discovery eligibility, ranking and activity

Files: Trip `service/publication/PlanDiscovery.java`, `repository/PublicationActivityRepository.java`, next additive migration, `SmartPlanSearchEngine.java`, `SharedPlanSearchService.java`, `SharedPlanSearchController.java`, `TripPublicationService.java`.
Interfaces: `PlanDiscovery.Filters(Set<String> collections, Set<String> themes)`; evidence eligibility and comparator use public snapshots and aggregate statistics. Existing six-argument search remains compatible; filtered overload supplies Filters. New landing requests reuse public search with empty term and a collection parameter rather than a new gateway route.

- [x] RED: focused tests for seasonal month, Christmas contrary/no dates, Easter/calendar rollover, collection OR/theme AND, score/tie/rating nulls.
- [x] GREEN: pure eligibility and comparator; activity daily SQL plus transactional view/copy recording; filtered public search before pagination/suggestion support checks.
- [x] Verify: focused tests and full Trip tests; real PostgreSQL migration/upgrades/old ORM compatibility.
- [x] Commit owned Trip files on feature branch after dev sync.

### Task 2: Discovery UI and filter contracts

Files: client shared-plan `search-state.ts`, `search-api.ts`, `search-controls.tsx`, `shared-plan-search.tsx`, new `discovery-sections.tsx` and `plan-filters.tsx`, public search proxy.
Interfaces: URL state adds collections/themes; sort accepts relevance/recent/trending/popular/views/rating/discussed. Five landing queries use existing card/grid, six per initial page and independent infinite pagination.

- [x] RED: URL parsing/serialization, invalid selections, request query forwarding and active-mode tests.
- [x] GREEN: single draft Apply/Reset filter popover; chips; landing-vs-results behavior; catalogue-aware cache keys and pagination reset.
- [x] Verify: search regression/model tests, typecheck/lint/build and browser keyboard/mobile.
- [x] Commit owned client discovery files.

### Task 3: Saved Guides service and compatibility

Files: IAM `library/LibraryContracts.java`, `SavedLibraryController.java`, `SavedLibraryService.java`, `SavedLibraryRepository.java`, new guide companion migration/repository, existing guide services consumed for visibility metadata.
Interfaces: `POST /v1/users/me/saved/guides` accepts guide ID/source; list `includeGuides=true` explicitly opts into GUIDE and guide counts. Legacy requests keep PLAN/PLACE only. Reuse IDs/actions/state envelopes and user locks; guide limit 50 independent of plan limit.

- [x] RED: public-only resolution, ownership, duplicate/concurrent save, quota, restore, trash/expiry, old/new contracts and mixed paging tests.
- [x] GREEN: guide companion storage and guide-inclusive UNION listing, merged states and private actions; source-aware reader reference.
- [x] Verify: full IAM and real PostgreSQL fresh/upgrade/rollback with guide rows; legacy request remains valid against new backend.
- [x] Commit owned IAM files after dev sync.

### Task 4: Saved Guides UI and integrated checks

Files: client saved library API/model/page/save-button, guide card/reader and curated guide rendering where publicly addressable; saved proxy allowlist if needed.

- [x] RED: GUIDE contract, route identity and mutation payload/state tests.
- [x] GREEN: highlighted Save icons with separate interactive targets; Guides tab and mixed Recents/All/opened; 50-guide indicator; unavailable state; search/trash/restore.
- [x] Verify: frontend suite/typecheck/lint/build; isolated integrated browser guest/signed-in, both themes, mobile, auth failures and old-server capability handling.
- [x] Final whole-branch fresh review, focused repairs, API/database/session docs and concrete release report. No production writes/deploy without new approval.

## Execution ledger

- Approval received. Isolated clean client/Trip worktrees branched from current dev; IAM worktree created from dev. User checkout remains untouched.

- Completed and pushed: client599ee7e, Tripb0f6c24, IAMce72041 on their isolated feature branches. No main merge or VM deployment.
- Final: frontend698pass; Trip650total/0fail/0error/5skip; IAM317total/0fail/0error/2skip. Actual PostgreSQL fresh/upgrade/previous-model checks, tsc/lint/build and integrated browser acceptance passed. See docs/reports/2026-11-05-discovery-saved-guides.md for setup corrections and provider-test limits.
- Fresh whole-branch review found stale409 pagination recovery and minor event ordering/unavailable-state issues; repaired with focused regressions and actual browser rerun. No Critical/Important findings remain.
- Decisions: expose only evidence-supported themes (no City); Seasonal uses calendar month fallback without weather claims; event proximity means shared travel date alignment. Guide-inclusive reads remain explicit opt-in and use separate storage.
- User checkout/config preserved, test-only Next root config restored. Owned services stopped; worktrees kept. New release approval still required.
