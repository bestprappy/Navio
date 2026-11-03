# Shared Plan Intent Relevance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Implementation is NOT authorized yet: user requested a detailed plan to revise and review together.

**Goal:** Make Shared Plan suggestions and results respect the whole travel intent, with separate Matching/Relevant titles and useful contextual phrase completions.

**Architecture:** Keep the existing public-snapshot search service and additive API. Separate query interpretation, evidence eligibility, ranking and phrase generation so popularity and geography cannot override missing intent. Frontend and backend consume one documented relevance contract; incomplete local summaries use conservative fallback.

**Tech Stack:** Existing Java 25/Spring Boot 4/Jackson/PostgreSQL, Next.js/TypeScript/Zod/TanStack Query; no new search service or paid API.

**Spec:** `docs/superpowers/specs/2026-11-03-shared-plan-search-relevance.md` (proposal, pending user review).

## Latest user amendment (takes precedence over year rules below)

User requires thorough search tests before completion and month/day-only published dates with no carried-over year. Plan/spec review is still the current workflow; no application implementation has started. Read the spec amendment first. Existing statements about verifying a typed year against original public trip dates are superseded: that year will no longer be public.

### Additional Task 0: Define and verify yearless publication compatibility

- [ ] Inventory all public snapshot endpoints, DTOs, preview/summarizer/read paths, copy-date flow, JSON schemas and existing published data. Determine the additive/versioned contract before implementation; do not convert LocalDate fields to month/day strings in place without consumer compatibility.
- [ ] Specify a real month/day value and ordered offsets, never a synthetic year masquerading as the owner's year. Readers omit weekday names. includeDates=false omits month/day as well; private trip full dates are unchanged.
- [ ] Update API/schema and UI plan for publication date options, yearless preview/readers, summaries and copy prompt. Keep original month/day only with reader-selected year or ask for new dates; preview Feb 29 and year rollover explicitly. Existing approval of retaining dates cannot silently mean retaining a hidden original year.
- [ ] Test legacy stored publications projected to yearless public reads without revoking links or leaking structured years. Confirm old/new client/API compatibility strategy before deployment. Freely authored prose is not automatically rewritten.
- [ ] Add red-then-green tests across publisher -> public reader/search -> copy -> private planner, with leap days, Dec/Jan, no dates, missing data, conflicting year query and malformed inputs. Verify source private dates are unmodified and transport-dependent data remains coherent.
- [ ] Adjust temporal search fixtures: month/day/event matching only; no claim that a yearless plan confirms a typed year. State the limitation explicitly. Year-specific movable holidays require a separately reviewed public-evidence rule rather than private-year lookup.

Task 0 expands the original search-only scope at the user's request. It crosses publication and copy contracts and must be designed/reviewed carefully before any DTO or serialization changes. Add the exact affected files after inventory; no migration is assumed. Complete thorough quality and regression checks in Task 5 before claiming completion.

## Global Constraints

- Shared Plans only; preserve Places search, default Explore landing, preview-only Interests and exact duration behavior.
- Preserve raw draft, repeated/trailing spaces, caret, IME, history and stale-request protection.
- Eligible publications only: listed, active, current sanitizer, readable public snapshot. Never join private trip data.
- Hidden dates stay hidden, including indirect search membership/count/reason leaks. Dates require publication includeDates and an actual public value.
- No fabricated titles, invented activity evidence, probability percentages, or automatic query replacement.
- No entity/migration/dependency changes planned. Any discovered need requires separate design review.
- No release/main push implied by plan approval. Follow release verification/authorization at the concrete release step.

## Review Focus

1. Country overlap must not rescue a missing event/activity; this applies to local fallback too.
2. Public December dates may support seasonal relevance, never prove Christmas activities or reveal private dates.
3. Synonyms must preserve specific intent, negation and explicit years; unknown words cannot silently disappear.
4. Autocomplete must preserve the typed sentence and modifier intent; no generic three-option filler.
5. Both groups and their independent pagination must remain stable, unique and accessible during rapid edits or rolling releases.

## Proposed product behavior for review

