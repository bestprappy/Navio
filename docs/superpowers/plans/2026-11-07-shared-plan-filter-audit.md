# Shared Plan filter polish and offline search audit

**Goal:** Implement the user's precise three control adjustments and audit at least 100 varied search/filter combinations without Google requests.
**Architecture:** Reuse existing sorting state and Base UI Select. Exercise the actual Java search engine with controlled test-only publications and an empty catalogue; do not create or publish sample plans. Keep existing matching/relevant/alternative semantics and filter conjunctions.
**Constraints:** No Google API, photo, map, geocoding or route requests. No billing/key changes, production mutations or release. Preserve teammate files and generated tsconfig. Custom Cover/categories and Places editorial remain paused.

- [x] Baseline existing client search/state tests; reproduce Recommended being an editable checkbox and native duration menu in a provider-blocked browser.
- [x] Render Recommended as a non-interactive selected/inactive status in a separate panel above sort checkboxes, with explanatory text; retain automatic relevance fallback and draft Apply/Reset semantics.
- [x] Prevent Filters count wrapping; use existing styled Select for Days/Months/Years with accessible keyboard navigation.
- [x] Add and run a reproducible audit of 100+ distinct query/filter combinations, including all user examples, country-only, duration-only, both, conflicts, sorts, themes/collections, empty catalogue and suggestions. Record real outcomes and unresolved vocabulary limitations rather than fabricate matches.
- [x] Run full frontend suite, type/lint/build and relevant backend search/controller/repository checks; browser-check desktop/mobile/light/dark and zero provider egress.
- [x] Review changes, integrate verified client into active checkout preserving unrelated work; commit feature fixes on fix branches and required notes via docs branch to dev only. No main push.
- [x] Deliver short implementation/test summary with evidence and limits.

Completed: client dd76a97 and Trip c2c0337 on dev. Evidence and unresolved search limitations are recorded in docs/reports/2026-11-07-shared-plan-filter-search-audit.md. No VM release.
