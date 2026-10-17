# Places Search Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. User approved the spec and explicitly requested review after implementation; do not repeat the approval gate.

**Goal:** Implement country-scoped discovery, focused search, grouped filters and exclusive month/season selection with a composed responsive UI.
**Architecture:** Extend the existing uncommitted Places feature. Add bounded public Explore reads in Mobility, retaining existing city/reader/append APIs. URL state and pure client helpers drive reusable controls and a shared card grid.
**Tech Stack:** Next.js 16.3.4, TypeScript, TanStack Query, Base UI/Shadcn, Spring Boot 4 / Java 25, Google Places New.
**Spec:** ../specs/2026-10-15-places-search-design.md

## Global constraints
- Preserve unrelated dirty work; no source commits/push/deployment or database changes.
- Country lock must validate structured country metadata; no fallback to address substrings.
- No fake climate, trend, availability or imagery claims; unsupported seasons are visible.
- Retain request budgets, cancellation, no-store, provider attribution and owned append behavior.
- User explicitly selected post-implementation review. Execute in the existing feature workspace, without moving unfinished changes to another checkout.

## Review focus
- Country and explicit conflicting query must never leak another country.
- Sparse filtered pages must remain pageable, not falsely empty.
- Recommendation resizing/paging must neither lose nor duplicate places.
- Unsupported climate/season combinations must not silently become another month.
- Filter Cancel, keyboard operation and long labels must preserve context and alignment.

## Tasks
1. **State and partition contracts** (`client/.../places/search-state.ts`, `tests/explore/places-search.test.mjs`): test URL/legacy parsing, exclusive time, mode matrix, countries, recommendation quality/row/dedup partition; observe red, implement, observe green.
2. **Provider and Explore service** (`server/mobility-and-ev-service/...`): test structured country lock, type OR/interest OR intersection, bounded paginated streams, expiry/query-bound cursors, season coverage and suggestions; observe red. Add typed DTOs, allowlists, limited cursor sessions storing only tokens/IDs, Google text search/predictions and source-backed profiles. Run targeted Mobility tests.
3. **Public read plumbing**: add exact Explore and suggestion GET security rules/Next proxies and tests; prove mutation/deeper routes remain protected. Existing reader and append stay intact.
4. **Controls and page** (`client/.../places/`): integrate tested state/contracts; accessible searchable Country, submitted query with debounced suggestions, grouped filter draft/Apply/Cancel, Month & season; anchored section headers, consistent cards, responsive five-row recommendation caps. Run lint, TypeScript and focused tests.
5. **Verification and review**: production build, targeted gateway/Mobility tests, responsive browser review, real provider/read/add integration where runtime is available. Fresh reviewer checks whole diff, fix material findings and rerun checks. Record evidence, remaining acceptance limits and required agent notes without source commits.

## Execution record

- User-review correction: supersedes the prior Any-country destination-prompt ruling and narrow no-fallback seasonal coverage. User explicitly requires inspiring default collections and seasonal adaptation across every collection; chose reviewed evidence first, then believable algorithmic/category fill.
- Added GlobalDiscoveryDestinations and SeasonalInspiration. Global live provider pools span14 named city/country starting points with per-collection ordering. Named themes alter each section's search; month-based fallback uses candidate hemisphere outside tropics without inventing local rain seasons. Selected-country discovery combines ordinary and themed pools, ranking reviewed guidance first. Explicit query/hard filters remain intact. UI distinguishes Navio inspiration from regional/calendar references.
- Follow-up review fixes: retain pagination on empty source-free seasonal pages; diagonal schedule varies global countries/types and includes city specificity. Regression tests observed red then green.18 frontend and39 Mobility tests pass; scoped lint/full TypeScript/Places-enabled build pass. Browser inventory remains empty, so visual acceptance is open.
- Baseline: root dev; client/server/Mobility feat/places-discovery; Trip feat/places-list-append. Existing feature source, profile fix notes, reports and logs preserved.
- Pre-flight: provider DTO feeds Explore DTO; Explore DTO feeds client Zod; pure state feeds controls/orchestrator; reader still imports PhotoCredit. Keep PhotoCredit export compatible. No schema migrations.
- Ruling: user asked for implementation before another review, overriding skill's repeat-plan approval; proceed inline. Existing dirty feature workspace retained to preserve the unfinished feature rather than split it across checkouts.
- Task 1 complete: URL/mode/exclusive-time/country/legacy/row-partition contracts observed red then green. Client focused set now 16 passing tests, including toolbar SSR labels, sparse expansion and expired-cursor HTTP status.
- Tasks 2–3 complete: scoped Explore service, request DTOs, source-backed time preferences, bounded two-call provider streams, query-bound ten-minute opaque cursor sessions, structured-country verification, semantic suggestions and exact public GET proxies/security. Mobility 33 and Gateway 8 focused tests pass. Existing reader/append APIs preserved.
- Task 4 complete: composed responsive toolbar/cards/collections, mobile filter sheet, grouped single/multi selections, contextual chips, legacy context migration, planner country/month defaults, recommendation partition, retry/reset and source disclosures. Scoped ESLint, full TypeScript and Places-enabled production build pass.
- Task 5 partially complete: fresh independent review identified sparse paging, alphabetical stream bias and time-only legacy context loss. All three were fixed with regression coverage. Self-review/live tests additionally fixed Google full-world viewport rejection, fallback token/query consistency, geographic predictions and unsupported-vs-empty seasonal messaging.
- Live evidence: Next/Gateway Google search returned 24 Osaka sushi places, all JP; nine initial recommendation candidates. Suggestions returned HTTP200/providerAvailable=true. JP autumn scenic discovery returned mode=discovery and one source. One subsequent page returned 24 places, zero overlap and no new recommendation IDs. The public JSON was validated against the client schema and then deleted; only verification metadata remains.
- Ruling: broad Any-country/no-search discovery shows the approved destination prompt, rather than fabricate a global pool or call IP-biased recommendations global. Any country remains available for submitted searches and place-type results. Cost: a fresh visit needs a country choice or a search before collections appear.
- Ruling: source commits remain deferred to preserve pre-existing unfinished feature ownership. Only required design/implementation/session documentation is committed on a docs branch and integrated to local root dev; no push/main/deploy.
- Acceptance remaining: browser control inventory is empty and both iab/chrome creation return unavailable. Visual review at 360/390/768/1024/1440, 200% zoom, actual keyboard/filter interactions and live add/save/reopen cannot be claimed. Backend services Mobility/Gateway were selectively reloaded; infrastructure, accounts and data were not reset.
