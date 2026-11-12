# Guide discovery and catalogue search

Live on the VM from root release 2d9db5c (2026-11-12), verified by deployment run 43186986279. The existing Guide editor, reader document format, author feeds and saving contracts remain compatible.

## Published catalogue

`GET /v1/traveler-guides/discovery` (anonymous or authenticated)

| Parameter | Accepted values |
|---|---|
| term | Optional text, maximum 200 characters |
| country | ISO alpha-2 country or empty |
| time | any; month:1 through month:12; season:spring/summer/autumn/winter/wet/dry |
| collections | Comma-separated trending,popular,seasonal,scenic,food,sweets,relax,night,nature |
| interests | Comma-separated architecture,museums,street-food,hiking,beaches,shopping |
| sort | Ordered priorities relevance,trending,popular,views,recent,updated |
| page / size | Zero-based page; size 1 through 24 |

Choices within Collections or Interests match any selected choice. Different facets work together. Sorting never bypasses eligibility. Recommended is the UI default when no explicit priorities are selected; later priorities break ties before stable publication/name/source/id fallbacks. Popularity is lifetime recorded views; Trending uses the recent 30-day view aggregate. Ratings, reviews, copies and itinerary dates are not Guide discovery metrics.

Response: `content`, `matching`, `relevant`, `matchingTotal`, `relevantTotal`, `totalElements`, `number`, `last`, `suggestions`, `notice`. Matching and Relevant paginate separately using the same page/size; last is true only when both are exhausted. Clients deduplicate by source plus UUID, not UUID alone. Entry fields extend the existing public guide summary with source CURATED/TRAVELER, viewCount, discoveryLabel and collections. Curated reader links use `?source=curated`; saved references retain CURATED.

Only published records enter discovery. Curated and traveler rows share server sorting/pagination rather than concatenating separately fetched first pages. Legacy absent publication timestamps are accepted by the client; they are not displayed on discovery cards.

## Search evidence

Title matches rank ahead of incidental body mentions. Synonyms and bounded prefix/typo matching use internal vocabulary and the published catalogue. Recognized country/destination, season and named-event constraints remain enforced for Relevant results. Dessert and desert are distinct. Suggested searches use eligible published titles or grounded destination/topic phrases; they are search actions, not fabricated publication titles. Plans and Guides search independently and use separate URL keys. Places search is unchanged.

Evidence comes from authored title/description/document and places actually referenced by that document. Unused embedded place records are not indexed. A venue name alone does not establish a holiday/event guide. Collection focus uses authored heading/title/description or a significant share of referenced places; a lone incidental restaurant in a broad city guide does not automatically establish food focus.

## Seasonal eligibility

Positive authored month/season references establish evidence; publication dates never establish travel suitability. Explicit four-season evidence is mapped to meteorological months only for temperate destination latitudes, respecting hemisphere. Tropical wet/dry timing is not invented. General rows retain unknown suitability with a notice; clearly conflicting known suitability is excluded. The Seasonal collection requires supporting evidence and uses the current UTC month when Any time is selected. This is authored discovery guidance, not verified climate or a weather forecast.

Trending retains eligible popular/recent fallback tiers if activity is sparse. Each card is labelled according to its actual recorded attention; no historical views are fabricated. Country, time, interests and text constraints continue to apply.

## Reading events

`POST /v1/traveler-guides/discovery/{CURATED|TRAVELER}/{uuid}/view` validates current publication, then records at most one view per actor/source/id/UTC date. An authenticated subject takes precedence over a visitor ID. Anonymous requests require `{visitorId: UUID}`. The Next proxy generates a first-party HttpOnly, SameSite=Lax visitor cookie and supplies that value instead of trusting the browser body. Cross-origin writes and invalid source/UUID paths are rejected by the proxy.

Dedup and daily budgets use stable SHA-256 keys, with no raw account IDs or network addresses stored. Limits are 100 distinct views per viewer/day and 10,000 per network/day; proxied traffic can share a network budget. Daily aggregates persist for lifetime ranking; recent ranking includes today and the previous 29 UTC dates. Old dedup/budget rows are cleaned during accepted view writes. The client records only a mounted reader's first visible state, including a background tab activated later; cards/prefetching do not record reads.

Storage is additive IAM V14: guide_daily_views, guide_view_dedup, guide_view_budgets. Previous releases can run with these extra tables. No provider, map, geocoding, photo or runtime AI requests are made by discovery classification/search.

## Operational boundaries

Current discovery reads each published source once per request and classifies it in process without truncation. Shelves load near the viewport; pagination is server-owned. If catalogue scale grows substantially, an indexed publication projection is the next optimization, not browser filtering or silent catalogue limits. Existing cover-photo retrieval remains under the existing provider safeguards and cache; development verification uses offline fixtures only.
