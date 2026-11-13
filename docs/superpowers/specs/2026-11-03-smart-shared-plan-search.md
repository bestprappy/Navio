# Smart Shared Plan Search — final proposed design

Status: researched and challenged on 2026-11-03. Proposed for user review, NOT implemented or authorized for deployment. Supersedes the earlier suggestion that more suffixes alone would solve search. Existing live release65a4105 stays unchanged.

## Outcome and scope

People can type a partial word, rough phrase or travel request and receive natural search suggestions plus real published plans that satisfy its meaning. Suggestions help formulate a query; titles identify actual plans. Preserve default Explore, existing country/duration controls, visual-only Interests, raw typing ownership, plan cards, publication/copy privacy and yearless dates. This change is Shared Plans only; do not modify Places, Guides, planner, navigation, teammate-reserved UI/auth or published samples.

No finite plan can enumerate all natural language or eliminate all future fixes. The acceptance suite below defines the supported language and critical invariants; unsupported requirements must be visible rather than guessed.

## Approach decision

| Approach | Strength | Failure discovered / tradeoff | Decision |
|---|---|---|---|
| More fixed suffixes and word AND matching | Small patch | Repetitive phrases; examples become requirements; negation mishandled; every concept needs another patch | Reject as architecture |
| LLM interprets and rewrites on each keystroke | Flexible grammar | Network delay, cost, nondeterminism, drift, service failure and adversarial public text; still needs evidence retrieval | Reject for first release |
| Vector-only search | Finds related meaning | Similarity cannot enforce country, exclusions, exact activities or calendar evidence; model/index infrastructure and evaluation needed | Reject as sole decision maker |
| Structured travel intent + compositional suggestions + evidence ranking | Explainable, fast, testable, fits existing service | Bounded English interpretation and maintained travel concepts; not arbitrary human comprehension | Recommend as complete initial implementation |
| Hybrid lexical/vector candidate retrieval behind the same intent/evidence interface | Can improve paraphrase recall | Additional infrastructure/model and privacy review; requires measured gain | Extension only after baseline evaluation, not a hidden requirement for launch |

The initial system uses semantic travel concepts (typed relationships), not embedding similarity. Do not market it as a trained AI model. No new hosted API, Elasticsearch service or database extension is required. Existing PostgreSQL16 and Trip Planning service remain authoritative.

## 1. Preserve raw input; parse into an explicit interpretation

Keep the actual text and caret untouched, including spaces and IME composition. Normalize a separate search representation. Parse longest geographic/event phrases before individual terms; preserve quoted text, negation, conjunctions, units and date punctuation until interpreted. Unknown important terms are retained as lexical requirements.

Proposed internal `SearchIntent`:

- original text and normalized fingerprint;
- required geography, including multiple destinations and unresolved alternatives;
- required concept groups (`allOf`, `anyOf`), excluded concepts and optional preferences;
- examples under a broader category, kept as boosts unless explicitly required;
- event/month/day intent, unsupported requested year and ambiguity notices;
- exact duration and source (control/query), conflicts and unsupported constraints;
- parser/concept version and source spans explaining each interpreted facet.

Examples:

| Input | Interpretation |
|---|---|
| Thailand Christmas Holiday | Thailand required; Christmas event; holiday means vacation here, not a compulsory literal word |
| Christmas festival trip in Thailand | Both Christmas and festival required |
| Christmas weekend in Thailand | Christmas AND weekend style; December alone cannot skip weekend evidence |
| Scenic Thailand, focus nature like gardens, forests, mountains | Thailand required; nature focus; examples suggest alternatives/preferences, not all three compulsory |
| Thailand mountains or gardens | At least one category |
| Thailand mountains and gardens | Both categories present in the plan, potentially different stops |
| Thailand gardens, forests, mountains | Comma list is ambiguous: use any-of initially and visibly summarize “gardens, forests or mountains”; offer require-all refinement |
| Prefer mountains, no beaches | Mountains preference; beaches excluded from scheduled stops |
| Japan sushi | Country AND sushi specifically; generic food is insufficient |

Bare requests such as “scenic” may match several scenic categories; specific “mountain” must not expand backwards to every scenic beach. Synonyms are equivalent; parent/child concepts are directional. `forest` is nature, but nature is not always forest. Botanical garden is not every amusement park; mountain temple does not establish a hiking activity. Record these as typed relationships rather than one flat alias list.

