# Shared Plan Search Implementation Plan

> For agentic workers: use superpowers:executing-plans inline, task by task. Do not delegate this run.

Goal: catalogue-wide live Plans search and destination/title suggestions, Places-style recommendation/results presentation and country/exact-duration controls, without redesigning default feeds.
Architecture: new anonymous read-only search controller/service/repository over eligible sanitized published snapshots, no schema changes or writes. Search eligibility identical to Explore. New Plans-only client workspace using TanStack Query; reuse Places country selector and existing shared cards. Initial schema-free streamed catalogue matching; bounded response/top-result memory, no persistence or stale content cache. Search indexing deferred until measurements justify it.
Tech Stack: Java25/Spring Boot4/JPA; Next16/React/TypeScript/Jotai/TanStack Query; existing UI tokens.
Spec: docs/superpowers/specs/2026-11-02-shared-plan-search-draft.md plus user approval/refinements in latest conversation.

Constraints: approved number+Days/Months/Years exact duration; months30days/years365days explicitly explained. Empty query+no country/duration or Enter on empty controls returns unchanged default feeds. Filters preview only. No global navbar, author/pin/publication writes, notifications, migrations, shared planner cards, guide changes or deployment. Existing generated tsconfig left uncommitted.

Review focus: reversed request ordering/IME; hiding/unlisting must remove entries; catalogue matches beyond first page; unit switching/empty/invalid duration; recommendations and results never duplicate; URL/back restore and keyboard/mobile behavior.

- [x] Task1: Backend matching and controller tests first (red). Add separate read-only search repository/service/controller and tests. Match normalized tokens/country aliases/published places; strict country and day constraints; stable ranking/paging; bound recommendations/suggestions and response sizes. Never read private trip state or increment view/copy counters. Test eligible status/version, absent identity, malformed query400, no-store, country-not-title, multiscope filters, stale snapshots, recommendations dedupe.
- [x] Task2: Client pure search-state/API model tests first (red). Define unit conversion, URL parsing/serialization and mode detection; Zod response; independent search key and abort handling. New server proxy validates query and anonymous gateway response with timeout.
- [x] Task3: Country selector small shared extraction preserving Places behavior. Build labelled toolbar, accessible autocomplete and exact duration control, preview-only Filters panel. Tests and scoped lint/types; no default feed redesign.
- [x] Task4: Places-style result sections with real high-confidence recommendations, remaining paginated results and no duplicates. Debounce, IME, cancellation, URL/back preservation, error/retry/empty. Existing default feed untouched when no active criteria. Guides/Places independent.
- [ ] Task5: Backend tests, all frontend tests/type/lint, production build where available; headless keyboard/mobile/browser checks using isolated fixture or test server, never runtime demo data in product. Document backend dev:vm availability limitation if not deployed; do not deploy without user request. Append handoff/log, leave clear feature branch state.

## Recovery / verification status (2026-11-02)

Laptop interruption did not lose source changes. Temporary configuration server was unavailable during the first broad backend run; restarted only an isolated test instance on18888. Full backend rerun passed336 tests (17 skipped); separate real PostgreSQL schema/search eligibility check passed7/7 using a disposable database on56432. Frontend regression suite passed603/603; TypeScript and scoped ESLint passed. Headless Chromium verified autocomplete, keyboard destination selection, exact unit conversion, country metadata search, pagination/deduplication, filter preview, narrow mobile width and blank Enter restoring the landing page. Browser fixture route removed after testing; test data remains under tests only.

Production build and three proxy tests also passed. Task5 remains partially open only for real deployed gateway search verification after a separately authorized release. New backend endpoint is NOT released to VM; dev:vm cannot use new search until coordinated release. No migrations, live database maintenance, reserved profile/notification code changes, pushes or deployments. Catalogue matching streams all eligible public snapshots per request: suitable initial implementation but O(catalogue size), measure before large-scale indexing work.
