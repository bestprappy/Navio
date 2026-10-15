# Places discovery and search design

Status: approved by the user on 2026-10-15; implemented locally for post-implementation review. Visual acceptance remains open because neither in-app nor Chrome browser control is available in this session.

## Purpose and boundaries

Make Explore > Places useful for relaxed discovery and deliberate place searches, with a composed, premium Navio presentation. Preserve Plans and Guides, the existing place reader, provider attribution, and the owned My List append workflow. Do not alter authentication, databases, EV functions, saved itineraries, or deployment configuration.

The existing Places work is uncommitted on client/server/mobility feature branches. It already provides city-based discovery, regional seasonal suggestions, a reader, request limits, and safe planner integration. Extend this work in place without replacing or committing someone else's unfinished source. Record the baseline before implementation. No push or production rollout is included.

## Controls and navigation

Desktop order: Country | Search places | Filters | Month & season.

- Country: searchable single-select combobox. First choice is Any country; remaining choices are the ISO 3166-1 countries/territories, displayed with English names. Country-dropdown typing only filters these options, without making provider requests. Match normalized names and two-letter country codes. Include keyboard navigation, selection indication, Escape, and a clear empty state.
- Search places: free-text input with a visible submit action. Suggestions update after 300 ms of inactivity and two characters; pressing Enter or selecting a suggestion commits the search. Typing alone does not replace the page's results. Preserve text while editing other controls.
- Filters: one popover with two clearly labelled groups, Discover by interest and Place types. Each group is multi-select. Use a mobile sheet when the viewport is narrow. Apply updates once when Apply filters is activated; Cancel preserves the last applied values. Clear filters clears both groups, preserving country, time, and search.
- Month & season: a single-select grouped dropdown. Any time first, then Months (January–December), then Seasons. Exactly one time value can be selected. Use a discriminated state, not independent month/season selections. Months and seasons are explicitly labelled in the trigger, such as Month: October and Season: Autumn.
- Applied filter chips show the group's meaning where needed, can be removed individually, and wrap within the page. Include a concise context line; do not duplicate full explanations below every control.
- URL state uses country, placesQuery, interest (repeated), type (repeated), time=any|month:1..12|season:<id>, and the existing plan parameter. Parse/validate centrally, ignore unknown selections safely, and retain plan context. Back/Forward restores the applied controls and result mode. Plans/Guides query values remain independent.
- Old destination/lat/lng/month/collection links remain readable. Explicit new country/time selections supersede the corresponding legacy context. Legacy city context is used only for old links or a planner-origin browse, is visibly stated, and is cleared by changing country or submitting a new free-text search. An old valid month migrates to month:<n>.
- Defaults on a fresh direct visit: Any country and Any time. A planner-origin visit may preselect its verified country and trip-start month, visibly shown and removable. Never silently assume a country from IP or claim global coverage from an IP-biased result pool.

## Discovery and result modes

| Applied state | Content |
| --- | --- |
| Country/time only, including Any | Discovery sections, adapted to context |
| Interests only, with country/time optional | Only selected discovery sections |
| Nonempty submitted search or at least one place type | Recommendations and Matching places |
| Search/place types plus interests | Same two result sections; interests refine the eligible places |

Discovery interests: Popular places, Hidden gems, Indoor, Scenic spots, Food & cafés, Things to do. A Seasonal picks section can appear when supported time/context evidence exists. Do not fabricate trend labels; Google popularity is not real-time trending.

Place types at launch: Restaurant, Café, Bakery, Hotel, Museum, Art gallery, Park, Botanical garden, Aquarium, Amusement park, Tourist attraction. Define provider-type mappings centrally and verify against Google's current supported type tables.

Multiple place types mean OR; multiple interests mean OR. Country, search intent, selected type group, and selected interest group intersect. For example Restaurant + Café finds either type; Restaurant + Scenic finds restaurants satisfying the scenic definition. Hidden gems requires its review-evidence rule, not a literal search for the phrase. Scenic requires credible category or explicit provider summary evidence; a nearby park does not make a restaurant scenic. When evidence is unavailable, return fewer matches and explain the limitation instead of relabelling arbitrary places.