Negation is scoped to clauses/items. “No beaches” in an owner's note is not positive beach evidence; “not only gardens but also mountains” must not become a blanket exclusion. “Not far from Bangkok” is proximity, not exclusion of Bangkok. Uncertain constructs receive a notice/clarification, not a confident silent rewrite. An excluded optional saved place should not automatically reject the scheduled itinerary: apply exclusions to itinerary evidence by default, and explain scope. Missing/unknown place types do not prove that an itinerary is beach-free; say “no beach stops identified in the published itinerary,” never certify real-world absence or safety.

Country control and typed geography must agree. A selected Japan plus typed Thailand yields a clear conflict with explicit resolution actions, not silently returning Japanese or Thai plans. “Japan and Thailand” requires both; “Japan or Thailand” permits either. Ambiguous Georgia or Paris requires destination choices when evidence cannot resolve it. Do not silently autocorrect geographic names into a different real place.

Duration controls retain current conversion (month=30 itinerary days, year=365 itinerary days), visibly described as conversions rather than calendar-month arithmetic. Explicit query duration must agree with the control. Weekend does NOT require two/three days automatically; yearless publication cannot prove Saturday/Sunday. Initially require affirmative weekend-style content; offer short trips as an explicit alternative rather than silently weakening Weekend. Ranges/“at least” that lack support get an explanation and an explicit exact-duration alternative; never pretend an exact field applied a range.

## 2. Compose suggestions from meaning

Generate a bounded set of at most24 candidates per request using recognized intent slots, approved grammatical arrangements, corpus facets and real plan titles. Validate every candidate by parsing it back and comparing intent. Avoid a fixed three-suffix output per country. Equivalent reorderings do not consume multiple visible slots. No grammar or word combinations copied blindly from arbitrary publisher text.

Types:

1. **Suggested searches:** corrections/rephrasings/completions preserving all required facets and exclusions. At most3.
2. **Explore alternatives:** explicitly labelled refinements/broadenings. At most2. Each records what changes; no automatic execution.
3. **Matching plans:** actual titles from the same Matching pool as results; at most3.
4. **Relevant plans:** actual titles from the same Relevant pool; at most2, with a brief evidence reason.
5. Destinations appear only while geographic completion/disambiguation is useful; at most2. A complete “Thailand Christmas Holiday” should prioritize search phrases over repeating Thailand. Literal Search for “…” remains one fixed footer action.

For `Thailand Christmas Holiday`:

- Suggested: Christmas holiday trips in Thailand.
- Alternatives: Christmas festival trips in Thailand (adds festival); Christmas weekend trips in Thailand (adds weekend); December holidays in Thailand (broadens Christmas). Show at most2 alternatives, choosing useful diverse changes rather than displaying all examples every time.
- Winter is NOT an automatic synonym for Christmas. A winter alternative needs an explicit seasonal interpretation, and never promises snow/climate. Initially keep ambiguous season language unresolved with useful season/month choices; no new climate engine in this scope.

Refinements with actual catalogue support rank above unsupported ideas. Meaning-preserving generic suggestions can remain when inventory is empty, marked “Search idea” when availability is zero/unknown. Do not imply an event exists or invent a result count. Retain one good idea rather than padding to a minimum. Completely unknown gibberish can legitimately have only the literal search action.

“Christmas festival” is a theme to search, not a factual claim that a particular festival exists in the chosen destination. Do not invent named events. Named movable holidays require explicit published text; do not calculate dates without an approved calendar source. No private search history/personalization in this release.

Choosing a search suggestion sets and submits the visible phrase while preserving filters. Choosing an alternative shows its changed intent through its label/interpretation summary and then searches that phrase. A plan-title selection opens the actual publication. An explicit destination choice preserves other typed facets; changing country requires an explicit action. Never silently turn “Thailand Christmas” into just “Thailand.”

## 3. Build structured public evidence

One evidence document per currently active, listed, eligible publication: title, public destination, dated public itinerary if selected, scheduled stop name/type/location, affirmative owner introduction/notes/checklists, public transport/EV evidence, and optional My List evidence. Preserve source kind, item/day association, certainty and revision rather than concatenating all text into one bag. Prepared checklist text is weaker than a scheduled stop and cannot establish attendance, accessibility or a verified service.

Use sanitized frozen snapshot data only. No private planner joins, original years, unselected notes/budget, bearer-only unlisted plans or external Google requests at search time. Use existing provided public place types; missing types mean unknown. A place called Christmas Cafe does not establish a Christmas event. Public review snippets/questions/hypothetical plans do not establish scheduled activity.

Evidence tiers: scheduled structured stop/affirmative specific title > affirmative owner description > optional suggestion/My List mention. Specific claims such as wheelchair access, free admission or child suitability are never inferred from broad categories. User “budget” may be a thematic preference supported by owner text; a numeric cost ceiling needs sufficient included budget evidence and currency context, otherwise state unsupported. Do not silently discard it.

