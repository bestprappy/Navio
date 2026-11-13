# Shared Plan feedback implementation and verification

**LIVE 2026-11-05:** User approved VM release. Final root `0e341ac`, client `45e42e8`, server `b11f808`, Trip `dfe950d`; [workflow 42043762253](https://github.com/bestprappy/Navio/actions/runs/42043762253) completed successfully. Initial root6f9b1cd built/deployed healthy but omitted feedback gateway route predicates; read-only live checks caught404. Corrected both route configs, added actual-path regression tests and a deployment smoke guard. No schema rollback or unrelated service changes.

**Live checks:** Real public feed/detail rating/count projections and comments/privacy pass; reports and anonymous forged-header writes401, unknown token404, health200/protectedtrips401. Production and localhost3000 dev:vm feedback proxies200. Real deployed Chrome guest reader, share URL dialog, Explore cards and390px layout pass with no API mocks/page runtime errors. No authenticated production feedback writes were made. Evidence: output/feedback-live-api.json/.log, feedback-live-browser.log and screenshots. Deployment log explicitly confirms feedback routing/authentication verification.

**Corrective checks:** Gateway18total/0fail/1existing skip; configuration-server1pass; shell syntax clean; deployment smoke3pass including reproducing missing-route failure. These supplement the implementation verification below.

## Implementation

User approved implementing the placeholder inventory with Custom Cover explicitly on hold, then asked to reuse components and optimize. Completed scope is persisted plan ratings, comments/replies, author edit/delete, publisher removal/report review, and actual reader link sharing. Guides, custom Saved categories, filters and new default-page collections remain separate later work. No cover storage/upload changes.

Trip owns additive V27 ratings/comments/reports tables and three aggregate columns. Writes lock the publication row; unique user/publication rating and reporter/comment constraints prevent duplicates. JPA aggregate columns are non-updatable so publishing does not overwrite concurrent feedback counts. Feed/search/detail project counts from existing publication reads, not per-card rating queries. Plain-text rendering, ownership, current listed-publication guards and generic unavailable responses preserve boundaries. API contract: docs/api/Shared Plan Feedback.md.

Client reuses existing Button, Textarea, Dialog, SharedLinkField, authentication proxy/session and TanStack Query. SharePlanButton extracts the already-working Explore-card dialog for both card and reader. Composers are reused for comment/reply/edit. Lists use bounded pages, conditional reply loading, mutation pending/error states and deletion confirmation. Identity-scoped caches and keyed composers prevent cross-account draft/permission reuse. Invalidation includes feed, search and reader summary/comments. Existing Google Maps reviews remain separate.

Review corrected cached-summary error handling so failed background refreshes preserve drafts, fixed invalidation of search aggregates, and browser testing corrected an edit/reply success transition race. Custom Cover, unrelated Community/Admin components and user dev:vm process were not edited.

## Test results

- Red tests established missing backend/controller and missing typed frontend feedback implementation before production code.
- Full Trip suite: 643 tests, zero failures/errors, 5 skipped (3 existing MyListAppendPersistence concurrency cases; 2 opt-in SmartSearchHttpPostgres tests restricted to a different isolated fixture database). Feedback PostgreSQL tests cover concurrency, updates/removal, permissions, visibility, comments/replies/tombstones, stale edits, reports and pagination. Final focused run after adding cross-publication isolation: all10 tests passed (overlaps the full suite; do not add these as unique totals).
- Real disposable PostgreSQL16/PostGIS migration and JPA validation passed, including upgrade of existing publication data. Previous released Trip mappings also start against the newly migrated disposable schema: 1 test passed, supporting rollback compatibility.
- Full frontend suite after review fixes: 693 passed, zero failures/skips, using Node24 with the repository-required `--experimental-transform-types`. Exact tracked-config TypeScript and scoped ESLint passed. Final post-review standard Turbopack build passed. Temporary filesystem-root setting only resolves worktree node_modules junction and was restored before commit.
- Gateway suite: 17 total, zero failures/errors, 1 existing application-context skip. New checks explicitly cover public GET routes and rejection of guest writes/forged identity headers.
- Chrome against isolated frontend3111/backend18084 and synthetic PostgreSQL data passed guest/login state, share dialog/link, persistent rating/remove after reload, literal script text, comment edit/reply, publisher reporting/removal, tombstone replies, mobile width and draft preservation across failed background refresh/retry; no page runtime errors. Session and gateway identity were test-only browser bridges; this is not a live Keycloak signed-in production test. Unrelated profile/notifications APIs are unavailable on the isolated Trip-only backend.

- Actual Next proxy checks (no identity bridge): anonymous summary/comments200 with no private identity; reports401; forged-header rating write401; cross-origin comment write403; unknown resource404.

Implementation testing used only isolated data. Dedicated frontend3111/backend18084 and identity-verified disposable PostgreSQL stopped; temporary next.config/tsconfig restored. User dev:vm3000PID43460 unchanged. Initial feature branches were client45e42e8, Tripdfe950d, gateway/server607ce0a; subsequent authorized release and routing correction are live as recorded above. Custom Cover remains on hold.
