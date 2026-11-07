# Private Community collections and public profile Guides

Implemented 2026-11-08; backend VM release pending. Community owns these records. Existing Explore PLAN/GUIDE/PLACE quotas and seven-day recovery are unchanged.

## Community collection API

All routes require authentication and always use the JWT subject; no caller-supplied account ID is accepted.

| Method | Route | Behavior |
| --- | --- | --- |
| GET | `/v1/social/me/library` | Paged private collection |
| PUT | `/v1/social/me/library/saved/{postId}` | Idempotent bookmark, preserving first saved time |
| DELETE | `/v1/social/me/library/saved/{postId}` | Immediate removal; permitted even after losing content access |
| PUT | `/v1/social/me/library/history/{postId}` | Record an actual readable thread visit, upsert latest opening |
| DELETE | `/v1/social/me/library/history` | Clear only the caller's visits |

GET parameters: `view=saved|voted|history|comments` (saved), `q` (literal substring, maximum200 characters), `vote=all|up|down` (all), `sort=recent|oldest|top` (recent), `page` (0..100000), `size` (1..50, default20). Search covers post title/body/community; comments additionally search the caller's comment. All supplied restrictions combine. Stable timestamp/post/comment ordering and totals use the same visibility predicate.

Response is a Spring Page of `{post,activityAt,commentId,commentBody}`. Comment fields are null outside Comment History; a comment row represents one own nondeleted comment. `PostResponse` adds `saved:boolean` to normal feeds/details/public-profile posts so cards need no per-row bookmark-status request. Public-profile drafts are not involved.

Voted is the current `social.post_votes` relation, not a history of actions. Removing a vote removes that row; sorting by recent/oldest uses the post's publication time and is labelled accordingly. Comment History is newest first in the UI.

History includes only openings within the preceding30days, one row per account/post. Feeds, image reads and link prefetches never record visits. Expired visits are excluded immediately, pruned for the visiting account, and physically removed by a daily scheduled cleanup. There is no invented historical backfill.

Hidden groups follow existing owner/moderator access; posts blocked in either direction are omitted and cannot be bookmarked/visited. Archived but readable posts remain usable. Post deletion cascades bookmarks and visits. History clearing never deletes posts/comments/votes. All collection data is private.

Unsave in Saved Posts replaces the card in place with a slim Undo row. Undo performs a fresh save; errors remain visible and retryable. Community bookmarks never enter Explore Recently Deleted. Multiple removed rows can be undone independently.

## Frontend integration

Saved defaults to Explore Recents. Explore and Community groups start expanded and can collapse; desktop navigation sticks beneath the measured navbar, while mobile stays in document flow. Community URL state uses `section=community`, `view`, `vote`, `communityQ`, `communitySort`, `communityPage`; Explore retains its existing parameters. Searches operate independently. Community uses the existing post card, vote and author components. Bookmark changes synchronize all Community projections plus public-profile post caches.

Avatar dropdown reuses the menu primitive: Profile opens `/u/{username}`, Account Settings keeps `/settings/profile`. Public profiles add Guides alongside Posts and Shared plans.

## Published Guides author filter

Existing `GET /v1/traveler-guides` accepts optional `author` UUID (public account/authentication subject). IAM resolves this to its internal profile owner ID; only that owner's PUBLISHED guides are returned. Unknown/deleted accounts return an empty page. Existing term/country/city/destination filters still apply. Invalid UUID returns400; no new IAM migration. This is the same public publication library used by Explore, not private drafts.