## 4. Apply eligibility before ranking

Evaluate ALL hard gates before selecting Matching or Relevant; never return early for a date/semantic hit. Gates: visibility, geography, selected/extracted exact duration, exclusions, required concepts/quoted residuals, and temporal requirements/conflicts.

- **Matching:** all required facets supported by direct or validated equivalent/typed evidence. Does not require identical title wording. No arbitrary “90% confidence” score in UI.
- **Relevant:** all hard constraints remain satisfied; at least one important facet has genuinely weaker but defensible evidence (for example public December dates rather than explicit Christmas activity, or optional versus scheduled nature evidence). Identify the weaker facet in the reason. No country-only rescue.
- **Alternatives:** changes a required facet; only executes after the user selects it. A generic Thai beach plan cannot enter Relevant for Christmas just because Thailand agrees.

Rank lexicographically: evidence tier/completeness; whole-phrase/title and concept alignment; scheduled-stop coverage/focus; temporal proximity where appropriate; explicit soft preferences; then low-weight popularity/recency; stable publication ID tie-break. Repeated keyword stuffing must not increase scores indefinitely. Nature focus should favor a nature-led itinerary over one incidental garden among many malls. Initial focus score counts distinct scheduled place stops (not notes/chargers/transport endpoints), uses known typed evidence with an unknown-data penalty, and exposes no invented accuracy percentage. Pin expected relative order in judged tests before tuning numeric boosts.

Christmas direct text with contradictory public February dates cannot be Matching. With no dates, affirmative Christmas content may qualify. Public December-only dates may be Relevant, with proximity to Dec25 ranking nearer trips above distant December trips; reason says December, not Christmas attendance. Christmas AND festival still requires festival evidence. New Year uses the existing Dec26–Jan7 relevance window. Year-specific confirmation remains unavailable because published dates are month/day only. Show the limitation and an explicit remove-year alternative, never read private years. No inferred weekdays.

## 5. UI and contract

Keep existing controls, card design and page structure. Add a quiet interpretation summary only for nontrivial parsing, alternatives, conflicts or uncertainty. Keep Matching and Relevant result sections and separate deduplicated pagination. Suggestions stay within the viewport below the field, with grouped headings and clear labels, no overflowing tall list. Empty title groups use compact status rows, not huge panels. Loading, unavailable and zero-results are distinct.

### Result-section empty states (user refinement)

Use the completed first-page totals for the current fingerprint, not just the currently loaded card arrays. Never decide “no results” from a pending request, an empty later page, a failed service or stale data. Conflicts/unsupported required constraints show their resolution notice before normal empty-result messaging.

| Matching total | Relevant total | Useful alternatives | Page rendering |
|---|---|---|---|
| Positive | Positive | Any | Matching plans, then Relevant plans; optional compact Alternative searches only if useful |
| Positive | Zero | Any | Matching plans; omit the empty Relevant section; optional useful alternatives |
| Zero | Positive | Any | Matching plans with one compact “No matching plans found.” message; Relevant plans below; useful Alternative searches last |
| Zero | Zero | Present | One combined “Matching and relevant plans” section with “No matching or relevant plans found.” and “Explore an alternative search below.” Then Alternative searches only; do not render two empty panels |
| Zero | Zero | Absent | One larger, calm empty-state panel; no empty Matching, Relevant or Alternatives sections |

Full-empty copy: heading “No plans found for this search.” Body “Sorry, we couldn’t find any published plans matching your search and selected filters. Try different keywords or adjust your filters.” Show the query/filter context safely, plus Edit search (focus/select search text) and Clear filters only when filters are active. With no active filters, offer Browse all plans to explicitly return to the existing default landing. Avoid exaggerated apologies or implying the system has searched the whole internet. No-results is not a technical failure.

Alternative searches are explicit query refinements/broadenings, not invented plan cards or secretly relaxed results. Cards from a broader query remain absent until the reader chooses that query. Show a brief changed-intent label such as “Broader dates: December.” Exclude exact duplicates, meaningless changes and alternatives confirmed to have no results; if support is unknown but the idea is defensible, label it “Search idea” without a count or promise. Do not count generic Edit search/Clear filters buttons or the unchanged literal search as available alternatives. The autocomplete can still offer inventory-independent meaning-preserving suggestions under its separate contract.

Keep compact notices when real plans are visible. Reserve the larger panel for a genuinely completed all-empty search. It should fit the page design, not fill the entire viewport. Retain current result sections while loading additional pages or displaying a next-page error. Announce one concise result-state change via aria-live, avoiding duplicate announcements across empty sections.

