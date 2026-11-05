# Smart Shared Plan search — implementation and verification

## Status

**Release update:** User subsequently approved release. Client `bcf1d63`, Trip `66ea735`, compatible teammate Mobility `afc6ccf`, server `35afd9c` and root `5b2a2eb` were published through dev/main. [Workflow41991110563](https://github.com/bestprappy/Navio/actions/runs/41991110563) attempt1 passed revision/Postgres and other images, but the web image failed before deployment on existing Next.js Google Fonts query parsing. Deploy was skipped; VM still uses the prior release and health200/protected401 were verified. Retry awaits the user's GitHub UI action because the connector lacks Actions write permission. No search code or font/library changes were made to address this intermittent build issue. The implementation snapshot below describes the earlier local-only verification point.

Implemented and committed locally, **not deployed**. Client `bcf1d63` and Trip Planning `66ea735` are on their respective `feat/smart-plan-search-20261103` branches in `output/smart-search-work/`. They incorporate the newer teammate dev histories (client `eb3d858`, Trip `ca3596a`) without conflicts. Ordinary working directories, existing local changes and the user's dev:vm process on port 3000 were preserved.

The laptop sleep/resumption audit found no source loss. A stale execution ledger was corrected after verifying source and logs. The isolated browser's earlier first-query timeout was resolved by allowing hydration before typing. Its missing Keycloak configuration was supplied only to the test process; authentication source was not changed.

## Implementation report

### Query interpretation and eligibility

- Existing service now uses a structured travel-intent parser and a versioned, directional concept vocabulary. Nature can be supported by forests/mountains/gardens; a specific sushi request is not satisfied by any restaurant.
- Country/city, exact duration, named months/calendar days, AND/OR interests, examples, preferences, quotations and exclusions are handled separately. Unknown specific words are retained instead of discarded to manufacture results.
- Geography groups preserve country context: `Japan Tokyo or Kyoto` does not admit Osaka merely because it is in Japan.
- Conflicting countries/durations, impossible named dates and unsupported constraints produce clarification. Negated events/months are explicitly blocked rather than interpreted positively. Broad seasons, accessibility and numeric ranges are not inferred.
- Matching requires direct or equivalent public evidence for all required criteria. Relevant plans must still satisfy every hard criterion, with explanations for weaker optional-content, spelling or calendar evidence.
- Christmas text can directly match; public December dates can support Relevant results. December alone cannot satisfy additional festival/weekend requirements. Nearer public dates rank higher. A place named Christmas Cafe is not evidence that its trip is about Christmas.
- Nature-led trips rank above trips with an incidental nature stop. Sorting remains deterministic. Month/day publication and copy contracts from the preceding release remain intact; no original year is inferred and private planner dates are not searched.

### Search ideas and result presentation

- Composed natural phrases replace the fixed itinerary/road-trip/weekend suffix list. Examples include `Christmas holiday trips in Thailand` and `Nature trips in Thailand` where the interpreted input supports them.
- Same-intent rewrites are reparsed and checked for equivalent criteria. Refinements and broadenings are explicitly labelled, including what they change. Selecting an alternative is required before changing the user's search.
- Topic ideas can still appear when there are no available plans. Actual Matching/Relevant title suggestions always come from eligible public publications.
- Autocomplete presents up to three Matching and two Relevant titles, bounded useful destinations, phrase ideas/alternatives and one literal search action. Existing keyboard/IME/raw-draft behavior is retained.
- When only Matching is empty, a compact notice precedes actual Relevant cards. When both are empty but useful alternatives exist, one combined notice precedes Alternative searches. When everything is empty, one larger recovery panel offers Edit search, Clear filters where applicable, and Browse all.
- Loading, failures and conflicting requirements have distinct states. Pending input does not show a stale no-results claim. A refreshed catalogue revision resets pagination, including refetch failures after multiple cached pages.

### Contract and operations

- Anonymous read-only endpoint and public snapshot eligibility remain unchanged. Search does not join private trips or write application data.
- Optional `searchAssist` metadata includes schema/concept version, current query/filter identity, catalogue revision, interpretation/notices, capability and typed suggestion actions. Legacy result fields and suggestion source values remain supported.
- Query limit is 256 Unicode code points on the new backend/proxy. The client confirms server capability before accepting more than the legacy 100-character protocol limit; input is not silently truncated.
- Later pages carry the catalogue revision; changed publication visibility/revisions return HTTP 409 so the client can refresh from page zero.
- Parsed immutable public evidence is cached with a 32 MiB estimated-weight bound and a 5,000-entry admission ceiling. Once at that ceiling, new evidence is safely parsed uncached. Eligibility is checked before every cache lookup. This is an admission ceiling, not an LRU guarantee or a measurement of total JVM resident memory.
- Backend rollback: `navio.search.smart-enabled=false` selects the retained legacy search implementation. No search migration, dependency addition or global authentication change was introduced.

## Test results

### Combined-version automated checks

| Check | Result |
| --- | --- |
| Full frontend suite after integrating teammate changes | 689 passed, zero failed/skipped |
| Full Trip Planning suite with all Spring datasource settings explicitly isolated | 634 total, zero failures/errors, 3 skipped |
| Real PostgreSQL migrations/JPA validation and publication/copy regression tests | Passed within full backend suite |
| Final fixed-label retrieval/rewrite evaluation | 241 tests passed after final test-only assertions |
| TypeScript using exact committed tsconfig | Passed |
| ESLint across every changed search source | Passed |
| Standard production Turbopack build on integrated source | Passed |
| Changed-file whitespace checks | Passed |

Three skipped tests are the existing `MyListAppendPersistenceTests`; they were not exercised. Counts above include existing project regressions, not exclusively new search tests.

The isolated dependency junction required a temporary Turbopack filesystem root encompassing both workspace and dependency target. It was restored afterward. A fallback webpack build encountered an existing pure-global CSS module selector outside search; that unrelated stylesheet was left unchanged. The project's standard Turbopack production build passed. Generated isolated tsconfig changes were discarded, while the user's original modified tsconfig remained untouched.

### Judged queries and limits of the evaluation

240 raw query surfaces use 20 controlled publications: 120 development, 60 validation and 60 holdout. They cover 24 intent families with wording variations, not 240 independent real-world topics. Manual Matching/Relevant membership labels are stored separately from the parser.

On the 60 holdout surfaces, 44 had relevant or matching documents:

| Controlled-fixture metric | Measured |
| --- | --- |
| Matching precision@5, nonempty returned pools | 1.000 |
| Relevant precision@5, nonempty returned pools | 1.000 |
| Recall@10, queries with labelled positives | 1.000 |
| nDCG@10, Matching grade 2 / Relevant grade 1 | 1.000 |
| Generated holdout rewrites preserving labelled retrieval | 52 / 52 |

These establish regression behavior on a small controlled set. They do **not** establish universal NLP accuracy, independently graded ordering within every same-grade pool, grammatical quality across all English inputs, or personalization. Explicit extra ranking checks verify Christmas date proximity and nature focus. Unsupported/unknown inputs may correctly have no reconstruction or results.

### Actual browser and HTTP verification

Headless Chrome used the real isolated Next frontend, Trip API and PostgreSQL catalogue. Only auth/session was mocked as anonymous; search responses were real. Checks passed for natural phrases, actual Matching/Relevant title groups, explicit alternatives and selection, combined/final empty states, filtering conflicts, edit focus, trailing spaces, keyboard navigation/Escape, IME, URL history, 390px mobile overflow and returning to the existing default page. No runtime page errors occurred. Browser source was search-identical to the final integration; later teammate changes were EV files, then the full suite/type-check/build were repeated on that integration.

Real HTTP/PostgreSQL checks verify public eligibility after cache warm-up/unlisting, changed-catalogue 409, refreshed totals, no-store, natural phrases and rejection of a 257-code-point query. Full existing publication/read/copy/privacy regressions ran on the same disposable datasource. No production database fixtures or authenticated production writes were used.

### Performance

Final integrated full-suite run, real HTTP plus PostgreSQL, five concurrent workers and 25 measured requests per size:

| Seeded publications | Cold | p50 | p95 | p99 |
| --- | --- | --- | --- | --- |
| 1,000 | 540 ms | 179 ms | 225 ms | 228 ms |
| 5,000 | 1,669 ms | 877 ms | 933 ms | 950 ms |

The 1,000-publication target (p95 <=300 ms, p99 <=750 ms, cold <=1.5 s) passed. The 5,000 case demonstrates slower catalogue-scan behavior; it is not a claim that those same latency targets hold at 5,000. A previous less-contended run measured 5,000 p95 388 ms; report the final run above rather than selecting the best sample. These are laptop measurements with development/test logging and concurrent build activity, not VM capacity certification. Browser interaction passed but end-to-end latency percentiles and total process resident-memory deltas were not separately sampled.

## Evidence and release boundary

Local evidence: `output/smart-search-client-integrated.log`, `smart-search-backend-integrated.log`, `smart-search-metrics-final.log`, `smart-search-browser-final.log`, desktop/mobile screenshots, `smart-search-types-final.log`, `smart-search-lint-final.log`, `smart-search-build-integrated.log`. Output files are not committed deliverables.

Fresh whole-branch review identified five important issues (geographic OR, negation, exact dates, revision refetch and pending empty UI). Each was repaired and its affected checks passed before final commits. The scope is Shared Plan search; unrelated planner, Places, community and default-page redesign were not undertaken.

Next step is separate user approval for the concrete VM release. The ordinary dev:vm frontend and VM continue using their existing release until child branches and parent pins are published through the documented release process. Do not describe this revision as live or deploy root main merely to publish these notes.
