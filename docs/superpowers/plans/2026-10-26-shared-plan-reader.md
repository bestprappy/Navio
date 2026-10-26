# Shared Plan Reader Implementation Plan

**Goal:** Implement the approved dedicated trip reader for UI review, preserving published planner data and copying.
**Architecture:** Shared-only presentation adapter, Jotai reading/navigation state, isolated map and card, existing PlannerWorkspace/brand components. No normal planner/map changes, backend/schema work or social/publication persistence. Real public data only on live pages; fuller publishing/Garage/list scenarios in development-only preview.
**Tech:** Next App Router, TypeScript, Jotai, TanStack Query, existing Google/Mapbox providers and Base UI.

- [x] Model/state tests: stable stop occurrence IDs, counts exclude notes/checklists, no original mutation, day/list following without camera moves, dismissed panel, related-plan ranking and safe dates; then implement pure adapter/state.
- [x] Dedicated reader: hero using real/bundled cover, compact owner/summary, contents, optional Garage/lists/budget, All dates/By date reading cards, feedback drafts and related real plans. Preserve existing copy button and underlying public snapshot. Add explicit development-only fixture and publication preview controls.
- [x] Isolated map/card: shared provider appearance, grouped visit pins, active group navigator and explicit camera commands; Overview/Photos/Reviews/In this plan, links, galleries/dialogs. Keep map visible, responsive and keyboard accessible. No global map changes.
- [x] Verify regression tests, full TypeScript/lint/test/build, visual/interaction checks if runtime permits, independent fresh review and fixes. Update agent notes and docs-only local dev commit.

Binding decisions: Catalogue cars default included unless excluded; custom cars require explicit decision. Lists opt-in. Copies carry published setup into the trip only, not account Garage, once persistence is implemented after UI approval. This phase never copies fixture/local drafts or claims new content is persisted. Save/share basic preview UI; comments/rating drafts not posted. Existing real copy endpoint unchanged. Author's planner owns content; no generated article/general guide. Deferred Places editorial remains disabled/excluded from reports.

Ruling: Keep existing dirty checkout instead of another worktree, because the approved reader depends on the uncommitted cover/card work and must appear in the running user workspace. Preserve all unrelated source. Cost: shared checkout requires narrow file ownership and diff review.
Ruling: New Garage/list/cover publication UI remains development-only; public pages omit fields absent from the public snapshot. Do not fetch private account data or invent published content. No backend publication changes before UI approval.

Verification ledger: 481 active frontend tests, TypeScript and scoped lint pass. Development preview HTTP200 and server-rendered cover present. Browser Sky initialized and discovered Chrome, but access approval timed out; CUA inventory has no browser connector. No live browser visual/keyboard claim. Independent review and production build pending.

Final evidence: all483 active tests, TypeScript, scoped lint, whitespace and production build pass; nine reader tests. Both actual listed page and development preview HTTP200 with photo and reader markup; production fixture artifact confirmed404 and no fixture. Reviewer found thumbnail/credit nesting, fixed with regression, and no remaining important findings on recheck. Final temporary file-input focus/reset refinement passed tsc/lint. Browser visual/mobile/keyboard acceptance remains pending due app-access timeout.
