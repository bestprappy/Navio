# Shared Plan discovery and Saved Guides

Status: proposed implementation design; read-only builder review completed, awaiting user design approval. No product code changed.

## Authorized scope

The user approved finishing the remaining features after Shared Plan feedback went live. This includes the requested Shared Plan default sections and functional sorting/filtering, and Saved Guides. The user subsequently explicitly paused custom categories. Custom Cover remains on hold. Neither held feature is part of this revision.

Existing ratings, comments/replies/moderation, sharing, plan/place bookmarks, source links and smart search remain the foundation. Do not replace them. No Places editorial feature, planner redesign, unrelated Community/Admin change, or new guide-writing feature.

## Inspected baseline

- Deployed root `0e341ac`, client `45e42e8`, server `b11f808`, Trip `dfe950d`.
- Explore currently renders Trending and Recent through SharedPlansSection; six trending cards and pagination already exist.
- Trending currently orders lifetime views, so its name overstates recency.
- Plan search has country, duration, live suggestions, Matching/Relevant/Alternatives and three sort values. Interests is a disabled preview.
- Rating average/count and comment count are now real publication aggregates.
- Published dates expose month/day only. Existing smart search deliberately rejects unsupported seasonal inference.
- Saved has Recents/All/Plans/Guides/Places/Recently Deleted; Guides is deferred. The library currently supports PLAN/PLACE, a 50-plan limit, unlimited places, seven-day trash, recent opens, search and pagination.
- Both public traveler guides and existing curated destination guides exist in IAM. Their identifiers and visibility rules must be resolved using existing guide services, not arbitrary client metadata.
- Existing client tsconfig changes, local files, service logs and the running dev:vm process must be preserved.

## Approach

Recommended: extend the current Trip publication/search services and IAM Saved library, with the existing card, bookmark, popover, guide cover, query/cache and authentication components. Keep collection eligibility separate from sorting and apply both before pagination. This avoids inconsistent frontend-only filtering.

Rejected: replace search with a separate engine/provider. This adds infrastructure and duplicates the working intent engine without solving the current collection/evidence gaps.

Rejected: download the current feed and filter/sort it in the browser. This cannot correctly rank or count the full catalogue and would omit eligible plans outside loaded pages.

## 1. Shared Plan landing page

Order: Trending plans, Recent plans, All-time popular plans, Seasonal trips, Event trips.

Reuse the existing responsive SharedPlanCard grid and section loading/retry/load-more patterns. Initial pages show six cards where six eligible plans exist; never manufacture cards or fill seasonal/event collections with unrelated plans. Each collection has independent pagination, totals and error/retry state. The same plan may legitimately appear in different named collections; do not repeat a token inside one collection/page sequence.

Use short section descriptions to explain the basis of selection. No extra hero, large ornamental panels, or changes to the reader/planner. Keep existing light/dark tokens, keyboard focus, mobile layout and stable card sizes.

Recent uses the publication's existing listing timestamp, not trip travel dates. All-time popular uses recorded successful copies first, lifetime views second, with deterministic timestamp/token tie-breaks. Keep this ordering explicit in helper text rather than calling the metric unique travelers.

Trending requires new daily publication activity aggregates. Proposed initial formula: today UTC plus the preceding six UTC dates, sum of views plus three times successful copies. Only tracked activity counts; no fabricated backfill from lifetime counters. Use the existing validated view/copy event paths; no new IP, identity, browsing-history or visitor tracking. Update lifetime and daily counters transactionally. Retain existing anti-duplicate behavior; do not describe requests as unique visitors. New plans without activity do not become trending solely from publication recency. During the initial measurement period show a compact honest empty state if necessary; Recent remains useful.

## 2. Seasonal and event eligibility

Clock and calendar are injected/testable, using UTC for collection rollover. Published private years are never read or inferred. Month/day evidence is recurring inspiration, not a claim that the author will travel this year.

Seasonal collection:

- Prefer reusable, verified destination seasonal profiles where they are available through existing Places infrastructure. Do not add cross-service database reads or a network request per card.
- Otherwise use public trip month/day overlap with the current month as calendar evidence and label it "For this time of year" / "Shared travel dates in November", for example. This is not a weather-suitability claim.
- Explicit seasonal/activity evidence can improve ordering only when it agrees with the public destination/time evidence. Do not apply northern-hemisphere winter to every country, assign an entire large country one climate, or infer dry/wet conditions without a regional profile.
- Unknown dates and unsupported climate claims do not qualify by default. Show the reason used on cards/section helper text without adding implementation jargon.

