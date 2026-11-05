# Smart Shared Plan Search Implementation Plan

## Execution status — 2026-11-05

User's Proceed authorized implementation, followed by explicit VM release approval. Released client `bcf1d63` / Trip `66ea735`, including newer teammate dev changes, server `35afd9c`, root `5b2a2eb`. Workflow `41991110563` attempt2 succeeded and actual VM/browser/dev:vm proxy checks passed. Tasks 1–6 are complete to the extent recorded in [the detailed report](../../reports/2026-11-05-smart-shared-plan-search.md). Original checklists below are the planned acceptance inventory, not a claim that every individual scenario has its own independently executed test.

Final combined suites: 689 frontend pass; 634 backend total, zero failures/errors, 3 existing skips. TypeScript, scoped lint and standard Turbopack production build pass. Real PG/HTTP/browser checks pass. 240 controlled raw-query surfaces represent 24 intent families, not 240 independent topics. Holdout membership precision/recall and group-grade nDCG pass; 52/52 rewrites preserve labelled retrieval. Total JVM memory and browser latency percentiles were not separately sampled; cache memory is an estimated-weight bound. The final 1k API performance gate passes; 5k scan latency is slower and explicitly reported. Do not present these limits as universal semantic quality or VM capacity certification.

Fresh branch review's five important findings were repaired and verified: geography OR grouping, negation, exact calendar days, refetch revision continuity and pending empty-state rendering. No source loss on sleep. Runtime test startup/configuration issues were isolated from application changes. The approved main push and deployment are complete; no authenticated production data writes were made. Initial CI Google Fonts parsing failure resolved by retrying the same source, no font/library changes.

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task after design approval. Steps use checkbox (`- [ ]`) syntax. Do not start application implementation from this planning-only session.

**Goal:** Turn rough travel requests into useful natural search suggestions and evidence-grounded Matching/Relevant plans without changing the user's intent silently.

**Architecture:** A structured intent parser and versioned directional travel concepts feed a compositional phrase generator and one authoritative public-catalogue evidence pipeline. Every hard constraint is evaluated before ranking. Keep the existing API/client structure with additive assistance metadata and safe fallback; no new AI service/database migration required for the initial release.

**Tech Stack:** Java25/SpringBoot4, existing PostgreSQL16/Jackson, Next.js/TypeScript, TanStack Query, existing node:test and Java/Postgres tests. No new dependency is assumed.

**Spec:** `docs/superpowers/specs/2026-11-03-smart-shared-plan-search.md` (the final proposed behavioral contract).

## Global constraints

- Shared Plans search only. No Places/Guides/planner/navigation/auth/teammate UI changes or sample rewrites.
- Raw input is separate from normalized interpretation. Preserve trailing/repeated spaces, caret, IME/history and250ms debounce.
- Public dates remain month/day only; no private data joins or original year inference.
- Every required facet/exclusion is checked before classifying Matching/Relevant. Alternatives change intent only on explicit selection.
- Suggestions may exist without inventory, clearly identified; actual title suggestions must be real eligible publications.
- Current max100-character protocol must stay compatible until backend supports256 Unicode code points; no silent truncation.
- Current default landing, exact duration conversion and visual-only Interests stay as is.
- No deployment from this plan approval alone. Follow docs/agents/release.md at concrete release time.

## Review focus

1. Christmas date evidence must not bypass festival/weekend/negative constraints (Tasks2/3).
2. Examples/OR/AND/negative clauses must be parsed from raw text, not hand-labelled test input (Task1).
3. Public evidence and titles must disappear after unlist/revoke/update, even when cache warm (Tasks2/5).
4. A grammatical rewrite may not drop geography, quoted specifics or exclusions; alternative must declare every changed facet (Task3).
5. Slow responses and catalogue updates may not corrupt input, mix pages or relabel unavailable data as zero results (Tasks4/5).

## File map