Backend owns interpretation, evidence classification and compositional phrases. Frontend owns raw draft, small safe destination/unfinished-word fallback, UI and keyboard. It must not recreate a second semantic matcher from incomplete feed summaries.

Keep current endpoint and legacy fields. Add optional `searchAssist` with schemaVersion=1, fingerprint, conceptVersion, interpretation/facet notices, typed suggestions `{text, kind, changedFacets, availability, action}` and catalogueRevision. Keep existing `querySuggestions` text/source enum for old clients; do not introduce new enum values there. Fingerprint includes query, country, duration, sort and interpretation version. No internal snapshot/token beyond existing public titles/links in notices. Query input max256 Unicode code points, consistently validated; retain raw input and show explicit validation instead of silent truncation. Roll backend compatibility first before new client sends >100 characters; expose capability before lifting client bound.

All async responses bind to their fingerprint; abort obsolete requests and ignore stale completions. Keep 250ms debounce, Enter immediate, composition-end safe, preserve caret/spaces/history. Up/Down navigate, Enter selects only the active option, Escape closes without changing text; Tab does not force a choice. Follow WAI-ARIA combobox semantics. Announcements are concise; use text labels beyond icons/colors. Mobile390px and200% zoom must remain usable.

## 6. Performance, consistency and fallback

For the current small catalogue, one authoritative eligible-publication stream per request; reuse its evidence for retrieval, phrases, support counts and titles. No full search per suggested phrase. Cache only parsed evidence by publicationID+revision+sanitizerVersion+conceptVersion, bounded by entry/byte limits (initial ceiling5,000 entries/32MiB, lower eviction limit wins). Every request must query current eligibility/revision; cached removed, unlisted or superseded content is not returned. Never use view-count updates as the evidence content revision.

No cached complete public responses or generated claims on client fallback. A failed API still permits safe grammar/destination completion marked unavailable; real title counts/results show failure rather than “no plans.” If cache fails, rebuild from authoritative snapshots. No writes/backfills/migrations needed initially. Parse invalid snapshots as skipped eligible-data errors with metrics, not whole-request500 and not silently total zero on a database failure.

Compute catalogueRevision from eligible IDs and publication content revisions; pagination carries that revision. If it changes between pages, reset/re-fetch the result sequence with a small notice rather than combine inconsistent pages or fake stable totals. Preserve visible results on a failed next-page request. Stable ordering within a revision, no duplicates between groups, group totals reflect actual membership. Current response fields remain for old clients.

Performance release targets (not measured claims): on1,000 representative publications and5 concurrent sessions, warm API p95<=300ms and p99<=750ms; cold evidence rebuild<=1.5s; browser suggestions normally visible<=800ms after typing stops, including250ms debounce. Instrument parse/evidence/rank/serialization separately. Benchmark5,000 publications too; if targets fail, do not ship a silent truncate/fabricated count or add more synchronous API calls. Move retrieval to an additive public-only PostgreSQL document/index projection with transactional publication updates as a separately reviewed prerequisite. PostgreSQL full-text/trigram and later vector candidates remain interchangeable behind the same intent/evidence gates; public-only rechecks always apply.

## 7. Challenges and fixed decisions

| What if | Decision |
|---|---|
| Good wording, no actual plan | Meaning-preserving search idea remains; empty titles/results honestly reported |
| More fluent phrase drops festival/no-beach | Reject rewrite; only labelled explicit alternative may change it |
| Different word order/plural/alias | Canonical intent equivalence; don't show redundant rearrangements |
| Food versus sushi / nature versus forest | Directional concept edges, not one shared synonym bucket |
| User says “like,” “or,” “and,” or comma list | Examples/preferences, any-of, all-of or visible ambiguity respectively |
| Wrong country but high similarity | Reject before ranking |
| Event evidence admits before weekend check | Hard gates first; regression pinned by design experiment |
| Two/three days but no weekend evidence | Short-trip alternative only; no invented weekdays |
| Private/unlisted/revoked plan in cached evidence | Authoritative eligibility on every response; exclude from titles, counts and suggestions |
| Country same but event/activity absent | Reject; never fill Relevant with it |
| Public dates hidden / original year requested | No temporal inference from private data; visible limitation |
| Season ambiguous / southern versus northern region | Ask via choices; no unsupported weather/snow promises |
| Ambiguous city / conflicting duration | Visible interpretation/resolution; no silent prioritization |
| Multicountry plan | Require query country evidence at actual stop/destination; don't infer every stop shares the primary country |
| Owner text says avoid/optional/question | Scoped negative/uncertain evidence, not blanket sentence inclusion/removal |
| HTML/prompt injection/huge punctuation/query | Escaped display, parameterized DB, bounded input/expansion; no executable or LLM instructions |
| Non-English or mixed script | Unicode-preserving literal/name matches; English concept interpretation only until evaluated language support added |
| Slow service, offline, rapidly edited query | Safe local completion and honest unavailable state; discard late responses |
| Sort recent/trending | Same membership gates; reorder within group, never make popularity override constraints |
| Publisher updates/revokes during pagination | Revision change resets pages; next authoritative read sees current state |
| Empty query/all filters cleared | Existing default landing; no new search request or UI redesign |

