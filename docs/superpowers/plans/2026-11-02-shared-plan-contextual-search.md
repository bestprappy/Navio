# Shared Plan Contextual Search Revision — Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline, task by task. Do not delegate this run.

**Goal:** Preserve uninterrupted typing and provide useful multiword autocomplete plus clearly separated matching and related published plans.
**Architecture:** Keep the raw input draft separate from normalized search/URL state. Add a bounded deterministic query parser/ranker over eligible sanitized public publications, shared by results and actual-title suggestions; keep general phrase suggestions independent of result count. Extend the read-only response additively and preserve default Explore feeds, filters, visibility and privacy rules.
**Tech Stack:** Existing Next.js/React/TypeScript/TanStack Query and Java/Spring/JPA. No new dependencies, schema changes, LLM calls or external personalization service proposed.
**Spec:** User feedback and examples of2026-11-02, plus docs/features/shared-plan-search.md. This is a proposal awaiting review, not execution authorization for the broader redesign.

## Confirmed code findings

- shared-plan-search.tsx resets the draft from state.query whenever its source changes. search-state.ts trims query during URL serialization. The combination can overwrite a newer raw draft, stripping trailing spaces or a subsequent edit during debounce. Reproduce timing deterministically before patching.
- search-suggestions.ts matches the complete normalized input as a prefix; country-only completions stop working for country+city/theme phrases. Only a small fixed topic set exists.
- SharedPlanSearchService currently requires every query token to occur somewhere in the public searchable text. It does not separate domain filler, typo/alias resolution, meaningful partial relevance or related candidates. Suggestions are collected after that strict rejection, so a zero-match query also suppresses useful catalogue completions.

## Proposed behavior

### 1. Urgent typing repair, isolated first

Raw draft is authoritative during editing. Normalize only a separate value for matching, request keys and URLs; never replace draft from a self-originated URL write or a completed request. External navigation (Back/Forward, incoming URL), explicit clear and suggestion selection may deliberately replace it. Preserve leading/trailing/repeated spaces, caret and mid-string edits, paste and IME; blank detection still uses a normalized copy. Avoid extra requests caused only by whitespace.

### 2. Autocomplete: independent sources, multiword context

Retain current visual style and grouped dropdown: Destinations / Suggested searches / Shared plans. Interpret recognized country/region/city spans and travel intent rather than comparing the entire sentence against one label. Complete the unfinished final token while retaining earlier words. General destination/phrase suggestions remain available when there are zero actual plan matches. Titles must always be existing eligible publications; show a small "No matching shared plans found" row inside that group when none qualify, while keeping phrase suggestions visible. Distinguish network failure from zero matches.

Use a controlled travel vocabulary and verified catalogue metadata, bounded spelling correction and aliases. Initial regressions include Hua Hin/Huahin, scenery/scenary/scenic views, food/dining/restaurants and trip/plan/itinerary filler. Do not silently alter the typed text or invent locations, attributes, plan names/counts. Correction candidates may display "Did you mean…". Unknown input still offers a clearly labelled literal search action rather than fake travel knowledge. General suggestions are possible searches, not evidence of available matching plans.

Examples: "Thailand Hua…" -> "Thailand Hua Hin"; "Huahin scenary and food trip" -> suggestions such as "Hua Hin scenic and food trip"; "Thailand Food Trip" -> relevant Thai food-travel phrases; "California Food Focus Trip" -> California food-travel refinements. Only show particular city/theme combinations when supported by known destination context; no random unrelated global suggestions.

### 3. Ranking and results

For text-only search show two sections, replacing the current recommendation-versus-leftover split:

1. Matching plans: strong overall intent coverage, ranked strongest first. Exact/near title matches, correct destination and evidenced theme coverage outrank broad country-only matches. All meaningful terms need contextual coverage; conjunctions and generic trip/plan wording do not independently exclude candidates. Avoid raw substring false positives.
2. Related plans: meaningful partial matches, clearly labelled as broader. Prefer same city, then wider region/country with matching themes; apply a minimum relevance threshold. Add a short evidence-based reason, e.g. "Also in Thailand" or "Includes food stops". A destination-only match for a food query belongs here unless food intent is supported.

Always retain the Matching plans heading; if no strong candidates, show compact "No matching plans found" and render useful Related plans below. If neither has genuine relevant candidates, show two honest compact empty states and query-refinement actions, not unrelated plans presented as related. Keep counts separate, no duplication between groups, deterministic pagination and one coherent relevance model for suggestions/results. Do not arbitrarily cap all strong matches to a handful; paginate each needed pool with explicit cursors/counts.

Selected country and exact duration remain hard constraints for both groups and actual-title suggestions. Typed geography is an intent anchor even without a filter: do not ignore California and suggest food plans from another country merely because "food" matches. May broaden within the recognized country/region for Related, explicitly labelled. No active criteria keeps existing Trending/Recent feeds. Interests remains visual-only. Proposed same two-section presentation when filters coexist, with no hidden filter relaxation; text-free filter browsing keeps existing behavior until separately approved.

## Files / bounded tasks

- [ ] Task1: Add a failing raw-draft/debounce regression test and a browser test which types a word+space around URL update boundaries, continues typing, edits in middle, pastes and composes IME. Repair draft ownership in client/app/feature/explore/_components/shared-plans/search/shared-plan-search.tsx; extract a small pure draft/navigation state helper if needed. Do not solve by lengthening debounce or dropping URL restoration. Verify Back/Forward and clear/suggestion actions. Review this as an isolated urgent fix.
- [ ] Task2: Add failing parser/phrase tests for all supplied examples, unknown words, aliases, typo suggestions, empty plan pool, geographic conflicts and stale requests. Extend search-suggestions.ts with explicit query context and bounded vocabulary under data.ts where appropriate; avoid one hardcoded branch per screenshot. Keep both original query and proposed correction.
- [ ] Task3: Add backend tests for meaningful token/intent coverage, title/location/theme weighting, direct versus related thresholds, hard country/duration intersection, no private/revoked/stale publications, evidence reasons, deterministic pagination and no duplicates. Introduce focused QueryInterpreter/PlanRelevance units beside SharedPlanSearchService as needed; retain existing eligible-publication repository. Derive only from sanitized published data; no private notes/checklists or newly fetched Google reviews.
- [ ] Task4: Extend DTO, client Zod schema and proxy tests additively with strong/related groups, counts, pagination and optional reason/correction fields. Preserve response compatibility while coordinating VM/client release; do not break old clients during rollout. Keep abort, no-store, request limits and bounded memory. Suggestions should not depend on strict result filtering.
- [ ] Task5: Update search-controls.tsx for persistent phrase and real-title groups plus compact no-title-match status. Update shared-plan-search.tsx for Matching/Related sections and scoped empty/error/loading states. Reuse existing cards/style; no default landing redesign. Cover keyboard focus, inline highlighting, mobile width, scroll and reduced motion.
- [ ] Task6: Verify supplied examples in browser with mocked controlled datasets and a real backend/real PostgreSQL check where appropriate, plus type/lint/full appropriate suites. Verify old strict matches, zero strong+nonzero related, zero both, no invented suggestions/counts, incomplete token and out-of-order response behavior. Review algorithm outputs on actual published catalogue before release. No deployment implied by approval of this planning document; follow current release authorization when executing.

## Proposed execution order

Fix and verify typing independently first. Then query interpretation/autocomplete; then shared ranking/API; then grouped result UI and integrated checks. Avoid mixing the urgent input bug with a large UI/algorithm patch.
