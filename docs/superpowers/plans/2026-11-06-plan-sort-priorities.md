# Shared Plan ordered sorting

Approved design: only Sort by expands inline inside existing Filters popover; checkboxes select multiple priorities, earlier/later buttons reorder them; collapse retains draft; existing Apply/Reset and cancel-on-close preserved. Recommended is the exclusive default, restored when last metric is removed. No provider/sample work or automatic deployment.

## Architecture and decisions
Reuse PlanSearchState.sort and existing public sort parameter as an ordered comma-separated string (single values remain compatible). Strictly validate <=6 unique explicit metrics, rejecting empty/unknown/duplicate/default-mixed lists. Keep Matching/Relevant/Alternatives membership unchanged; apply lexicographic sorting within each bucket. Explicit secondary criteria precede legacy single-sort tie-breakers (rating count, views), followed by event proximity and stable listedAt/token fallback. Include ordered string in request fingerprint and mutable metrics in catalogue revision. Existing per-section default sorts remain when Recommended selected.

UI: reusable SortPriorityControl with accessible expansion trigger, labeled native checkboxes, priority badges and labeled reorder buttons. Only the sorting subsection expands; outer popover stays. Replace the redundant results-toolbar single-select with an accurate ordered summary, so sorting is edited in the one approved Filters control. Token styles, viewport bounds, keyboard focus, responsive text, light/dark and reduced motion. No dependency/schema changes.

## Task 1 - End-to-end sorting contract (RED/GREEN)
- Client tests in tests/explore/plan-sort-priorities.test.mjs: valid ordering URL round-trip, malformed input fallback, toggle/removal/reset/reorder behavior, draft preserves latest query/country; proxy accepts order and rejects invalid lists.
- Trip tests in PlanSortPriorityTests: rating ties resolved by views before rating count, reverse priorities change ordering, newest as secondary, stable pagination/fingerprint and invalid lists. Reuse SearchTestFixtures.
- Implement search-state helpers/types, proxy validation, SmartPlanSearchEngine comparator chain and PlanSortOrder parser.
- Run focused tests then full client/Trip regressions with realPG, type/lint.

## Task 2 - Expandable UI and verification
- Replace Sort by select in plan-filters.tsx with reusable sorting subsection, preserve outer Apply/Reset state and popover, adjust existing toolbar and summaries consistently.
- Real browser tests: expand/collapse retains draft; select/reorder; close discards unapplied draft; Apply URL order; Reset restores default; keyboard/mobile/dark no overflow or runtime errors. Use disposable local backend against realPG for backend ordering; no production writes/mocks as evidence of real data.
- Fresh whole-branch review per executing-plans. Fix Important/Critical findings with regression tests. Commit feature branches, integrate active frontend only with compatible backend release approval; do not expose broken multi-sort against old VM. Ask concrete VM release approval after verified implementation.

## Progress
- Approved by user; existing isolated client/Trip worktrees reused on feat/plan-sort-priorities-20261106, based on current dev. Ordinary user tsconfig/CLAUDE preserved.


## Verification ledger
- Contract RED: old client lost ordered URL sort and lacked toggle helper; old Trip rejected rating,views and views,recent. GREEN: focused client6 and Trip11 passed, then full client701 and Trip658/0fail/0error/5existing skips (realPG).
- Actual local Next3111 + Trip18084/disposablePostgres: multilist200, malformed400, expanded/collapsed draft, reorder, Apply/Reset/cancel, keyboard, mobile/dark passed without page runtime errors. Two final visual defects were reproduced with clickability assertions and repaired: fixed footer keeps Apply/Reset outside scrolling body; sticky Sort heading keeps collapse control reachable. Browser rerun passed.
- Fresh whole-branch review: no Critical/Important findings. Minor (deferred test coverage): dedicated Newest+Events precedence case. Design ruling: explicit Newest is primary before event proximity, consistent with user-selected ordered priorities; previous implicit event proximity takes effect only after explicit metrics. Single default sorting otherwise retains legacy fallbacks. Cost if wrong: users wanting closest event date first should leave Recommended rather than Newest selected.
- Temporary worktree-only Turbopack root adjustment is necessary because node_modules junction points to ordinaryclient. Restore next.config and generated isolatedtsconfig before commit. Ordinary usertsconfig remains untouched. Offline jar packaging lacked cached Maven plugin dependency; cached spring-boot:run used successfully for real HTTP browser tests; no dependency/product change.
- Deployment is not authorized for this new revision yet. Do not integrate multi-sort frontend into active dev:vm while VM rejects its new ordered parameter. Finish verification/feature commits, ask concrete release approval once.

Final verified feature revisions: client7644ac8/Tripd7692ea. User approved VM deployment; release now authorized, not pending permission. Full final client701/types/lint/build and browser regression pass; Trip658 with5 existing skips.
