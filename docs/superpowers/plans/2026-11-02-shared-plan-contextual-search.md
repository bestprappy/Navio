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

- [x] Task1: Add a failing raw-draft/debounce regression test and a browser test which types a word+space around URL update boundaries, continues typing, edits in middle, pastes and composes IME. Repair draft ownership in client/app/feature/explore/_components/shared-plans/search/shared-plan-search.tsx; extract a small pure draft/navigation state helper if needed. Do not solve by lengthening debounce or dropping URL restoration. Verify Back/Forward and clear/suggestion actions. Review this as an isolated urgent fix.
- [x] Task2: Add failing parser/phrase tests for all supplied examples, unknown words, aliases, typo suggestions, empty plan pool, geographic conflicts and stale requests. Extend search-suggestions.ts with explicit query context and bounded vocabulary under data.ts where appropriate; avoid one hardcoded branch per screenshot. Keep both original query and proposed correction.
- [x] Task3: Add backend tests for meaningful token/intent coverage, title/location/theme weighting, direct versus related thresholds, hard country/duration intersection, no private/revoked/stale publications, evidence reasons, deterministic pagination and no duplicates. Introduce focused QueryInterpreter/PlanRelevance units beside SharedPlanSearchService as needed; retain existing eligible-publication repository. Derive only from sanitized published data; no private notes/checklists or newly fetched Google reviews.
- [x] Task4: Extend DTO, client Zod schema and proxy tests additively with strong/related groups, counts, pagination and optional reason/correction fields. Preserve response compatibility while coordinating VM/client release; do not break old clients during rollout. Keep abort, no-store, request limits and bounded memory. Suggestions should not depend on strict result filtering.
- [x] Task5: Update search-controls.tsx for persistent phrase and real-title groups plus compact no-title-match status. Update shared-plan-search.tsx for Matching/Related sections and scoped empty/error/loading states. Reuse existing cards/style; no default landing redesign. Cover keyboard focus, inline highlighting, mobile width, scroll and reduced motion.
- [x] Task6: Verify supplied examples in browser with mocked controlled datasets and a real backend/real PostgreSQL check where appropriate, plus type/lint/full appropriate suites. Verify old strict matches, zero strong+nonzero related, zero both, no invented suggestions/counts, incomplete token and out-of-order response behavior. Review algorithm outputs on actual published catalogue before release. No deployment implied by approval of this planning document; follow current release authorization when executing.

## Proposed execution order

Fix and verify typing independently first. Then query interpretation/autocomplete; then shared ranking/API; then grouped result UI and integrated checks. Avoid mixing the urgent input bug with a large UI/algorithm patch.


## Execution ledger ? 2026-11-02

Approved by user "proceed", including the amendment that real related titles should appear when no strong title matches. Implemented inline on feat/contextual-plan-search-20261102 in client and Trip service. Client commit378bac2; Trip9a3b1d8. No new dependencies, migrations, reserved teammate edits or deployment.

Ruling: Keep raw draft authoritative and acknowledge self-originated URL writes with a bounded pending-query queue; external popstate explicitly restores URL text. Request normalization collapses whitespace separately. This avoids both space loss and overwriting a newer edit without disabling URL restoration.

Ruling: Add matching/related arrays, independent totals/exhaustion flags, relatedPlans, reasons and optional correction to the existing response. Retain legacy content/recommendations/counts/last semantics. One page index advances both new pools; a single Load more fetch appends both, so no second catalogue scan per section click is needed. New client combines both exhaustion flags; legacy last still follows legacy matching content.

Ruling: Interpret controlled broad travel intents but retain specific terms such as beach/sushi for strong matches; broad-theme alternatives belong in Related. Geography is grounded in country registry, public catalogue city names and a small explicit alias set (Hua Hin/California). No external geocoding, generative model or arbitrary claim of understanding every unknown location. Ambiguous cities use typed/selected country; otherwise retain known alternatives, not arbitrary row order. Search streams eligible public snapshots twice and retains bounded candidate windows; cost remains linear in catalogue size, with indexing deferred until measurements justify it.

Verification: frontend643/643, production build and scopedlint passed. Backend347 total /0failures /0errors /3environment-dependent skips with real disposable PostgreSQL enabled; includes schema validation, two-pass JSONB integration and JDBC copy counts. Browser passed trailing/repeated spaces, raw newer edits, caret editing, delayed response races, IME, history restoration, related title fallback, dual empty states, dedupe, keyboard/mobile/blank landing. Actual local Explore route also passed trailing-space preservation and navigation during pending debounce. Temporary review route removed; data only under tests; own Next3108/config18888/database56432 cleaned up. Independent review issues reproduced/fixed: same-name city geography, unfinished multiword span duplication, legacy pagination; final review found no remaining P1/P2.

Release status: A new VM release question is pending. Backend changes are not on VM; current local dev:vm frontend tolerates the old response and clearly indicates related-result capability is unavailable there. Do not claim deployed completion. No push or production action is authorized by implementation alone under the approved plan.