Clearing search returns to discovery unless a place-type filter remains. The time selector never triggers results mode. Country/time changes retain applied search and filters and reset paging. Filters do not create a second competing group of discovery sections above result mode.

## Search, suggestions, and country verification

Use Google Places Text Search for semantic interpretation of queries such as Japan, Japan Osaka, Japan Osaka Restaurant, and Japan Osaka Sushi. Navio owns query composition, filters, country verification, recommendation eligibility, section layout, and state. Do not claim to reproduce Google's search engine or introduce an LLM/paid AI dependency.

- Geography-only queries are composed as places to visit in <query>, so a country/city name does not produce only an administrative-area card. Preserve explicit cuisine and place-name intent. Suggestions offer Search for <text> and labelled refinements such as Restaurants in Japan, Scenic spots in Japan, and Hidden gems in Japan. Do not rewrite a geographic Japan query into Japanese restaurants without explicitly showing that different interpretation.
- Use provider query predictions where supported, merged with deterministic Navio refinements. Distinguish a place suggestion (opens the reader) from a query suggestion (submits a search). Restrict place predictions by selected country. Google does not return query predictions with includedRegionCodes; use Navio query refinements in that case rather than treating it as an error.
- A selected country is a hard eligibility rule. Add its name to the provider query and request structured address components. Validate the returned countryCode with the existing GooglePlaceLocationMapper. regionCode alone is only a bias/formatting setting. Exclude missing or mismatched country metadata under a country lock; do not guess from formatted address text.
- With Any country, preserve explicit query geography and do not add an inherited city bias. Broad discovery is labelled as a selection, never all places worldwide. Use a bounded country-neutral query for each section; if no meaningful global pool is available, show the destination prompt and country selector rather than inventing recommendations.
- Server-side allowlists validate country codes and filter identifiers. Cap query length at 200 characters, selected interests at six, types at twelve, and pagination tokens at 4 KB. Invalid inputs are 400 errors before provider requests.
- Multi-type searches use per-type provider streams because Text Search accepts one includedType. Merge fairly, deduplicate by providerPlaceId, and apply returned type evidence. Do not assume strictTypeFiltering applies to hotel or geopolitical queries.
- Keep provider relevance order in ordinary results, with deterministic tie breaking. Ratings cannot move an unrelated place ahead of an exact query match.

## Recommendations and pagination

Recommendations contain only strong relevant matches, never padding to meet a target. Initial quality eligibility: the place passes every applied scope/filter, is not permanently closed, has a Google rating of at least 4.5 with at least 50 reviews, and falls within the provider's first result page for its query stream. These are transparent Navio selection rules, not a guarantee of quality or seasonal suitability.

- Rank eligible candidates using the existing Bayesian rating approach within the relevant candidate pool; retain provider relevance as the first ordering criterion. Do not globally rank solely by review count.
- Responsive recommendation capacity is five rows: one column below 640 px, two from 640 px, three from 1024 px, four from 1280 px. Thus caps are 5/10/15/20 cards. Show the section only when at least two rows' worth of eligible cards exist at that layout; otherwise retain all candidates in Matching places. Never fill with weaker candidates.
- Recommendation selection is derived from one ordered candidate pool, not a separate provider query. Exclude the displayed recommendation IDs from Matching places, including later pages. On a column-count change, recompute the partition without losing candidates. Recommendations beyond the visible cap remain ordinary results.
- After initial results load, freeze the ordered eligible recommendation pool for that search. Later pages extend Matching places without moving cards into/out of the recommendation section. A new applied search/filter/context creates a new pool.
- Matching places supports Load more until provider cursors end. Say Matching places, not All available places: Places API has finite query-result limits. Empty filtered pages with a continuation must show Load more, not a false terminal empty state.
- Store cursor/query/seen-place-ID state in a signed, short-lived bounded cursor or equivalent server-side short-lived pagination session. No Google content needs durable storage. Enforce matching query parameters when continuing provider tokens. Bound one frontend page to at most two provider calls; continue sparse/multi-type streams via the next cursor rather than unbounded fan-out.
- Fetch photo media only for cards in the current returned page. Preserve provider/photo attribution. Retain existing no-store behavior, cancellation, client queue concurrency two, service limiter and concurrency budget. Autocomplete must share this budget, not bypass it.

