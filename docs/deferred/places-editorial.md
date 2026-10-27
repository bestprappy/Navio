# Deferred: Places editorial articles

Status: DEFERRED - DISABLED - EXCLUDE_FROM_REPORT
Feature ID: PLACES_EDITORIAL
User decision:2026-10-22. Prioritize more important functionality. Do not resume without a new user request.

## Current behavior restored
The Places reader uses its previous Google provider description near the title, photos/gallery, practical information and map. There is no Navio article, Read the story control, prepared article catalog lookup, publication gate or midnight review timer in the active page. Existing reader layout, zoom/scroll behavior, provider credits and Add to Plan remain. Earlier planner empty-day plus and Saved places shortcuts remain active; they are separate work.

## Preserved experiment (not an active product feature)
The trial implemented one original article per eligible exact place ID, a visible introduction and expandable story,250-500 word publication budget, sources per passage, review dates/status/expiry, reading time and live credited photos. Three sample entries were prepared for Tuileries Garden, Grand Palace and Wat Pho (362/389/391 words). These samples are not comprehensive coverage. No automatic worldwide discovery/research/writing pipeline was implemented.

All code in these client files is line-commented, including imports/exports:
- app/feature/explore/places/place-article.tsx
- app/feature/explore/places/place-article-model.ts
- app/feature/explore/places/place-articles.data.ts
The import and JSX integration in place-reader.tsx are commented out.
The original article tests are preserved, also line-commented, as tests/explore/place-article.deferred.mjs; they are intentionally outside the active *.test.mjs suite. Do not count their historic passing results as verification of a currently available feature.

Each file has BEGIN DEFERRED IMPLEMENTATION / END DEFERRED IMPLEMENTATION markers. The original source is preserved by prefixing each original line with exactly three characters: slash, slash, space. To recover it later, take only lines between the markers and remove exactly that prefix from each line. Do not remove arbitrary comments from the code. The existing active reader regression ensures the article remains absent and the provider description is restored even for a previously catalogued place.

## Future direction, if resumed
Eligibility should depend on adequate official records and reliable independent evidence, not fame or review counts. Prepare/review/store original articles in advance, then associate them with place identities. Batch by destination and expand coverage over time. A candidate list is not a complete global inventory; exhaustive coverage of every eligible place cannot be promised. A scalable content workflow and sustainable maintenance capacity remain unresolved work, not something the prototype accomplished.

Preserve these principles: original prose based on independently accessed official/institutional sources; no rewriting Google editorial summaries or reviews into stored Navio articles; source traceability and explicit attribution for live Google data/photos; no on-click article generation; no filler to reach a word count; supported activities and expiry review. Wikipedia can lead to stronger references, not stand alone for important facts. Recheck current API terms and source reuse conditions before resuming.

Plans and research remain in docs/places-editorial.md, docs/superpowers/specs/2026-10-22-place-article-editorial-proposal.md and docs/superpowers/plans/2026-10-22-place-article-editorial-implementation.md. Their old completion/checklist statements describe the experiment only. Source checks from2026-10-22 and due dates2027-01-20 must be revalidated; do not simply enable stale entries. Notre-Dame is an example eligible candidate, not a researched/stored article in the trial.

## Reporting exclusion (binding user preference)
See docs/agents/report-scope.md. Exclude this entire feature, its algorithms, prepared examples and future coverage workflow from reports, report revisions, screenshots/feature inventories, claimed results and testing evidence. Do not quietly include it in a future-work chapter. Keep development history and this deferred note for engineers. Only an explicit user instruction to change report scope lifts the exclusion.