Backend base `server/trip-planning-service/src/main/java/com/navio/tripplanningservice/service/publication/`:

- Create `search/SearchIntent.java`: immutable typed clauses, source spans, ambiguity and canonical interpretation.
- Create `search/TravelConcepts.java` and resource `src/main/resources/search/travel-concepts.v1.json`: versioned equivalent/directional relationships and grammar lexicon, with startup validation.
- Create `search/SearchIntentParser.java`: raw text to intent, including operators, modifiers, unsupported/conflicting requirements.
- Create `search/PublicSearchEvidence.java` and `search/PublicSearchEvidenceBuilder.java`: field/item-scoped public evidence and certainty.
- Create `search/PlanSearchEligibility.java` and `search/PlanSearchRanker.java`: hard gates, group classification, deterministic evidence order.
- Create `search/QuerySuggestionComposer.java`: bounded candidates, reparse/equivalence, alternatives and support-aware selection.
- Create `search/SearchAssist.java`: optional wire metadata, actions and versioned fingerprints.
- Modify `SharedPlanSearchService.java`: orchestration, single eligible stream, results/counts/groups/legacy compatibility.
- Modify `PlanSearchQuery.java` and `PlanSearchTemporalIntent.java`: adapters/delegation during migration; remove duplicated logic only after regression proof.
- Modify `repository/ExploreSearchRepository.java`: authoritative eligible revisions/projection only if needed to eliminate repeated parsing/streams; do not join private Trip.
- Modify `controller/SharedPlanSearchController.java`: additive capabilities/length/revision validation; preserve route/errors/security.

Backend tests under `src/test/java/com/navio/tripplanningservice/service/publication/`: create `SearchIntentParserTests.java`, `QuerySuggestionComposerTests.java`, `PlanSearchEvidenceTests.java`, `SmartSearchJudgedTests.java`; modify existing `SharedPlanSearchServiceTests.java`, `controller/SharedPlanSearchControllerTests.java`, `SharedPlanSearchPostgresTests.java`. Fixture JSON under `src/test/resources/search/` with separate development/validation/holdout sets.

Frontend base `client/app/feature/explore/_components/shared-plans/search/`:

- Modify `search-api.ts`: optional typed SearchAssist/capability/revision schema; preserve legacy enums/fields.
- Modify `search-suggestions.ts`, `data.ts`: backend assistance authoritative; minimal safe local prefix fallback only.
- Modify `search-controls.tsx`: suggestion/alternative/title groups, keyboard/action labels and conflicts.
- Modify `shared-plan-search.tsx`, `search-results.ts`: request fingerprint, revision reset, notices, honest errors.
- Modify `search-state.ts` only for validated capability-aware input bound; keep URL keys/defaults/conversions.
- Keep `search-draft.ts` behavior unchanged unless a new failing regression proves a required repair.
- Extend `client/tests/explore/shared-plan-search-suggestions.test.mjs`, `shared-plan-search-relevance.test.mjs`, `shared-plan-search-results.test.mjs`, `shared-plan-search-draft.test.mjs` and `shared-plan-search-proxy.test.mjs`; create `client/tests/explore/smart-plan-search.test.mjs` for new assistance-contract cases. Reuse the existing test runner, not a new framework.

## Task1: Intent contract, vocabulary and judged raw-language fixtures

**Interfaces:** `SearchIntentParser.parse(String raw, SearchFilters filters, GeographyCatalog geography): SearchIntent`. `SearchIntent` holds geography/required/excluded/preferred/example groups, temporal/duration clauses, unknowns/conflicts/source spans and conceptVersion. `TravelConcepts` exposes equivalent and directional expansion separately. Fixtures contain raw query, filters, expected intent and relevance labels.

