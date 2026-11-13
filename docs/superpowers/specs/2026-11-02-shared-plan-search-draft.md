# Shared Plan live search - draft for user review

Status: proposal only. No implementation approved. Scope: Explore > Plans only. Preserve Guides/Places search state, shared reader, publication/copy/save/profile pin/notification behavior and global navigation.

## Existing state
Remote client origin/dev inspected without switching the nested checkout. ExplorePage filters already-loaded recent cards using a lowercase includes query. Feed query currently accepts page/size/sort only. This can omit matching plans outside loaded pages. Places CountrySelect has searchable country list/Any country and keyboard behavior; extract or share it carefully, preserving existing Places behavior.

## Approach
Recommend a dedicated read-only server catalogue query plus suggestions, backed by existing public listed sanitized publications. Client-only filtering cannot satisfy complete results. No separate commercial search engine or runtime LLM required initially. Isolate search query code from publication writes and coordinate ownership of existing publication integration before implementation. No migration number allocated by this draft.

## Layout
Explore tabs and page introduction remain. Desktop single aligned toolbar: Country | Search shared plans (widest) | Filters | Trip duration. Labels always visible. Consistent heights, restrained borders, compact responsive sizing. Active country/duration chips and Clear all below, then result count and sort. Mobile search full width and compact controls below; touch-friendly popovers/sheets. Preserve tab/navbar sticky offsets; no new global sticky region by default.

Country: use Places searchable single-select, Any country default, all supported countries; typing inside dropdown filters country names only. Selected country is a hard constraint combined with query and duration. Country selection does not silently modify free text.

Filters: visual design only in this phase. Explicit non-active preview state; no fake applied count or pretend filtering. Future keyword/interests panel not assigned functional semantics yet.

Duration: Any duration; 1 day; 2-3; 4-7; 8-14; 15+; optional custom min/max day range. One selection, inclusive bounds, positive whole days, min<=max, clear validation. Published itinerary day count, not exposed actual travel dates or difference of date strings. Unknown durations remain in Any and excluded from constrained ranges unless later product decision changes this.

## Live suggestions and results
From 2 typed characters, debounce about250ms; suggestions and results update without Enter. Cancel/ignore superseded requests. Preserve prior grid while fetching with an honest Updating status; never label old results as matches for new query. Composition-aware input. Empty query opens suggestions only when useful; no invented history/trends.

Dropdown anchored to search, about8 entries total in two labelled groups: Destinations (country/city plus parent country) and Shared plans (real title, destination, duration, optional tiny cover). Highlight literal match text safely. Counts only if actually supplied by current catalogue query. Destination suggestions prefer places with matching public plans; countries with no matches remain selectable through country filter. Never fabricate titles or counts.

Destination suggestion fills a canonical destination intent while respecting selected country; visible field/chip makes intent clear. Plan suggestion opens that plan. Enter without highlighted option confirms full current search, closes dropdown and flushes debounce; Enter on active suggestion selects. Up/down navigate, Escape closes without clearing text, Tab moves normally. WAI-ARIA combobox/listbox semantics and polite result announcements.

Clearing query preserves country/duration; Clear all resets all active controls. Country conflicting with query yields scoped no-results state and visible Clear country action, never silently drops the country lock. Sort default Relevance for query, Recent/Trending optional; filters without query retain ordinary feed sort choices.

No constraints: existing Trending and Recent landing feeds. Any applied query/country/duration: a single deduplicated paginated Matching plans grid; do not duplicate same results into Trending/Recent sections. Pagination and totals use whole filtered catalogue, reset on query/filter change. Back from plan restores query, filters, sort, loaded results and reasonable scroll. URL represents applied search/filter/sort, not pending draft every keystroke; use replacement while typing, not a new history entry per character.

## Matching
Only active public Explore-listed sanitized snapshots eligible; private, unlisted, removed, blocked or inaccessible entries must respect existing visibility rules. Same predicate for suggestion titles, counts and results.
Normalize Unicode/case/diacritics/punctuation/whitespace. Match title, structured country/city destinations, published place names/highlights; tokenize multiword queries instead of one exact substring. Resolve country aliases such as USA/United States and UK/United Kingdom to canonical country codes. Country search can match a Kyoto-titled plan whose published country is Japan. Multi-country plans match each reliably recorded published destination; do not invent country associations from ambiguous city text or private owner data.

Rank exact destination/title and phrase matches ahead of word prefixes, token coverage, then controlled typo candidates. Popularity only tie-breaks relevance; stable token tie-break for pagination. Keep typo handling conservative; did-you-mean is preferable to silently replacing intent when uncertain. No unverified activity tags generated from prose.

## Backend boundary and efficiency
Dedicated read-only search/suggest handler/service or narrow existing feed query extension, coordinated before touching friend's publication code. Query across all eligible publications with bounded pages and suggestion limits; do not fetch every plan into browser or treat loaded pages as complete. Country metadata must be trustworthy; inspect current published snapshot coverage before selecting extraction/index strategy. Reuse existing database capabilities and add indexing only if measurements justify it, following database rules/current migration coordination. No schema change implied by this review draft.

## Acceptance examples
- Ban offers matching public plan titles and relevant destination completions.
- Japan finds plans in Japan with unrelated titles.
- Multi-country itinerary appears under each reliably recorded country.
- Selected country AND duration AND text all apply.
- A match beyond first feed page still appears.
- Short plans do not include longer itineraries; unknown day count not converted into1day.
- Out-of-order responses cannot replace a newer query; IME, keyboard and mobile work.
- Unlisting/deletion/access changes remove suggestions/results through current visibility checks.
- Filters preview does not change data or show an active badge.
- Existing author links/pins, publishing notifications, copying and saving remain unchanged.

References: https://www.w3.org/WAI/ARIA/apg/patterns/combobox/ ; https://www.algolia.com/doc/guides/building-search-ui/ui-and-ux-patterns/query-suggestions/in-depth/query-suggestions-faq/angular (interaction reference only, no Algolia dependency proposed).

## Approved implementation refinements

User subsequently approved numeric duration plus Days/Months/Years (replacing proposed presets); exact itinerary-day matching with explicit30/365 conversions. No query/country/duration preserves default Trending/Recent, including blank Enter. Active criteria use recommendations plus paginated remaining matches without duplicates. Keyword/interests Filters remain an explicitly labelled preview. Implementation/verification status is tracked in the2026-11-02 implementation plan.
