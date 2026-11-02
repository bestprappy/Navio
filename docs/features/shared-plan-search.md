# Shared Plan search

## Interaction

The Plans search bar is reactive: after two characters, its autocomplete combines general destination completions, travel search phrases, and actual published plan cards. Countries and aliases use the existing country registry, independent of backend availability. Related phrases are query suggestions, not invented plans or claims of available results. Already-fetched public Explore cards provide immediate title matches; the catalogue endpoint augments these with matching public plans after a 250 ms debounce. Old-query responses are cancelled/ignored. IME composition does not submit unfinished input.

Selecting a country completion fills the search text; only the separate Country selector locks the country. Selecting a travel phrase searches that phrase. Selecting a real plan title opens that publication. Keyboard arrows/Enter/Escape and pointer selection are supported. Unknown plan counts are never displayed as zero; backend counts reflect the current constraints. Backend failures must not hide general completions or be labelled as an empty catalogue.

The numeric duration control matches exact itinerary day count. Days, Months and Years are planning units with explicit 30/365 conversion text. No query/country/duration preserves the existing Trending/Recent landing sections. The Interests/Filters panel is explicitly a nonfunctional preview. Active criteria show bounded high-confidence recommendations and paginated remaining matches without duplicates.

## Read-only API

`GET /api/shared-plans/search` proxies only approved query parameters to anonymous `GET /v1/shared-plans/search`: term (max 100 characters), country (ISO alpha-2), days (1..36500), page (0..500), size (1..48), sort (relevance/recent/trending). Default size 12. It does not forward user credentials, cookies, tokens, or arbitrary upstream paths. Responses are no-store and schema-validated, with abort/timeout handling. Missing upstream endpoint returns 503 with a clear unavailable message.

The service searches eligible listed ACTIVE publications at the current sanitizer version, using their sanitized public snapshots. It never loads private planner state, writes a trip, or increments views/copies. Matching includes normalized title, primary city/country and public place addresses/names; country metadata works even when absent from the title. Country, duration and query tokens intersect. Recommendations and paginated results share stable ranking and exclude duplicates. General autocomplete is topic completion, not a Google service or personalized browsing-history model.

## Scale and limits

This initial schema-free implementation streams the eligible public catalogue per request, with bounded top-candidate memory and response sizes. Its scan cost is O(catalogue size); measure latency and traffic before introducing a persisted index. Country extraction from public addresses is conservative and not a substitute for structured country metadata for every stop. Token matching is deterministic lexical matching, not an LLM or unrestricted semantic engine. Live catalogue results require the backend release; local generic completions alone do not substitute for complete search.

## Verification (2026-11-02)

Combined frontend suite: 621 passing; Trip suite: 337 total with zero failures and 18 environment-dependent skips. Seven real PostgreSQL schema/search eligibility checks passed during implementation. Production build and scopedlint passed. Browser checks deliberately used an unavailable live API and verified immediate country/travel/title suggestions, keyboard/click selection, country-filter independence, stale suggestion removal and mobile width with no runtime errors. Temporary review route removed. Release run and live smoke results are recorded in docs/agents/handoff.md.


## Contextual revision (released 2026-11-02)

Raw input and normalized request text are independent. Typed spaces and newer edits survive URL acknowledgement; Back/Forward deliberately restores external state. Multiword country/city/travel-term completions, controlled aliases and offered corrections keep phrase suggestions useful independently of catalogue count. Real strong title matches appear first; if none qualify, real related plan titles are labelled as Related. Zero real matches are a compact status within that group, not a replacement for phrase suggestions.

New optional response fields: `matching`, `related`, `matchingTotal`, `relatedTotal`, `matchingLast`, `relatedLast`, `relatedPlans`, `reasons` (token to plain-text explanation) and nullable `correction`. Both pools use the page index independently. New clients load more while either exhaustion flag is false. Legacy `content`/`recommendations`/`totalElements`/`matchedCount`/`last` keep their original meaning. UI always retains Matching plans for text searches, then Related plans; counts and cards are disjoint. No arbitrary unrelated fallback fills an empty pool.

Country and exact duration remain hard constraints; typed known geography constrains theme relaxation. Place type/name, public title and transport/charger facts support broad travel themes; specific subtypes remain required for strong matches. Public descriptions can match ordinary words but are not sufficient alone to claim a themed stop. Country hints and selected filters disambiguate same-name cities. Search uses existing sanitized publications only, never private trips or editorial research. Vocabulary-based relevance is deterministic, not Google personalization or unrestricted semantic understanding.

Verification for this revision:643 frontend tests, full backend347 total with zero failures and three skips, real PostgreSQL integration/schema checks, browser input/IME/history/race/related-title/group checks and production build. See the contextual-search implementation plan and agents handoff for release status.

Released as rootf6f2f0b, workflow41461424001 success. Real-catalogue API and deployed-browser checks passed, including trailing spaces, multiword completion, actual related-title fallback, two result groups, hard constraints, no-match states and pagination. See agents handoff for exact counts and evidence.
