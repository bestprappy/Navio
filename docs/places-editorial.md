> **DEFERRED / DISABLED / EXCLUDE_FROM_REPORT - PLACES_EDITORIAL (2026-10-22).**
> Saved experiment and future reference only. Code and integration are commented out; the previous reader behavior is restored. Historical implemented/completed statements below are not current product claims. See [deferral and report-scope instructions](/docs/deferred/places-editorial.md). Do not resume or include in reports without the corresponding explicit user request.

# Places editorial catalog

Articles are prepared original editorial entries, not generated during a visit. Popularity, Google review counts and star ratings do not determine eligibility. A little-known documented place can qualify; a famous place with insufficient evidence cannot.

## Add or revise an article
1. Confirm the exact provider place identity and inspect official operator/institution records directly. Do not copy or rewrite Google Maps summaries or reviews, scrape the Maps UI, or save provider photos/reviews into this catalog.
2. Research independent source families including at least one authoritative operator, institution or government source. Separate URLs on one publisher are one family. Confirm important facts against independent evidence; publisher count alone does not prove accuracy. Avoid unresolved disputed figures. Wikipedia can identify primary references but is not the sole evidence.
3. Write original passages in client/app/feature/explore/places/place-articles.data.ts, with sourceIds on every passage. These are internal evidence links; readers see a compact source footer rather than academic inline citations. Do not quote source paragraphs. Retain only original prose and source metadata, respecting access and reuse conditions; source access is not permission to copy their expression or images.
4. Use draft until the place identity, statements, sources, two or more concrete supported experiences, context and article quality have been checked. Review each factual sentence against its cited source(s). Do not publish unsupported seasonal advice, medical/health benefits, accessibility promises, guaranteed access or review consensus.
5. Target 350-450 words with meaningful shorter articles accepted from250; hard cap500 including title/headings. Do not pad to meet count. articleWordCount and articleIssues expose machine-checkable constraints; they cannot verify source authority, independence or factual truth automatically. Researcher judgment remains necessary.
6. Set version, locale, status, reviewedOn and reviewDueOn. Review all experience recommendations at least every90 days (background at least every180); the initial entries use the stricter90-day due date for the whole article. Recheck source checkedOn dates before renewing, never just extend dates automatically. Mark needs-review or withdrawn on unresolved changes. Keep transient hours/prices in live practical details, not article prose.
7. Run article/reader tests, TypeScript and scoped lint. Preview desktop/mobile light/dark, disclosure keyboard behavior, credits and missing photos in a browser before claiming visual acceptance.

## Reader behavior
Only published, identity-matched, source-referenced, in-budget and unexpired entries render. Missing, stale, draft or closed-place entries omit the section without filler or an empty placeholder. A midnight timer and visibility/focus recheck expire open readers on the editorial Bangkok calendar without research/API requests. The browser cannot independently discover a changed fact; operator updates still require editorial maintenance.

Every article has a visible opening, Read the story / Show less disclosure, approximate reading time, full source links and source-check date. Google descriptions never override or feed the original article. Google photos stay live and distinctly credited. One lower provider logo serves place details/photos; photo author/source credits and existing gallery/map attributions are retained. No new backend schema, Admin authoring UI, runtime LLM or automatic worldwide crawler.

## Initial coverage and research notes
- Tuileries Garden: Louvre garden history/layout plus Paris tourism office visitor information.
- Grand Palace: Bureau of the Royal Household official history/Emerald Buddha material plus Tourism Authority of Thailand. Ceremonial purpose does not imply all areas are open; avoid historical or outdated notices as current operating advice.
- Wat Pho: temple documentation of reclining Buddha and four great chedis plus UNESCO Memory of the World. Temple and UNESCO sources give different inscription totals; omit the number rather than silently choose one. UNESCO Memory of the World listing is not a World Heritage Site designation.

Initial source checks:2026-10-22; next review due2027-01-20. The three entries are starting coverage, not a claim of worldwide articles. All source URLs and publisher identities are stored beside the passages.