## 8. Evaluation and release gates

Completed design evidence: read-only16-query live baseline; offline42 labelled admission/phrase-policy cases and192 Cartesian evidence combinations. Experiment found and corrected early-return admission before weekend gate. These do NOT establish a production parser, a vector/LLM model, end-to-end accuracy, performance or completed implementation. Scripts/results in output/smart-search-*20261103.* are local artifacts. The reproducible policy spike is preserved in `docs/superpowers/experiments/2026-11-03-smart-search-policy-lab.mjs`. See companion evaluation note.

Before implementation tune on120 judged queries; reserve60 unseen validation and60 holdout/adversarial queries (240 total minimum, all labelled against controlled publications). Include at least20 controlled publications with positive/negative evidence and a separate snapshot of real catalogue examples. Do not require results for genuinely absent inventory. Each case contains raw input, expected intent/ambiguity, accepted/rejected suggestions, candidate relevance grades and reasons. Include paraphrases/unseen phrasing, negatives and sparse records, not just exact vocabulary fixtures.

Release gates: zero privacy/hard-filter/exclusion violations; zero unlabelled intent-changing rewrites in the judged suite; >=95% suggestion validity and Matching precision@5; >=90% Relevant precision@5 and supported-intent recall@10; nDCG@10>=0.90 on graded non-empty queries. Report macro averages, category breakdowns, empty-result behavior and sample sizes, not a universal accuracy percentage. Sparse query precision denominators use returned items; measure recall separately to prevent a system passing by returning nothing. Fail critical categories even if average passes. Parser assertions compare actual raw-language output against manually labelled intent; do NOT feed annotated intent directly and call it NLP verification.

Run red/green unit tests, raw-query-to-result integration with real PostgreSQL and full-context startup, concurrent visibility/update tests, compatibility fixtures, real browser keyboard/IME/spacing/race/mobile/history/default tests and1k/5k concurrency benchmarks. Use explicit isolated SPRING_DATASOURCE overrides for every full context, disable delivery/discovery/bus, assert test DB identity before writes. Never use shared local or VM data for fixture writes. Existing publication/copy/yearless/notes/MyList/Garage suites remain required, though this revision must not change their source data.

Feature flag new backend behavior; dual evaluate only in test/shadow mode, no user-visible automatic alternatives. Backend first with legacy wire compatibility, client second, exact-pins PostgreSQL deployment gates. User approval needed at concrete VM release step; this planning request is not release authorization. Canary public GET checks include existing basic searches, new natural phrases, missing inventory, hard filters, revoked items, preserved spaces and genuine querySuggestions. Roll back flag on hard-constraint leakage, precision regressions or latency failures; no schema rollback needed for initial design.

## Sources and their role

- PostgreSQL16 text parsing/query/ranking: https://www.postgresql.org/docs/16/textsearch-controls.html — existing-DB future retrieval option, not a claim that ts_rank is semantic understanding.
- PostgreSQL16 trigram matching: https://www.postgresql.org/docs/16/pgtrgm.html — spelling retrieval option, not permission to autocorrect valid geography.
- Elastic multiword/equivalent versus directional synonyms: https://www.elastic.co/docs/reference/text-analysis/analysis-synonym-graph-tokenfilter — concept design reference; no Elasticsearch installation proposed.
- Elastic hybrid lexical/semantic search: https://www.elastic.co/docs/solutions/search/get-started/semantic-search — evaluated extension path, not required first-release infrastructure.
- Algolia query suggestions and duplicate/minimum-hit controls: https://www.algolia.com/doc/guides/building-search-ui/ui-and-ux-patterns/query-suggestions/js — support-aware suggestions. Navio deliberately also allows labelled inventory-independent search ideas per user requirement.
- W3C combobox: https://www.w3.org/WAI/ARIA/apg/patterns/combobox/ — keyboard/accessibility contract.
