# Shared Plan search and yearless publication — 2026-11-03

Status: implemented, released and live-verified on 2026-11-03 after explicit user approval. Root `65a4105`, client `85f2e1f`, server `714bdc9`, Trip `e33812d`. Workflow `41617858398` passed revision checks, PostgreSQL gates, image builds and VM deployment.

Live verification: real API catalogue suggestions, strict Weekend/Christmas relevance, year limitation, country/duration constraints, disjoint pagination, frontend proxy, health 200 and protected anonymous trips 401 passed. Deployed Chrome checks passed for contextual phrases, separate title groups, spaces, keyboard, mobile width and no runtime page errors. Local dev:vm proxy also exposes the new catalogue suggestions. Thailand Christmas currently has no qualifying public matches; unrelated Thai trips are not used to fill it. The chosen live public sample hides dates; visible month/day and copy round trips were verified in the isolated PostgreSQL/HTTP suite, with no authenticated production writes. Evidence: `output/search-yearless-vm-results.json`, `search-yearless-vm-check.log`, `search-yearless-live-browser.log` and live desktop/mobile screenshots.

## Implementation report

- Replaced permissive country-only Related eligibility with required geography, activity and specific-concept evidence. Matching/Relevant remain disjoint and independently paginated. A Thai coastal plan does not qualify for Christmas or food solely because it is in Thailand. Exact phrases rank above weaker evidence; bounded spelling alternatives remain possible.
- Added public temporal interpretation for Christmas, New Year and English months. Christmas-specific public text can establish Matching; December dates alone establish Relevant and nearer December 25 ranks higher. Other requested activity requirements still apply. Public month text can match when private dates were withheld; hidden metadata is never consulted. A searched travel year produces an explicit cannot-verify notice, since published dates no longer carry years.
- Removed the fixed country + itinerary/road trip/weekend trip branch. General prefix vocabulary and real destination completion remain independent of catalogue availability. Full-catalogue suggestions carry actual public support and are checked against the original intent, so a generic plan title cannot replace a specific search and erase its activity. Literal search is a separate button, not a fabricated suggestion.
- Dropdown displays Matching and Relevant titles as separate groups, including genuine empty/loading/unavailable states. Relevant titles/cards can explain public temporal evidence. Retained raw whitespace, caret, newer draft ownership, IME/history behavior, hard country/duration constraints and the unchanged blank landing page.
- Public structured dates are true month/day values; no synthetic year is exposed. Added relative day offsets/span so sparse itineraries and New Year trips copy correctly. Reader labels omit year and weekday. Hidden dates also hide generated date titles. Legacy snapshots are projected at read time without changing their stored record or revoking links; malformed roots/dates remain handled errors.
- Copy dialog requires a chosen year/start date. Leap-day choices are validated; later dates follow the preserved spacing, which the UI explains. Explicit full destination dates are sent even to an older backend, preventing its legacy retain mode from silently choosing the original year. Bodyless requests are rejected by the new backend before creating a trip.
- No migrations, new infrastructure, paid API, dependencies, global auth/proxy changes, or unrelated Places/planner/sidebar/profile edits. Private planner dates and source content remain unchanged.

## Test results

### Automated frontend

- Full suite: **650 passed, zero failed, zero skipped**.
- TypeScript passed using a temporary copy of the committed tsconfig, excluding the locally generated tsconfig changes from the proof.
- Scoped ESLint passed. Final isolated production build passed.
- New regressions were observed failing before fixes: event completion/template removal, country-only fallback, phrase intent loss, yearless date labels/leap-year validation and explicit copy payload compatibility.

### Automated backend and database

- Final full suite: **371 total, zero failures, zero errors, three skipped** (368 executed).
- Final run explicitly points all Spring contexts at disposable PostgreSQL 16/PostGIS on loopback port 56432, with service discovery, configuration bus/stream and outbox delivery disabled. Flyway/schema validation, public JSONB search and real HTTP publish -> view -> copy -> planner reload passed.
- Three pre-existing skipped tests are MyListAppendPersistenceTests concurrency/stale-snapshot cases: `competingSnapshotAndAppendSerializeWithoutDeadlock`, `simultaneousDuplicateClicksCreateExactlyOneItemAndOneRevision`, `oldWholeSnapshotCannotEraseAppendedPlace`. They were not counted as passed or represented as exercised.
- Checked positive and negative Christmas/date cases, wrong geography, specific sushi vs generic food, unknown terms, explicit year limitation, hidden dates, speculative owner questions, month-title evidence, bounded typo behavior, duplicate-free result windows and hard filters.
- Verified old/new month/day serialization, no structured year/weekday leakage, hidden generated titles even without date fields, malformed snapshots, leap-day validation, sparse/New Year spacing, explicit missing-date rejection before writes, and preserved selected introduction/My List/Garage/notes/checklists/budget through copy/reload.
- Review found four Important defects and one follow-up speculative-question defect; all received regression fixes and passed final verification. Review-only work did not edit the implementation.

### Browser and scale checks

- Chrome on the actual Explore route: simultaneous Matching/Relevant groups, evidence label, contextual completion, literal search action, keyboard/Escape, raw trailing/repeated spaces, caret insertion, late-response race, honest no-match states, year limitation, IME, history, mobile overflow and blank landing passed with no page runtime errors.
- Browser search responses were controlled fixtures; backend behavior was separately tested against real PostgreSQL/HTTP. No authenticated production copy/save operation was performed. The temporary QA frontend's certificate setup was corrected before the final browser run.
- A 1,000-public-plan in-memory catalogue fixture returned accurate totals, 12-card result windows and four-title suggestions. Three local requests took **199 / 131 / 130 ms** in the dedicated measurement. This excludes network/database cost and concurrent load; it is not a production latency claim. Search still streams the eligible catalogue, so large-scale production indexing remains a measurement-driven decision.

### Environment note

Early full-suite runs set the NAVIO_TEST_DB variables, but some existing SpringBootTest classes still used their configured local development datasource. Those runs may have left generated test records in that local database. The final run corrected this with explicit SPRING_DATASOURCE overrides for every context. No VM data was changed; no broad local-data cleanup was attempted because it could remove existing records. Owned temporary QA processes and the disposable database are cleaned up at session end.

Local evidence (not committed): `output/plan-relevance-client-final.log`, `plan-relevance-backend-final-isolated.log`, `plan-relevance-build-final.log`, `plan-relevance-browser-final.log`, `plan-relevance-catalogue-load.log`, and desktop/mobile screenshots.

## Delivery limits

The VM and dev:vm proxy now use this revision. The frontend accepts legacy responses and sends explicit copy dates. Older cached clients may fall back to Day N for the new month/day format; refresh to load the released frontend. They must not be given a fabricated original year to mask that limitation.

Relevant vocabulary and fixed-event rules are bounded and primarily English. Movable/local holidays and arbitrary semantic intent are not claimed to be fully understood. Empty or sparse results are preferred over unsupported recommendations. The reported counts and regression outcomes do not imply a measured universal 90% search accuracy.