- [ ] Write120 development +60 validation +60 holdout queries with expected interpretations/ambiguities and at least20 controlled publications; keep holdout separate from tuning. Include user's exact phrases and all spec challenge categories.
- [ ] Add failing raw-input tests for holiday filler versus public holiday, explicit AND/OR, “like” examples, comma ambiguity, specific subtype, negation scope, quoted unknowns, multiple/ambiguous geography and conflicting durations.
- [ ] Run focused tests and observe meaningful failures; implement immutable clauses, versioned concept graph and parser. Validate no cycles/contradictory aliases or duplicate concept IDs at startup. Do not silently add broad parent-to-child equivalences.
- [ ] Run parser/fixture validation tests; unknown/mixed language remains literal with honest notices. Commit scoped source/tests on feat branch fromdev.

**Acceptance examples:** gardens OR mountains accepts either; AND requires both; “not only gardens but also mountains” retains both; “not far from Bangkok” does not exclude Bangkok; unknown quoted term remains required; Japan filter + Thailand query creates conflict.

## Task2: Public evidence and eligibility before rank

**Interfaces:** `PublicSearchEvidenceBuilder.build(PublicPlanSnapshot snapshot, PublicationIdentity identity): PublicSearchEvidence`; `PlanSearchEligibility.evaluate(SearchIntent intent, PublicSearchEvidence evidence): EligibilityDecision` with group/rejection reason/evidence spans. No optional branch can return before all required gates are evaluated.

- [ ] Write failing cases for ChristmasCafe false event, December plus missing weekend/festival, negative/uncertain owner clauses, planned versus optional My List stops, hidden dates, mixed-country stops and wrong-country strong title.
- [ ] Run failing tests, implement source-scoped certainty and eligibility. Reuse `PublicPlanDates` and sanitizer versions; never change publication/copy payloads.
- [ ] Implement lexicographic rank tiers, distinct scheduled-stop focus and capped text repetition. Pin nature-led versus incidental-garden order; direct event versus public December-only reason.
- [ ] Run eligibility/rank tests and raw-query-to-results service tests; no returned reason may claim more than recorded public evidence. Commit.

## Task3: Compositional phrase generation and additive wire contract

**Interfaces:** `QuerySuggestionComposer.compose(SearchIntent intent, CatalogFacetSummary facets, List<RankedCandidate> candidates): List<QuerySuggestion>`; suggestion kind REWRITE/REFINE/BROADEN, changed facets, availability and explicit query action. `SearchAssist` version1 wraps fingerprint/interpretation/notices/suggestions/catalogueRevision. Legacy `querySuggestions` retains existing `{text,source}` values.

- [ ] Write failing tests for natural Christmas phrasing, zero-inventory suggestions, no fixed country suffix list, constrained festival/weekend, exclusion preservation and de-duplicated same-intent reorderings.
- [ ] Observe failures; implement max24 candidate generation, reparse and equivalence validation, max3 rewrites/max2 alternatives, meaningful diversity and support-aware ordering. Do not issue a separate catalogue scan per candidate.
- [ ] Add contract tests for old/new clients, absent optional metadata, invalid input length/codepoint boundaries, impossible counts, year limitation and ambiguous/conflicting query actions.
- [ ] Run composer/controller/service tests, commit. Unknown or gibberish may legitimately yield only literal Search; empty inventory must not suppress valid known-travel phrase ideas.

## Task4: Frontend integration and interaction preservation

**Interfaces:** typed optional SearchAssist, action handler for query/refinement/title, raw draft unchanged; query key includes all filters and assistance version. Backend capability must be confirmed before lifting100-character client protocol bound.

