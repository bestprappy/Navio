# Shared Plan and Guide public statistics

Requested: Total Views, Unique Visitors, Current Favorites and Rating directly under the cover on both readers; add Current Favorites to both Explore card types. Preserve plan copy/copier figures separately.

Definitions: total counts each visible reader opening (guest or account), never speculative SSR/prefetch. A retry reuses its read UUID. Unique Visitors counts signed-in accounts once per publication, matching Guide behavior. Favorites counts distinct accounts with an active Saved bookmark; soft delete subtracts, restore adds, repeated saves do not inflate it. No new favorite state, no account identities in public responses.

Rulings: preserve historical Plan view_count as its existing baseline; old total-repeat and account uniqueness cannot be reconstructed. New account uniqueness starts when released. Keep older clients' GET counting compatibility, but stop forwarding browser visitor IDs from the new frontend; new visible-view POST replaces that path for new clients. Never change Guide view semantics or Google/provider behavior.

Implementation sequence (TDD, latest dev in existing clean worktrees):
1. IAM: public validated max48 aggregate favorite identities (PLAN and GUIDE only), grouped distinct active owners over existing own-schema tables. New public controller/repository with security tests and real PostgreSQL save/unsave/restore/no-double-count checks. No account rows returned and no cross-schema access.
2. Trip: additive V32 read receipt + unique account ledger; valid active listed sanitized publication required. Idempotent read POST under feedback, summary includes total and account unique counts. Lock only short counter transaction, update existing daily activity. Invalid/revoked/unlisted access remains uniform404; rating/comments authorization unchanged. Real PostgreSQL concurrency/retry/account/guest/rollback/schema tests.
3. Gateway: narrowly permit GET favorite aggregates and POST visible shared reads; route favorites to IAM. Verify other verbs/paths stay protected.
4. Client: shared four-metric row with accessible labels and unavailable placeholders, favorites batched/coalesced in TanStack Query. Invalidate after library mutations including trash restore. Use row under both covers, preserve copy details in plan overview, add favorite metric to Plan/Guide cards. Plan visible read hook uses same idempotent model as Guide; public proxies validate bodies/identity bounds, preserve optional authenticated identities. Remove legacy visitor forwarding from new read fetches.
5. Regression: unit/SSR count formatting, API/proxy validation, current active favorites refresh and responsive cards/readers, guests/accounts/retry/reload/prefetch, all existing frontend/backend tests plus PostgreSQL startup. Provider calls blocked in browser tests. Fresh final review; commit innermost first and integrate dev, production release requires new explicit approval.


Implementation rulings and verification ledger:
- Both reader types now reuse one four-metric presentation and one visible-read hook. Resource changes create a new read UUID; identity changes replay the same UUID to attach the account. Missing statistics render unavailable placeholders rather than invented zero/unrated values.
- Cancel an in-flight pre-read summary before invalidation, because browser verification reproduced a stale initial total otherwise. This also applies to the existing shared feedback refresh.
- Real PostgreSQL tests cover active bookmark deduplication, two accounts, unsave/restore/purge; concurrent read retries, historical totals and daily activity; guest-to-sign-in replay. Existing Guide replay returned before account insertion; move the insert before the duplicate-receipt return while retaining the network budget check.
- Browser verification blocks external provider hosts and uses fixture APIs. No paid Google requests, production content edits or VM deployment in this implementation session.
