# Shared Plan search: intent relevance revision

Status: User approved proceeding. Implemented and verified locally 2026-11-03; not deployed. Execution ledger and detailed implementation/test report supersede earlier proposal status wording. Month/day-only publication overrides original year-verification paragraphs below.

## 2026-11-03 amendment: published dates omit year

The user requests that published plans carry only month and day, not the original year. This overrides all explicit-year/public-year matching proposals below. Private planner dates remain full dates. Structured public API payloads, publication previews, readers, summaries and copy responses must not expose the original year; merely hiding it in UI is insufficient. Do not strip years from freely authored prose, which is separate from structured travel-date publication.

Introduce an explicit month/day public value with ordered itinerary/day offsets rather than assigning a fake constant year. Preserve duration and ordering across Dec/Jan. Display e.g. Dec 25 or Day 1; weekday names require a year and must not be inferred. includeDates=false still omits month/day too. Seasonal relevance uses published month/day and public event text, never private years. A typed year cannot be verified against a yearless plan; communicate that limitation rather than claim a year match or infer an author's original travel year. Event instances that require a specific year need explicit independently public evidence and reviewed handling.

Copying retains the previously approved date-choice flow but cannot offer original full-date retention once the original year is no longer published. Offer the same month/day with a reader-selected year or new dates; require an explicit destination trip start date before creating full planner dates. Preview Feb 29 adjustments and Dec/Jan rollover; no silent invalid-date normalization or original-year reuse. Recheck all publication/copy consumers and existing published snapshots: project legacy dates into yearless public values on reads; no read path (including raw public snapshot endpoints) may leak legacy structured years. Never make old published links disappear solely because a new date representation is introduced. Define rolling-version API compatibility before coding; preserving privacy can conflict with old consumers expecting ISO LocalDate. Do not claim this is only a label-formatting change.

Thorough pre-completion testing is mandatory: representative judged search queries, top-result precision and negative relevance, both autocomplete groups, whitespace/caret/IME/races, hard filters, pages/deduplication, privacy, API failure, and real PostgreSQL. Add yearless publishing/read/copy round-trip, existing snapshot compatibility, Feb 29, crossing New Year, omitted dates and absence of year/weekday leakage. Source plan private full dates must remain unchanged. Concrete updated implementation contract requires review before date DTO changes.

## Findings

The released search is working as coded, but its relevance contract is too weak. Both `PlanSearchQuery.match` and `knownPlanSuggestions` accept a country anchor alone as related evidence. Thus Thailand Christmas returns arbitrary Thai plans. `buildPlanSuggestions` explicitly appends itinerary/road trip/weekend trip to every country. The dropdown also substitutes related titles only when matching titles are empty, instead of displaying the two groups together.

PublicDayDto.date and public snapshot start/end dates are removed by the sanitizer unless publication includeDates is enabled. Search must never join private trip dates to fill this gap. The current frontend summary lacks sufficient event/date evidence, so fallback suggestions must be conservative rather than guess.

## Recommended approach

Revise the existing service and API additively, with a shared relevance contract and representative judged fixtures. A separate search engine can improve large-catalogue retrieval but does not solve incorrect intent eligibility. Do not introduce Elasticsearch, a paid service, an LLM per keystroke, or query-history collection for this revision.

### Query interpretation

Extract geography, explicit duration, event/month/year, activities and specific remaining concepts. Normalize Unicode/case and known aliases; correct only bounded unambiguous typos. Keep the raw draft unchanged. Partial final tokens support autocomplete, while committed result searches evaluate complete concepts. Preserve multiword entities (Hua Hin) and ambiguous city disambiguation.

Country/duration constraints remain mandatory. A named city must not silently relax to its whole country. Christmas, sushi, family, etc. must not disappear because generic travel words match. Avoid treating every term as a broad synonym; sushi is not equivalent to all food and Christmas is not equivalent to winter.

### Matching and Relevant

Matching requires every essential query constraint plus at least 90% weighted meaningful-concept coverage. Essential geography, events, explicit time and specific activities cannot be omitted even if a numerical threshold passes. This is evidence coverage, not a claimed probability or displayed confidence percentage. Exact names/phrases rank above aliases, public content evidence and bounded fuzzy matches; popularity only breaks relevance ties.

