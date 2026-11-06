# Seasonal and event sample plans

> Execute inline using superpowers:executing-plans; preserve existing samples and user work.

**Goal:** Publish 15 additional complete Navio Team plans and extend evidence-qualified Events recognition, as requested and explicitly approved by the user.
**Architecture:** Reuse seed-explore APIs and completeSample. New manifest supplies per-plan dates, published month/day dates, varied introductions and official source links. No direct database insertion, no arbitrary event tags or fake views/ratings, no overwrite of existing travelers. Expand the small event calendar, retaining its existing upcoming-window and public-evidence gates.
**Tech stack:** Existing Node maintenance tooling and Java Trip discovery; no new dependency/schema.

## Decisions

- Seven seasonal plans: Kyoto/Amsterdam spring; Bled/Lucerne summer; Kyoto/Seoul autumn; Sapporo winter.
- Eight event plans: Edinburgh Halloween; Vienna/Strasbourg Christmas; Bangkok EV/Sydney New Year; Singapore/Hong Kong Chinese New Year; Chiang Mai Loy Krathong. Destinations/durations differ; optional activities and schedules are not promises of admission or seasonal conditions.
- Chinese New Year uses official HKO calendar dates for 2026-2030; no guessed fixed month/day. Loy Krathong initially only verified 2026 date (Thai government and Chiang Mai provincial tourism); omit unknown future occurrences. Fixed Halloween uses October31. Do not confuse Lunar New Year with Gregorian New Year.
- All 15 are actual maintained public records, not previews. They rotate with the current month/event period; no forced visibility outside eligibility. Loy Krathong provides a genuinely upcoming November event. EV Garage is only in the Thai route; other plans stay non-EV.
- Source/auth: existing dedicated Team owner via already-authenticated VM terminal/private Docker network. No SSH/password/access-setting changes. Dry-run, then canary, then rest; verify published sections/map locations and stable idempotent rerun.
- Existing seed defaults remain unchanged. New manifest/batch is explicit; per-plan dates override rolling defaults only for these definitions. No rewrite of merged migrations or unrelated application UI.

## Tasks

- [x] RED/GREEN: Trip tests for Halloween windows, Lunar-vs-Gregorian separation, official varying dates, unknown-year omission and Loy eligibility. Extend calendar and update its accurate UI description.
- [x] RED/GREEN: maintenance runner tests for explicit batch selection/per-plan dates/date publication/full sections/idempotence. Add 15 researched definitions and reuse completeSample with optional original introduction.
- [x] Verify focused/full regressions; real PostgreSQL startup if service source changes require release. Fresh whole-branch review.
- [ ] VM dry-run validates provider locations; publish canary and remaining records using existing private service APIs. Compare baseline public titles/tokens and verify15 additions only, no artificial metrics.
- [ ] Document result, source links and calendar limitations. Request release approval only for the concrete verified event-recognition code update; sample creation itself is authorized.

## Sources

- HKO Gregorian/lunar calendars: https://www.hko.gov.hk/en/gts/time/calendar/pdf/files/2027e.pdf (and 2026/2028/2029/2030).
- Hong Kong 2027 general holidays: https://www.info.gov.hk/gia/general/202605/15/P2026051400300.htm
- Chiang Mai tourism November24-25,2026: https://chiangmai.mots.go.th/news/6839
- Thai government Loy Krathong calendar: https://www.thailand.go.th/events
- Official destination material consulted: japan.travel Kyoto; iamsterdam.com spring; bled.si Lake Bled; luzern.com winter; visitscotland.com Halloween; wien.info Christmas; noel.strasbourg.eu; visitsingapore.com Chinese New Year; sydneynewyearseve.com guide.


## Execution record

- Root maintenance revisionsd762bc0/0ff9c15 pushed on feature branch; Trip044e0bd and client9181607 pushed on their feature branches. No deployment/main push.
- Final checks: maintenance15pass; Trip655 tests,0failure/0error,5existing skips with disposable realPostgres; frontend698pass, TypeScript and scopedESLint exit0.
- Fresh read-only whole-branch review found two Important issues. Both repaired RED?GREEN: incomplete existing maintained publications now fail closed instead of falsely counting as skipped; required EV charger lookup failure prevents creation. Full maintenance suite15/15. Recovery intentionally requires owner-side inspection rather than automatically publishing potentially revoked content. Cost: manual recovery for an interrupted draft; benefit: no unintended overwrites/republication.
- Live provider identity/locations and publication/copy review remain pending, not inferred from mock tests. Independent source research documented above. Existing live schema unchanged; fullPostgres-backed regression check passed, releaseCI still required before deployment.
- VM dry run reached Google Places but all15 lookups failed: upstream403 PERMISSION_DENIED (caller lacks permission), Mobility503. Tally published0/dry-run0/failed15. No canary or apply run attempted. Application services/configuration unchanged. Temporary container file-permission issue corrected by running only that disposable maintenance container asroot.
- Original31 public records preservation check recorded in output/seasonal-preservation.json. Do not re-create definitions or re-run code implementation; next resolve provider access, repeat dryrun, canary, remainder, full15snapshot checks, and calendar deployment approval.


Calendar code release approved and deployed: root027fabc, client9181607, servera20859f, Trip044e0bd; workflow42181062252 successful. Actual VM/dev:vm discovery API, filters, five headings, mobile and runtime-error checks passed; existing31 plans preserved and health200. No sample records created; Google Places access is still a separate blocker. Release is complete; do not repeat it.