Event collection:

- Use a small versioned event registry with stable ID, names/aliases, geographic applicability, calendar definition and bounded discovery window. Initially cover Christmas, New Year and Easter as requested; any additional regional event needs an explicit definition.
- Proposed discovery window: the event is ongoing or starts within the next 45 days. Correctly handle December/January rollover. Western and Orthodox Easter must be distinct; an unlabeled generic Easter initially means Western Easter, stated in collection context. Do not infer a local holiday closure or celebration from a date alone.
- Strong qualification requires an explicit public event/theme mention and compatible public date evidence where dates were shared. Generic December dates alone do not establish a Christmas-themed trip.
- Preserve the existing search distinction: a calendar-related plan can be Relevant with a reason in search, without being promoted as an event plan in this collection.
- Rank eligible event plans by genuine recent activity, then event proximity and deterministic tie-breaks. A missing qualifying catalogue produces a useful empty state, not unrelated coastal plans.

Calendar edge cases: compare only the actual public month/day evidence; preserve December/January as a circular calendar and never reconstruct an owner's hidden year. An explicit event mention without any shared dates may qualify as an event-themed plan, with no claim about its travel timing. When dates were shared, require at least one compatible public day; contrary dates exclude it. Easter compatibility uses the registry's current occurrence, not a guessed historic travel year. February 29 remains a valid public month/day for February inspiration, but is not shifted to another date or turned into a current-year event in a non-leap year. If dates were omitted by the publisher, do not recover them from the private source trip.

## 3. Filters and sorting

Keep Country on the left, Search shared plans, Filters, then Trip duration. Rename the external Interests label to Filters. Inside the popover, show Sort by first, Collections next, then only useful supported travel-theme filters.

Sort choices:

- Recommended/relevance: current search ranking when a query exists; default collection ordering otherwise.
- Newest shared: listing timestamp descending.
- Trending: recent activity score.
- Most copied: lifetime successful copies.
- Most viewed: lifetime views.
- Highest rated: average descending, rating count descending; unrated plans last. Clearly show sample counts; do not fake a score or mix comments into stars.
- Most discussed: count of visible active comments descending. Use this label instead of "Review" because the current feature is comments plus ratings, not a distinct written-review system.

"All time" is the All-time popular collection/time basis, not an ambiguous duplicate sort. Keep one source of truth if a compact results sort control also remains.

The selectable Collections are Seasonal and Events, with multiple choices allowed. Trending, Recent and All-time popular are default discovery sections and sorting bases, not restrictive collection checkboxes: giving Recent/All-time universal membership would neutralize the Seasonal/Event filter. With no query, country/duration and collection selections keep the collection presentation and show only selected sections. A sort-only change reorders eligible cards within the sections; it does not remove collection membership. Country/duration constrain every section.

With a query, retain Matching/Relevant/Alternatives and the existing no-results hierarchy. Collection and theme filters constrain every bucket, including alternatives; do not silently relax them. Sorting changes ordering within a bucket, never promotes an irrelevant plan into Matching.

Selecting Seasonal and Events uses an OR of their exact landing-page eligibility rules, not a new broader search interpretation. Destination/duration/theme groups still intersect this predicate.

Same-dimension choices are OR, different dimensions are AND. The popover uses draft selections with Apply and Reset so multiple selections do not cause repeated network churn. Country and duration retain their existing live/debounced behavior. Show applied filter chips/counts and an accessible Clear all action. URL state restores through refresh/back/forward and request cancellation prevents stale responses replacing current results. Changing criteria resets pagination.

Theme choices are limited to existing well-supported travel concepts: Nature & scenery, Food, Culture, EV trips and City exploration, subject to verifying evidence coverage. Reuse the concept/evidence parser; no unverified accessibility, accommodation-quality or safety tags. Unknown/unsupported facets are not exposed as working controls. An extra free-form keyword input would duplicate the search bar and is not proposed.

Do not alter smart autocomplete suggestion semantics, whitespace preservation, IME support, public-year privacy or existing plan copy/publication data.

## 4. Saved Guides

Enable saving publicly available guides from their discovery cards and reading page, reusing the highlighted icon-only SaveButton and sign-in handling. No nested interactive button inside an anchor; refactor the card composition while preserving its navigation and visual layout.

