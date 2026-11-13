# Guides discovery and catalogue-led search implementation

Implemented, verified and released with explicit approval on 2026-11-12. Root main 2d9db5c; deployment 43186986279 succeeded, with twelve read-only live checks passing.

Approved 2026-11-12. Plans and Guides remain separate; Places unchanged. Remove Desert escapes. Guide cards follow Shared Plan card surfaces/alignment with larger cover prominence, no copies or itinerary dates. Reuse Plan priority sorting control adapted to supported Guide metrics. Existing editor/reader behavior retained.

## Contract
GET /v1/traveler-guides/discovery: term(max200), country(ISO2 or empty), time(any|month:1..12|season:spring/summer/autumn/winter/wet/dry), collections(comma-separated trending,popular,seasonal,scenic,food,sweets,relax,night,nature), interests(comma-separated architecture,museums,street-food,hiking,beaches,shopping), sort(comma priorities relevance,trending,popular,views,recent,updated), page>=0,size1..24. Public published-only unified curated+traveler catalogue.
Response {content:Entry[],matching:Entry[],relevant:Entry[],matchingTotal:number,relevantTotal:number,totalElements:number,number:number,last:boolean,suggestions:string[],notice:string|null}. Entry extends existing PublishedGuideSummary with source:TRAVELER|CURATED, viewCount:number, discoveryLabel?:trending|popular|recent, collections:string[]. Source-qualified identity. Existing detail reader uses source query for curated.
GET discovery counts all eligible publications, stable server pagination separately matching and relevant; no partial browser catalogue. Suggestions grounded in eligible published catalogue, no invented plan/guide titles. Unknown time suitability neutral for general rows with notice, excluded seasonal row. No new rating/review feature or unsupported sort. Trending real 30day attention, honest popular/recent fallback.
POST /v1/traveler-guides/discovery/{source}/{id}/view optional authenticated/anonymous bounded deduped view recording; must validate publication and use internal evidence only. Do not alter existing GET reader semantics; separate client reader effect records visit.

## Tasks
1. IAM discovery backend and additive engagement storage: published source-unified feed, themes/time, sorting, pagination, grounded suggestions; TDD and real PG schema validation.
2. Trip search: simplify matching/relevance/suggestions to catalogue evidence while preserving all filters, sorting, privacy, durations, pagination. No generative Google imitation. Tests short prefixes/aliases/typos/geography/topic conflicts.
3. Frontend: reusable catalogue autocomplete; Guides controls/discovery sections and visual cards, independent URL state; reuse sorting and country controls without editing Places. Wire new backend and reader view event.
4. Verification: full client/backend suites, types/lint/build, offline browser fixtures (no paid APIs), review integration and update API/database/session docs. Integrate feature branches into dev only when verified. VM release requires explicit approval, do not deploy as part of implementation.

## Constraints
No Google/Mapbox/provider calls for development testing. Never overwrite active user tsconfig or other-session notes. Preserve published identities, saved references, authored content and source. Reuse existing account/auth/publication security. Existing custom cover/categories and editorial exclusions unchanged.