Relevant requires compatible geography and evidence for each essential intent, permitting documented alternatives such as Christmas wording replaced by public December dates. Country overlap alone never compensates for an absent activity or event. Unknown modifiers must not be discarded just to produce results. Return fewer or zero titles when evidence is insufficient. Pools are disjoint, paginated consistently, and obey selected filters.

Christmas policy proposed: public December itinerary dates qualify as broad seasonal relevance; overlap around December 25 ranks higher. Public Christmas-specific text can establish Matching when the rest of the query matches. December dates alone do not prove Christmas activities. Explicit years must agree. Hidden/missing dates do not establish temporal relevance. Qualify using actual itinerary days or a short public trip interval, not an unchecked huge date range. Multiple independent intents must agree; contradictory public evidence is not strengthened by keywords. Movable/local holidays need a verified country/year calendar entry before date inference, otherwise use explicit public textual evidence only.

Reasons must name the evidence (e.g. "Public trip dates in December"), not just "Also in Thailand". Apply the same rules to autocomplete titles and result cards. Legacy response names can remain internally during rolling deployment; visible labels become Matching plans and Relevant plans.

### Suggestions

Show Destinations, Suggested searches, Matching plans and Relevant plans as distinct groups. Show both title groups when available, with compact honest empty states. Retain accessible keyboard navigation, stable focus, live debounce, cancellation, IME and the existing space/caret fix.

Remove unconditional three-template expansions. Candidate phrases come from normalized public titles, real public destinations/place names, and a curated travel vocabulary of activities/events. Complete the unfinished word while preserving the rest of the query, including its modifiers. Curated vocabulary supports general travel-language completion even when the catalogue has no plans; it must not claim inventory or invent a plan. Label the literal search action separately from a suggestion. Rank prefix/phrase compatibility, preservation of intent, public-catalogue support and diversity; deduplicate variants. Do not replace an unknown modifier with generic country phrases. At a fully complete rare query, show the literal action and only defensible refinements; do not pad with unrelated suggestions.

Expose corpus-backed suggestions through the backend across the full eligible catalogue, not just initial trending cards. Keep lightweight country/word completions available during API outages. Do not make incomplete local summaries guess event/date-related titles. Bound candidate sets and cache only with explicit listing/revocation freshness handling; do not make a new stale public-content cache without invalidation.

## Acceptance and evaluation

Create judged query/plan fixtures before ranking changes: Thailand; Thailand Christmas; Thailand Christmas 2026; Christmas dates shared/hidden/missing; city+food; Hua Hin scenic food; California food; sushi vs generic restaurant; ambiguous Paris; typos; long/unknown phrases; contradictory geography. Include negative examples of popular but irrelevant plans. Check top-five precision and ranking, not only returned counts. Irrelevant country-only Christmas results must be zero; public-only eligibility and hard filters must hold for every group.

Verify phrase variation by actual corpus/context, query-modifier preservation, independently empty title groups, no duplicates over pages, no false count claims, client fallback/API consistency, raw repeated spaces, caret, IME, stale-response races, history, keyboard and mobile. Run frontend, backend and real PostgreSQL integration checks appropriate to the changed paths. Any VM deployment is a separate concrete release step; no deployment is implied by this proposal.

## Primary references

- Elastic Boolean query: required/filter constraints are distinct from optional ranking boosts. https://www.elastic.co/docs/reference/query-languages/query-dsl/query-dsl-bool-query
- Algolia Query Suggestions: candidates can come from real data before enough analytics exist, with normalization, deduplication and result-support thresholds. https://www.algolia.com/doc/guides/building-search-ui/ui-and-ux-patterns/query-suggestions/ios
- Elastic Ranking evaluation: use representative queries and manually judged results to measure precision/ranking rather than assuming successful responses mean useful search. https://www.elastic.co/docs/reference/elasticsearch/rest-apis/search-rank-eval

These references inform the design; they do not prescribe adopting their products. The event/date policies and thresholds above are Navio design recommendations requiring validation against the catalogue.