- [ ] Add failing UI/helper tests for grouped phrases before title groups, alternative changed-facet labels, destination actions preserving other intent, fingerprint mismatch and honest empty/unavailable states.
- [ ] Implement within existing controls and result sections. At most3Matching/2Relevant titles; destinations max2 only when useful; one literal footer; no default-page redesign. Apply the spec's empty-state truth table: compact Matching empty with actual Relevant cards; combined Matching/Relevant empty above useful Alternative searches; one larger final empty panel if all absent; omit empty Relevant when Matching exists. Alternative searches are explicit query actions, not broader-plan cards fetched silently.
- [ ] Add a result-presentation helper with exhaustive tests over Matching/Relevant/alternatives presence, plus loading/error/stale/next-page states. Use authoritative current-query totals; test positive totals with temporarily empty card arrays. Test confirmed-zero alternatives excluded, unknown-support Search idea labels, generic recovery buttons not counted, and query/filter-aware Edit search/Clear filters/Browse all actions. Assert exact spec copy and no duplicate empty panels or live announcements.
- [ ] Run real route browser tests for250ms debounce, slow/out-of-order responses, paste/clear/caret/spaces, IME, keyboard/Escape/Tab, URL history, filter conflicts, long query/zoom and390px mobile viewport. Test both API-present and offline legacy fallback.
- [ ] Run TypeScript, scoped lint, client full test suite and production build on exact committed config/files. Preserve generated local tsconfig. Commit.

## Task5: Catalogue consistency, performance and operational evaluation

**Interfaces:** immutable evidence keyed by eligible publication identity/revision/sanitizer/concept version; current eligibility rechecked per request; bounded cache5k entries/32MiB. CatalogueRevision binds page sequences. Parse/cache operations are internal; no new database writes/migrations initially.

- [ ] Write failing realPostgres tests for cache-warm update/unlist/revoke, public-note selection changes, partial/malformed snapshots, deterministic totals, ties and pagination revision mismatch. Database failures must not masquerade as empty catalogue.
- [ ] Observe failures; consolidate to one eligible stream and reused per-request evidence. Add cache eviction and safe uncached fallback, structured per-stage timings and fingerprinted pagination reset. In-flight responses use their DB snapshot; subsequent requests must reflect revoked visibility.
- [ ] Assert isolated database identity before writing fixtures; set SPRING_DATASOURCE for every context, disable bus/discovery/outbox delivery. Run full service, Postgres schema/startup and publication/copy regression suites. Report skipped tests explicitly.
- [ ] Run held-out relevance evaluation and1k/5k realPostgres fixtures at5 concurrent sessions, warm/cold; report p50/p95/p99 and memory. Gates: no critical leaks/constraint violations/intent-changing rewrites; >=95% suggestion validity/MatchingP@5; >=90%RelevantP@5 and recall@10; nDCG@10>=.90. Category failures block regardless of overall mean.
- [ ] API p95<=300ms,p99<=750ms at1k; cold<=1.5s; browser normally<=800ms after typing stops. If missed, stop launch and amend plan with measured cause/index projection rather than silently accepting truncation or degraded relevance. Commit validated code/tests and evaluation report.

## Task6: Review and release, separate from implementation approval

- [ ] Review all raw-query examples and returned evidence against the spec; no claim of universal NLP comprehension. Document bounded language, unsupported constraints, cache limits and actual benchmark environment.
- [ ] Enable new behavior behind a backend flag in test; compare old/new known basic searches and held-out queries without running two full searches for every real user's keystroke.
- [ ] Prepare backward-compatible backend-first/client-second release with exact child pins, existing API/schema checks and rollback flag. Update API/feature docs, handoff/log. Present concrete results to user; request VM release approval only at this ready stage if not separately authorized.
- [ ] After release approval deploy through childdev/main->server->root, watch run to success, verify actual VM and dev:vm APIs plus browser. No authenticated production fixture writes. Record LIVE status on docs branch->dev only.

## Design evaluation already completed (not implementation proof)

`output/smart-search-baseline-20261103.json`:16 public GET queries against live release65a4105. `docs/superpowers/experiments/2026-11-03-smart-search-policy-lab.mjs`:42 labelled policy/composition cases and192 evidence combinations passed after correcting a temporal early-return bug. Inputs to admission tests are manually annotated; this does not test a natural-language parser or any AI model. Full acceptance remains unchecked above.