- Dropdown order: Destinations, Suggested searches, Matching plans, Relevant plans. Up to four destinations, four phrase suggestions, three matching titles and three relevant titles; no padding to fill quotas. Keep dropdown height bounded and keyboard-scroll selected items into view.
- Results: Matching plans first, Relevant plans second; both visible when present, compact genuine empty messages. No duplicate plan between groups/pages. Preserve selected country/duration constraints and existing sort options, but no sort can bypass relevance eligibility.
- Matching: all essential geography/time/activity/specific-concept constraints, plus >=90% supporting-concept coverage. Initially treat meaningful concepts as essential unless a documented rule classifies a word as nonessential. Thus short queries ordinarily require all meaningful concepts; generic words such as trip/plan do not dilute coverage.
- Relevant: same required geography and each essential intent supported directly or through a documented compatible alternative (e.g. public December dates for Christmas). Unknown/unfulfilled modifier means exclude rather than fall back to country alone. Use reasons to explain the alternative.
- Christmas: entire December is broad Relevant; December 18-31 ranks above other December dates, with overlap around December 25 strongest. This is a proposed relevance window, not a claim that every trip has Christmas activities. A typed year is mandatory. Explicit Christmas text can be Matching; when a year is typed, public date/year evidence must agree. Missing/hidden date and absent event text means no event-related eligibility.
- Phrase suggestions: independent of whether titles match. Complete destinations and unfinished travel words from a curated vocabulary; additionally suggest phrases/titles supported by the full public catalogue. Preserve all previous modifiers. Do not invent unsupported country/event/activity combinations. At a complete query with no defensible completion, offer the literal search action and honest title empty states.
- General completion examples: `Jap` -> Japan; `Thailand Christ` -> Thailand Christmas; `Hua Hin sea` -> a valid curated completion such as Hua Hin seafood, not an assertion that a seafood plan exists. Country-only input can show actual catalogue-supported refinements, whose variation reflects available plans rather than the same templates.
- Unsupported semantics (negation, competing destinations, ambiguous event/year): preserve text and avoid false confident matches. Do not interpret "not Christmas" as positive Christmas intent; add explicit exclusion handling for recognized concepts or return conservative lexical-only results until supported.

## File map

Backend paths relative to `server/trip-planning-service/src/main/java/com/navio/tripplanningservice/`:
- Modify `service/publication/PlanSearchQuery.java`: parsed intent and required concept coverage.
- Create `service/publication/PlanSearchTemporalIntent.java`: verified fixed-event/month/year interpretation and public-date evidence only.
- Create `service/publication/PlanSearchSuggestions.java`: bounded corpus phrase candidates and evidence metadata.
- Modify `service/publication/SharedPlanSearchService.java`: evidence extraction, independent eligible pools, additive suggestions/reasons and legacy compatibility.
- Preserve `repository/ExploreSearchRepository.java` public listing eligibility; measure scan cost before any index proposal.
- Tests under `src/test/java/com/navio/tripplanningservice/service/publication/` and existing controller/Postgres test paths discovered at execution.

Frontend paths relative to `client/app/feature/explore/_components/shared-plans/search/`:
- Modify `data.ts`: replace country suffix templates with documented vocabulary/aliases, not generated plan claims.
- Modify `search-suggestions.ts`: contextual prefix completion, conservative local title fallback.
- Modify `search-api.ts`: additive typed query-suggestion/evidence schema with legacy defaults.
- Modify `search-controls.tsx`: separate Matching and Relevant groups and empty states.
- Modify `shared-plan-search.tsx`: visible Relevant labels and accurate reasons.
- Preserve `search-draft.ts`; extend regression coverage without rewriting its ownership mechanism.
- Tests: `client/tests/explore/shared-plan-search*.test.mjs`; add relevance fixtures under the existing search test data directory.

## Task 1: Lock relevance examples and privacy contract

- [ ] Add judged fixture cases before implementation: Thailand-only; Christmas with explicit text; public December 25; public December 5; public July; hidden December; wrong country/year; missing date; city-food; sushi vs generic food; unknown modifiers; negation; ambiguous city; exact/prefix titles. Assertions specify Matching/Relevant/excluded and rank relationships.
- [ ] Run new service tests and record expected failures proving current country-only fallback and date ignorance. Do not rewrite prior tests simply to preserve wrong counts; explicitly update expectations against the reviewed contract.
- [ ] Define typed concept/evidence categories and missing-evidence behavior in `PlanSearchQuery`, preserving existing aliases, city disambiguation and exact filter constraints.
- [ ] Verify tests pass for geography/activities/unknown concepts, including negative popular-but-irrelevant examples. Commit scoped `fix(search)` on a fix branch from dev.

## Task 2: Add public temporal relevance and ranking

