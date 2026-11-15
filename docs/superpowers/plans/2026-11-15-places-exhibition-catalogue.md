# Places Exhibition Catalogue Implementation Plan

Release 1 only. Fixed Bangkok collection, independently sourced descriptions, licensed bundled photos, provenance and approximate map points. Navio Team owns this exhibition snapshot; no scheduled maintenance. No Google Places search/detail/photo fallback. Existing provider-backed planner/Guides/Shared Plans remain unchanged.

- [x] Write failing catalogue tests: real identity, search/filter/time, pagination, missing-ID denial and zero provider fallback.
- [x] Prepare source-tracked catalogue; reuse discovery response contracts and controls. BFF discovery endpoints return catalogue only. Unknown catalogue IDs never leave Navio.
- [x] Reuse saved-location append; preserve catalogue identity through Saved/My List/itinerary/publication; locally resolve catalogue details in shared detail hook. No bulk migration.
- [x] Show source/coverage and honest editorial labels; retain existing viewport/map and no long-form deferred editorial feature.
- [ ] Verify tests, TypeScript/lint/build; browser walk catalogue/search/detail/Saved/add/reload/shared snapshot with provider calls intercepted. Count map/routes separately. Run fresh branch review.
- [ ] Integrate local dev only; report measured catalogue request elimination, remaining scope and deployment requirement. Release 2 requires separate approval.

819 client/tests and eight fixture browser checks pass. Real VM persistence checks await release approval.