## Time and seasons

Time affects discovery composition and recommendation preference, never ordinary search eligibility by itself. The provider has no universal seasonal-suitability field; no claimed bloom dates, snow availability, forecasts, festivals, or open status can be inferred from a month.

- Any time disables seasonal weighting and suppresses the time-specific Seasonal picks section.
- A selected month uses reviewed regional climate profiles to prioritise indoor or outdoor discovery where supported. Apply this only inside the verified destination/region, not to an entire multinational or mixed-climate pool.
- Named seasons represent local seasons, not fixed northern-hemisphere months. Seasons include Spring, Summer, Autumn, Winter, Wet season, and Dry season. The menu marks a season as region-dependent where necessary. Persist the semantic season identifier rather than converting it silently to one month.
- Launch profiles extend the existing reviewed Thai city profiles and add Japan's sourced four-season calendar. Japan's calendar does not by itself establish flower/snow/fall-colour suitability; only reviewed place-type/category preferences can influence selection. Thai wet/dry handling remains regional; do not invent spring/autumn there.
- For unsupported country/region/season combinations, preserve the selected time, show one compact notice that seasonal matching is unavailable there, and show ordinary scoped discovery/results. Do not silently swap seasons, pick a hemisphere, or return fabricated seasonal cards. With Any country, only supported regional candidates receive seasonal weighting; disclose partial coverage.
- The Seasonal picks explanation is a keyboard-accessible About seasonal picks disclosure with source links and Typical conditions, not a forecast. Short ordinary section descriptions remain visible.
- Regional profiles are reviewed data with region identity/bounds, supported season IDs and month sets, approved category preferences, source URL and review date. Region evidence is checked per candidate; country alone is insufficient when it spans climates. Profiles do not change automatically based on today's month.

This coverage limit is intentional and must be visible in review: broad country browsing works independently of seasonal coverage. More seasonal profiles can be added from authoritative sources without changing the controls or endpoint contract.

## Interface and component boundaries

Keep the existing discovery endpoint compatible for old city requests. Add a dedicated public GET /v1/geo/places/explore for country/context discovery and result-mode searches, and a public GET /v1/geo/places/explore/suggestions for bounded predictions/refinements. Add narrow Next proxies and exact gateway public-read matchers; do not broaden mutation authorization. Shared DTOs contain typed applied context, mode, paged items, continuation, and optional seasonal explanation/coverage. The results response supplies eligible recommendation IDs alongside the first candidate page; it does not issue a second overlapping recommendation fetch.

Use the existing place detail/attribution envelope and add structured types/country metadata only where needed. Keep the safe My List append API unchanged. Query state is URL-backed; transient dropdown/search-draft state is local; remote state uses TanStack Query. Pure functions own URL parsing, mode selection, suggestion refinement, and recommendation partitioning. Reusable country/time/filter controls and place cards remain separate from collection/result orchestration. No new UI framework is required; use existing Shadcn/Base UI primitives with correct nativeButton semantics.

## Visual specification