- [ ] Write failing temporal tests for the reviewed December windows, explicit year, long date spans, contradictory text/dates, hidden/malformed/missing dates and leap-year intervals. Check both results and counts/reasons for private-date leakage.
- [ ] Implement `PlanSearchTemporalIntent` with fixed reviewed rules and explicit evidence provenance. Movable holidays have no inferred dates without verified locale/year entries. Do not assume winter means Christmas, or Northern Hemisphere seasons apply globally.
- [ ] Extend `Evidence` to separate title, public descriptive/owner text, place/type facts and public temporal facts. Index only deliberately included public textual fields; generic checklists or speculative owner questions must not imply an activity took place. Test event text from public introductions/notes independently from hidden notes.
- [ ] Replace permissive related OR gates with mandatory concept compatibility. Rank exact title/phrase, coverage, evidence strength and temporal closeness before popularity; deterministic ID tie-break. Keep Matching/Relevant pools disjoint and legacy response pagination compatible.
- [ ] Run service/controller and real PostgreSQL integration tests, including more than one page and remote titles outside initial feeds. Commit scoped backend fix.

## Task 3: Replace fixed phrase templates with contextual suggestions

- [ ] Add failing frontend/backend tests for `Jap`, `Thailand Christ`, city+food prefixes, trailing spaces, completed rare phrases, unknown terms, no catalogue matches, API unavailable, duplicates and modifiers preserved during completion.
- [ ] Implement curated destination/event/activity word completion as search-language help, explicitly separate from inventory-backed title suggestions. Remove the country+three-suffix branch entirely.
- [ ] Implement bounded catalogue phrase candidates via `PlanSearchSuggestions`; candidates must preserve recognized constraints, have public support when claiming inventory, and return provenance/count only when verified. Avoid repeated variants and unrelated popular phrases.
- [ ] Add an optional API field such as `querySuggestions: [{text,source,matchingCount?}]`; source is `catalogue` or `vocabulary`. Retain legacy fields internally during rolling upgrades; Zod defaults missing field to empty. No analytics/popularity claims without measured data.
- [ ] Frontend fallback only offers defensible local completions/strong titles. It must not approximate event dates from incomplete summaries or briefly flash arbitrary Related plans before API resolution.
- [ ] Verify suggestion tests, API schema/proxy tests and scope lint; commit focused backend/frontend fixes in their respective repos.

## Task 4: Present both title groups and result groups clearly

- [ ] Write grouping tests: both title groups nonempty; only one; neither; API failure vs genuine empty; no duplicated title; title activation retains normal navigation.
- [ ] Update dropdown to render both groups under clear headings with concise evidence in Relevant rows. Keep literal Search action separate from completions. Show loading instead of prematurely claiming no matches.
- [ ] Rename visible Related -> Relevant in results without renaming legacy wire fields unnecessarily. Show meaningful reasons such as public December dates; do not expose an owner's excluded data through reasons or counts.
- [ ] Browser-check keyboard, focus, Escape, scrolling, mobile, live requests, cancelled/stale responses, IME, raw spacing/caret, filter changes and Back/Forward navigation. Preserve default page when criteria empty.
- [ ] Run scoped checks and commit frontend fix.

## Task 5: Evaluate quality, verify integration and prepare review

- [ ] Run the representative judged suite: report precision@5 for eligible title suggestions/results, exact-title rank and event negative false positives. Target zero irrelevant country-only event results and zero privacy/filter violations. Publish measured values rather than an unsupported "90% accuracy" claim.
- [ ] Compare representative live public catalogue inputs read-only. Do not modify sample dates/text to make the algorithm look better; missing evidence should yield fewer results.
- [ ] Run client full suite/typecheck/build, backend relevant/full tests and disposable real PostgreSQL checks. Measure repeated-query latency and bounded allocations under a larger fixture catalogue. No unbounded or stale-content cache introduced to mask poor performance.
- [ ] Get one independent code review under requesting-code-review skill; fix material findings and rerun relevant checks.
- [ ] Update feature docs and end-session handoff/log; commit child-first with explicit files, preserving teammate changes and generated local files. Present UI/evaluation evidence for user review. VM release remains separate and must follow `docs/agents/release.md`.

## Open decisions for user review

1. Confirm December-wide Relevant Christmas results, with December 18-31 prioritized, or narrow the entire relevant window.
2. Confirm direct essential-intent evidence is required even when this means fewer results; no arbitrary country-wide rescue section.
3. Confirm general phrase completions remain available without a matching plan, clearly distinct from actual matching/relevant plan titles.

No implementation task above has started. Approval of this document's behavior comes before execution.
