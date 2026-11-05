# Shared Plan Feedback Implementation Plan

> Execute inline with superpowers:executing-plans. User approved the placeholder inventory, excluding Custom Cover, and requested existing components be reused.

**Goal:** Replace local rating/comment/share previews with persisted Shared Plan feedback and existing link-sharing behavior.
**Architecture:** Trip owns feedback keyed to an active publication, not private copies. Existing Spring controller/service/exception patterns, additive PostgreSQL migration, token visibility guards and gateway identity propagation. Reuse existing Dialog/SharedLinkField, Button/Textarea, session and TanStack Query; share one link action across card and reader. No new dependency.
**Spec:** docs/features/shared-plan-placeholder-inventory.md plus user approval: Custom Cover on hold.

## Decisions

- Public reads only for active listed publications at current sanitizer version; feedback disabled on unlisted links and previews. Mutation requires gateway identity. No rating own plan; one 1–5 score per account, editable/removable. Public aggregate only, no voter identities.
- Comments plain text up to 1500 characters, authenticated author display name supplied like existing publication bylines and sanitized; never use email. Stable paginated top-level comments and independently paginated single-level replies. Deleted parent retains a tombstone. Authors edit/delete their own; publisher may remove abusive comments. Report reason limited/validated, one report per account/comment; publisher can inspect reports within this plan. No fabricated automatic moderation or user reputation score.
- Feedback is publication-specific, survives normal snapshot updates; revoked/unlisted/stale publications expose no feedback. Copy never copies reviews/comments/ratings into personal planner.
- Rating aggregates on existing public response/card DTOs, same values on search/feed/detail; per-publication counters updated under publication-row transaction lock. No N+1 rating queries and no stale count cache.
- Reader shares actual published link by reusing card dialog. No cover, Guides/custom categories, Community behavior, new filter/section or deployment changes in this phase.

## Tasks

- [x] Backend red tests for feedback authorization, lifecycle, validation and aggregate contract.
- [x] Add new migration after current V26; ratings/comments/reports and aggregate columns, additive only. Implement small DTO/repository/service/controller with mapped exceptions.
- [x] Wire public aggregate projections, anonymous GET gateway allowlist and authenticated Next proxies; verify spoofed identity cannot pass gateway.
- [x] Reuse share dialog; add typed feedback client/hooks and focused rating/comment components with login/error/pending/pagination/accessibility behavior.
- [x] Run targeted then full backend/frontend checks; disposable real PostgreSQL migration/JPA/feedback lifecycle/rollback compatibility and actual browser checks where available.
- [x] Review diffs, update API/database/feature docs and separate implementation/testing report. Preserve user's ordinary client tsconfig and other repos. Mandatory agent notes -> docs branch -> dev only. No VM deployment without release review/approval.

## Execution ledger

Implemented and published feature branches: client45e42e8/Tripdfe950d/server607ce0a. No release. Full verification/evidence in docs/reports/2026-11-05-shared-plan-feedback.md. Independent review's cached-data draft-loss and search invalidation findings corrected; browser regression confirms draft preservation after a real post-mutation failed refetch/retry. Composer success closes old editor before invalidation, avoiding a late callback closing a newly opened reply. Temporary test config restored, owned services stopped. Custom Cover remains on hold.

## Review focus

- Concurrent repeated score changes keep sum/count correct; content mutations do not change source plan version.
- No feedback from another publication, hidden/revoked/stale rows or cross-plan reply/report identifier.
- Blank/oversize/invalid score/parent/body and duplicate reports; deleted content is never served publicly.
- Guest/session changes do not retain other user's editable identity or drafts; failure retains unsent draft.
- Real empty vs unavailable state, correct average/count, keyboard controls, narrow layout and confirmation before deletion.
