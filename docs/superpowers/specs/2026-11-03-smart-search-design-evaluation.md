# Smart Search design evaluation — 2026-11-03

Scope: planning experiments only. No application source, VM deployment, schema changes, private data access or authenticated production writes. Existing live release65a4105 unchanged.

## Live baseline

Sixteen read-only API queries returned HTTP200. Observed Matching/Relevant/remote phrase counts:

| Query | Matching | Relevant | Catalogue phrases |
|---|---:|---:|---:|
| Thailand Christmas Holiday |0|0|0|
| Thailand Christmas Festival Trip |0|0|0|
| Christmas Weekend Trip in Thailand |0|0|0|
| Scenic Trip in Thailand |4|0|1|
| Thailand nature gardens forests mountains |0|0|0|
| Thailand nature like gardens forests mountains |0|0|0|
| Thailand mountains or gardens |0|0|0|
| Thailand mountains and gardens |0|0|0|
| Thailand without beaches |0|0|0|
| Thailand Holiday |1|0|0|
| Thailand Weekend |2|0|1|
| Jap |5|0|0|
| Thailand Christm |0|0|0|
| Japan sushi |1|0|0|
| Georgia nature |0|0|0|
| Thailand Christmas2026 |0|0|0|

Zero Christmas results are not proof of incorrect retrieval: the current public catalogue may contain no qualifying event evidence. The missing reconstruction capability is independently apparent in current source (tail-prefix/corpus completion, flat theme aliases, all residual terms mandatory). These remote phrase counts do not include the client's independent local prefix fallback; `Jap` can still display Japan in the UI. The year query returned the expected year-not-verifiable notice. Timings were recorded per request but this small sequential network sample is not a load benchmark.

## Offline policy experiment

Local script `output/smart-search-design-lab-20261103.mjs` compares evidence admission, not trained semantic retrieval. Controlled cases distinguish OR examples from AND, negative evidence, exact country/duration, explicit Christmas versus public December, festival/weekend conjunctions, year/ambiguity limits, public visibility, and meaningful query rewrites versus declared alternatives.

First run failed `Christmas weekend needs weekend evidence`: the prototype returned Relevant immediately after December evidence and skipped weekend. Fixed the design order to evaluate every required gate before classification. Final42 labelled cases and192 Cartesian evidence combinations pass. Composition spike creates a Christmas rewrite and distinct labelled festival/weekend/December changes, validates intent preservation and avoids padding a specifically festival-constrained query. Nature examples are preferences, not mandatory exhaustive categories: an evidenced waterfall itinerary can qualify too. Reproducible script: `docs/superpowers/experiments/2026-11-03-smart-search-policy-lab.mjs` (run from repository root with Node).

Five adversarial comparisons reject the country-only strategy and the every-mentioned-word strategy: those either admit unrelated Christmas coasts/excluded beaches or reject a valid mountain itinerary under nature examples. Structured constraints produce the expected labels on those five annotated cases.

## What this does not prove

- Raw natural-language parsing correctness: admission inputs are manually annotated.
- Actual relevance precision/recall or coverage of current inventory.
- Quality/cost/latency of any LLM/vector model (none was run).
- Production UI, async behavior, database index/cache correctness or throughput.
- Universal seasonal/event/accessibility/cost understanding.

The final proposed spec/implementation plan therefore requires240 judged raw queries, isolated PostgreSQL integration, browser regression and1k/5k concurrency measurements before launch. Do not describe this planning lab as an implemented or fully tested smart search system.

## Recommendation

Implement structured travel intent, directional concepts, compositional suggestions and evidence-first ranking in the existing search service. Keep inference bounded and explicit; leave a compatible retrieval interface for measured future hybrid/vector candidates. No per-keystroke LLM or new search server initially. See `2026-11-03-smart-shared-plan-search.md` in specs and plans for full decisions and gates.