- Use the existing Navio typeface and design tokens. No new decorative font, default Tailwind brand palette, ornamental gradients, invented travel scores, sparkle icons, or oversized promotional panels.
- One page grid, max width matching Explore. Horizontal padding 16/24 px; section spacing 32/40 px. Section headers, control edges, grids and attribution align to that grid. Avoid a box around every text group.
- Desktop controls share 44 px input height and label baselines, with 12 px gaps. Country has a stable useful width; search flexes; Filters and Month & season never shrink into unreadable text. At tablet widths search gets its own full row if required; at mobile all fields follow the same reading order with full-width search and no horizontal overflow.
- Use quiet card surfaces, subtle one-pixel borders, restrained 12–16 px radii, and small hover elevation. Selected chips and actions use Navio blue selectively. All icon-only controls have accessible labels and useful hit areas.
- Cards use consistent 4:3 photography, compact category/rating metadata, two-line title space, one-line location space, and bottom-aligned add actions. Stable image fallbacks occupy the same geometry. No repeated empty reason paragraphs or oversized provider-credit blocks.
- Headers and supporting text are anchored through spacing and proximity to their content; source disclosures sit inside the associated section. Empty/error/loading states use the same grid and surface rhythm. No hanging text or arbitrary misaligned ornaments.
- Gentle 150–200 ms interaction transitions; respect reduced motion. Keep image and card dimensions stable during loading. Search suggestions and popovers stay inside viewport bounds and above the sticky Explore tabs without obscuring input focus.
- Target widths for review: 360, 390, 768, 1024, 1440 px; also 200% zoom, long country names, long place titles, dark mode, empty/error states and keyboard navigation. Visual review must actually run before claiming a polished or glitch-free result.

## Verification and delivery

1. Baseline existing Places, reader, planner append, gateway authorization and unrelated dirty-file inventory before changes.
2. Behaviour tests first: mode matrix, multi-select semantics, Any time, exclusive time values, URL restoration, legacy links, country-lock leakage, missing country metadata, country/query conflicts, sparse pages and cancellation.
3. Recommendation tests: eligibility thresholds, no padding, two-row minimum, five-row responsive cap, stable first-pool selection, cross-page dedup and relocation between sections on resize without loss.
4. Season tests: Thai regional differences, Japanese calendar, unsupported profiles, wrong hemisphere/mixed regions, Any country partial coverage, Any time no weighting, and no season-based exclusion of ordinary matches.
5. Provider contract tests: country metadata mask, one includedType per request, hotel exceptions, query-prediction/country restriction compatibility, cursor parameter consistency, bounded provider fan-out, attribution and rate-limit failures.
6. Run targeted client/backend tests, scoped lint, full TypeScript, whitespace checks, and a production build with Places enabled. Validate narrow public GET routes and protected mutation/deeper routes.
7. Browser review at the listed sizes and keyboard/zoom; verify real searches and add/save/reopen on an authorized disposable plan. Do not modify production accounts or reset local data for this work. If browser automation is unavailable, state that limitation and leave visual acceptance open.
8. No migrations expected. Do not commit existing unfinished source without separate authorization. Required agent-note-only commits follow the root docs branch/dev workflow; no release or push.

## Research references reviewed 2026-10-15

- Google Text Search: https://developers.google.com/maps/documentation/places/web-service/text-search — semantic queries, type filtering, geographic bias/restriction and pagination limitations.
- Google Text Search REST contract: https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places/searchText — page-token and request-shape constraints.
- Google Autocomplete: https://developers.google.com/maps/documentation/places/web-service/place-autocomplete — predictions, regional restrictions and required attribution.
- Google Autocomplete REST contract: https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places/autocomplete — query predictions are unavailable with includedRegionCodes.
- Japan Meteorological Agency: https://ds.data.jma.go.jp/gmd/cpd/longfcst/en/tourist_japan.html — local season calendar and regional climate context.
- Japan Meteorological Agency regional guidance: https://www.data.jma.go.jp/cpd/longfcst/en/tourist.html — substantial regional climate differences.
- Australian Bureau of Meteorology: https://www.bom.gov.au/resources/learn-and-explore/climate-knowledge-centre — why a global four-season or hemisphere-only assumption is inappropriate.
- Existing Thai Meteorological Department reference/profile definitions remain in PlaceDiscoveryService and docs/features/places-discovery.md; reverify before extending those profiles.

## Review state

User approved the written specification and explicitly requested review after implementation. Implementation and focused tests are complete locally; see the implementation plan's execution record and docs/features/places-discovery.md. Live provider reads and pagination were verified. Responsive visual, interactive filter/keyboard, and disposable-plan save/reopen acceptance remain open; do not claim pixel-perfect or release readiness from tests alone.