Use a canonical guide identity with a source namespace if curated/traveler IDs can overlap. The server resolves current published visibility/title/destination/author/cover through existing guide services. A bookmark is a reference, not a copy of the guide/editor document. Private drafts and unpublished/deleted guides cannot be newly saved or opened as public content.

Saved Guides joins Recents, All, Guides, recently opened, search, sort, pagination and seven-day trash/restore. Keep 50 active plans and 50 active guides as independent limits; places remain unlimited. Removal frees a slot. Restore checks the relevant limit under the existing user lock. Duplicate saves are idempotent and do not consume extra slots. Preserve plan/place source-link behavior and existing favorite-place synchronization.

If a saved guide later becomes unavailable, retain the user's bookmark and display Unavailable with removal/restoration controls. Never reveal draft content through cached metadata or fall back to an editor URL. Opening navigates to the existing public reader and tracks recent opens only after access validation.

Compatibility constraint: simply adding GUIDE to saved_library_items would make older clients fail their PLAN/PLACE-only response parser after rollback. Prefer an additive guide-bookmark companion table with shared library projections/lifecycle helpers and a UNION query for new mixed listings, so the previous released backend does not read unknown content types. Do not rewrite V10 or existing place-sync triggers. Explicitly test old-backend operation against the migrated database and new guide rows. Use server-generated metadata only; no client-supplied public author/title authority.

Client coexistence also requires an explicit guide-inclusive request version/opt-in: legacy list requests continue returning only PLAN/PLACE and their original counts. New clients request guide-inclusive library listings and parse GUIDE. A new backend must never send GUIDE to an old/open client using the old request contract. Test old-client/new-backend and old-backend/new-schema separately; the companion table alone only solves the latter. Unsupported guide capability on an old server shows a retryable unavailable state, not falsely successful bookmarks.

Custom categories remain disabled/Later; do not create a collection API, migration or UI in this phase.

## 5. Verification and release

- Discovery tests: all sort modes, totals, stable ties, pagination, activity window boundaries, copy success/failure, zero activity, no invented historical trend, eligibility before paging, independent section errors.
- Calendar tests: UTC midnight, December/January, leap day, Easter dates, country/region mismatch, unknown public dates, contrary dates, no private year leakage, no climate claim from generic month evidence.
- Search regression: Matching/Relevant/Alternatives, country/duration/theme/collection intersections, empty and conflicting filters, no implicit relaxation, typing spaces/IME, cancellation and URL navigation.
- Saved Guides: guest/auth, ownership for every action, invalid/private/unpublished guides, duplicate/concurrent saves, 50-item limit, trash expiry, restoration/full quota, unavailable references, recent opens and mixed-type pagination/search.
- Database: fresh migrations, upgrade with real existing records, Hibernate validation on real disposable PostgreSQL, rollback compatibility; no shared/personal database.
- Frontend: meaningful model/contract tests, TypeScript, touched lint, production build, actual browser checks in both themes and mobile, keyboard/focus/no-overflow, real integrated API rather than mocked success only.
- Existing Save, copy, ratings and comment caches must invalidate affected discovery/library queries appropriately.
- Update API/database/handoff/session docs; commit owned work only through isolated branches/worktrees. Preserve unrelated teammate/local work.
- Implementation approval does not itself authorize a new root-main deployment. Complete and verify the revision first, then request release approval with concrete revisions as required by docs/agents/release.md. The user's prior approval was for the already-live feedback release.

## References consulted

- Nielsen Norman Group, Helpful Filter Categories and Values for Better UX: https://www.nngroup.com/articles/filter-categories-values/
- Nielsen Norman Group, User Intent Affects Filter Design: https://www.nngroup.com/articles/applying-filters/
- Algolia, How we improved the search algorithm (relevance and popularity): https://www.algolia.com/blog/product/unveiling-the-search-algorithm-how-algolia-improved-search

These inform clear facets, batching multi-selection and separating relevance from popularity. No external search service or new UI framework is proposed.

## Builder review outcome

The read-only review caught the old-client/new-server GUIDE parser incompatibility; the explicit opt-in contract above resolves it. It also clarified selectable collection membership, precise UTC activity windows and recurring-date/event semantics. No additional user-specific product decision was left unresolved by the review. Numerical ranking/window choices above remain proposals for this design approval, not claims of earlier user agreement.
