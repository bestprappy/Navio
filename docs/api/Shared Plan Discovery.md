# Shared Plan discovery

Implementation: 2026-11-05; LIVE on VM and verified in dev:vm after root e1aea7d (2026-11-06). Extends the existing public shared-plan search endpoint and frontend proxy; no new gateway route or external search provider.

## Request and membership

Existing query, country, duration, revision and pagination parameters remain supported. `sort` accepts `relevance`, `recent`, `trending`, `popular`, `views`, `rating`, `discussed`. `collections` accepts comma-separated `seasonal` and `events`; the landing Trending query uses the internal `trending` collection. `themes` accepts `nature`, `food`, `culture`, `ev`. Unsupported values are rejected. The UI never mixes the internal Trending collection with selected collections.

Collections are OR selections; themes are OR selections; collection, theme, country, duration and search intent dimensions are combined with AND. Eligibility is applied before ranking, suggestion support, counts and pagination, including all search result buckets. Nature includes strong nature or scenic evidence. No unsupported City filter is exposed.

Country/duration selections alone retain the discovery layout. A search query or travel theme uses Matching, Relevant and Alternatives results. Collection-only selection restricts discovery sections. Each section starts with six plans and loads more independently; empty collections do not substitute unrelated plans.

## Ranking and evidence

- Trending: actual daily views plus three times successful copy events, from the current UTC date and previous six dates. Only positive-activity plans enter Trending. There is no fabricated historical backfill or visitor identity collection.
- Recent: publication listing time. Popular: lifetime successful copies, then views. Views: lifetime views. Rating: real average, then rating count, with unrated last. Most discussed: visible comment count. Stable listing/token ties support deterministic paging.
- Seasonal: currently uses public shared month/day dates overlapping the current month. This is a calendar fallback, not a climate or weather suitability claim. Hidden years are not read or exposed for eligibility.
- Events: current registry supports Christmas, New Year and Gregorian Western Easter. Discovery begins up to 45 days before an occurrence and includes its active period. Affirmative owner event text is required; shared dates, when present, must also agree with the event window. Undated explicitly themed plans may qualify. Orthodox Easter is not silently classified as Western Easter. New Year rollover and leap dates are handled. Among otherwise tied event plans, shared travel dates closer to the event date rank ahead; this is travel-date alignment, not a forecast or inferred private year.

Changing mutable ranking statistics or relevant calendar/filter state changes the catalogue revision. The frontend recovers from a stale-revision 409 by resetting that exact collection query, preserving criteria and announcing the refresh. It does not append stale pages or retry the same obsolete revision indefinitely.

## Storage

Trip V28 adds publication daily activity aggregates. View recording participates in existing listed-publication reads. Copy recording occurs only after a newly inserted successful copy event; idempotent replay does not increment activity again. Existing lifetime counters and smart-search intent rules remain in place.


## Calendar extension (LIVE, 2026-11-06)

Released root 027fabc / Trip 044e0bd adds Halloween (October 31, seven days before/two after), Chinese/Lunar New Year (seven before/fourteen after), and Loy/Loi Krathong (three before/two after). Existing 45-day discovery lead-in and affirmative owner-text/date evidence remain. Chinese/Lunar New Year is excluded from Gregorian New Year recognition, including search intent parsing.

Chinese New Year dates are verified from the Hong Kong Observatory Gregorian/lunar tables for 2026-2030 (February 17, February 6, January 26, February 13, February 3 respectively). Loy Krathong is verified for November 24, 2026 only through Chiang Mai provincial tourism/Thai government sources. Unknown-year lunar occurrences are omitted rather than guessed. Extend official calendar coverage before those bounds expire. Source links: https://www.hko.gov.hk/en/gts/time/calendar/pdf/files/2027e.pdf and corresponding year tables; https://chiangmai.mots.go.th/news/6839 ; https://www.thailand.go.th/events . The expanded registry is live after successful workflow42181062252.
