# Shared Plan search

## Interaction

The Plans search bar is reactive: after two characters, its autocomplete combines general destination completions, travel search phrases, and actual published plan cards. Countries and aliases use the existing country registry, independent of backend availability. Related phrases are query suggestions, not invented plans or claims of available results. Already-fetched public Explore cards provide immediate title matches; the catalogue endpoint augments these with matching public plans after a 250 ms debounce. Old-query responses are cancelled/ignored. IME composition does not submit unfinished input.

Selecting a country completion fills the search text; only the separate Country selector locks the country. Selecting a travel phrase searches that phrase. Selecting a real plan title opens that publication. Keyboard arrows/Enter/Escape and pointer selection are supported. Unknown plan counts are never displayed as zero; backend counts reflect the current constraints. Backend failures must not hide general completions or be labelled as an empty catalogue.

The numeric duration control matches exact itinerary day count. Days, Months and Years are planning units with explicit 30/365 conversion text. No query/country/duration preserves the existing Trending/Recent landing sections. The Interests/Filters panel is explicitly a nonfunctional preview. Active criteria show bounded high-confidence recommendations and paginated remaining matches without duplicates.

## Read-only API

`GET /api/shared-plans/search` proxies only approved query parameters to anonymous `GET /v1/shared-plans/search`: term (max 100 characters), country (ISO alpha-2), days (1..36500), page (0..500), size (1..48), sort (relevance/recent/trending). Default size 12. It does not forward user credentials, cookies, tokens, or arbitrary upstream paths. Responses are no-store and schema-validated, with abort/timeout handling. Missing upstream endpoint returns 503 with a clear unavailable message.

The service searches eligible listed ACTIVE publications at the current sanitizer version, using their sanitized public snapshots. It never loads private planner state, writes a trip, or increments views/copies. Matching includes normalized title, primary city/country and public place addresses/names; country metadata works even when absent from the title. Country, duration and query tokens intersect. Recommendations and paginated results share stable ranking and exclude duplicates. General autocomplete is topic completion, not a Google service or personalized browsing-history model.

## Intent relevance revision (released and live-verified 2026-11-03)

Released as root `65a4105` (client `85f2e1f`, server `714bdc9`, Trip `e33812d`), workflow `41617858398` successful. Real VM API, deployed Chrome and local dev:vm proxy checks passed: catalogue phrases, strict relevance, year notice, hard country/duration filters, disjoint pagination, typing spaces, keyboard and mobile layout. No authenticated production writes were tested.

This supersedes the older country-only related fallback and fixed three country suffixes described in historical entries below. Matching requires every essential geographic/activity/specific-word condition. Relevant alternatives must also satisfy those conditions: date-only Christmas/New Year compatibility or bounded close spelling can qualify, but country overlap alone cannot. A sushi query cannot be rescued by a generic food plan, and a named city does not relax to its entire country.

Christmas text can establish a Matching plan; public December dates alone establish Relevant, ranked by closeness to December 25. New Year uses explicit text or a bounded year-turn date window. Public English month names are supported. Unknown years and movable local holidays are not inferred from private data. Date-only matching never proves that holiday activities exist. These rules are deterministic, conservative evidence rules, not general natural-language understanding or a displayed probability percentage.

The dropdown displays Matching plans and Relevant plans independently. Literal search is a separate action. General destination/travel-word completion remains available without inventory, while optional `querySuggestions` come from actual eligible public catalogue content and preserve the typed constraints. The same itinerary/road/weekend suffixes are no longer appended to every country. The optional `notice` explains why a year-specific query cannot be verified from yearless dates. Existing response fields remain compatible, including legacy pagination semantics.

Public introductions and attached notes can supply affirmative activity/event evidence; conservative negative/speculative/question filtering prevents an optional question from becoming a confident activity claim. No private notes or dates are loaded. This heuristic is intentionally conservative and is not a language model. Incomplete local feed summaries do not guess missing temporal evidence while waiting for the API.

See `yearless-publication-dates.md` for the publication/copy contract. Implementation and testing evidence: `../reports/2026-11-03-shared-plan-search-implementation.md`.

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
