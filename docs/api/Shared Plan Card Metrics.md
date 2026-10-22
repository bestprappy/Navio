# Shared Plan card metrics and covers

Implemented locally on 2026-10-22 in client and trip-planning-service; not deployed by this task. These fields supplement the existing publication contract.

## Explore summaries

`GET /v1/shared-plans` includes `viewCount`, `copyCount`, and nullable `coverPlaceId` per plan. Existing cover image and summary fields remain compatible. Counts are nonnegative integers. The client displays unavailable counts when an older backend omits them, rather than inventing zero.

- Views retain the existing public-read counter, not unique visitors. Card links disable prefetch to avoid speculative public reads.
- Copies count every successful import, including repeated imports by one traveler. They do not mean completed trips.
- `coverPlaceId` identifies a public stop in the published snapshot. A stored cover is preferred; missing/broken covers can use the existing Places reader endpoint for that stop. Photo requests are lazy, bounded and attributed. Unavailable photos show a neutral destination fallback, never an unrelated stock photo.
- Rating is deliberately `Not rated yet`; no rating submission or fabricated average is implemented.

Trending requests six plans per page on both server and client. Load more appends another page. Fewer than six eligible plans cannot be supplemented with invented plans.

## Listed detail

Listed shared-plan responses add `engagement: { viewCount, copyCount, uniqueCopierCount }`. The client displays both total copies and distinct travelers on detail pages. Only aggregates are public; copier identities are never returned. Unlisted links omit engagement, preserving their existing sharing behavior.

## Persistence and deployment

Migration `V21__shared_plan_copy_events.sql` adds `trip.shared_plan_copy`. A successful copy inserts its event after the planner snapshot saves, in the same transaction. The copied-trip primary key makes duplicate event writes idempotent. Aggregate reads are batched by publication. Deleting a private copy retains the historical event; deleting its publication cascades the events.

Backfill recovers existing trips whose `destination_id` still equals `shared-plan:<publication UUID>`. Already deleted or no longer identifiable historical copies cannot be recovered; historical totals must not be represented as exhaustive.

Run the updated trip service so Flyway applies V21 before expecting the new fields. Updating the local client alone does not update the configured VM/backend. No production or VM deployment was performed in this task.

Verification: frontend 471 tests, TypeScript, scoped lint and production build passed; backend 264 tests, zero failures/errors, three skips, including real disposable PostgreSQL fresh/upgrade checks. Browser visual review remains pending.
