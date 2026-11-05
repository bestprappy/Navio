# Shared Plan Feedback

Implemented contract, 5 November 2026. Requires the Trip V27 migration and matching gateway/frontend release. This is Navio feedback on a trip plan, not Google Maps visitor reviews of a place.

Live in root0e341ac (client45e42e8/serverb11f808/Tripdfe950d), verified through both the production gateway and dev:vm proxy. Public and mutation feedback paths are included in both gateway route configurations; anonymous access remains restricted by exact security rules to summary/comments GET only.

All paths are under `/v1/shared-plans/{token}/feedback`. Responses are not publicly cached. Public reads require a current, active, Explore-listed publication. Unknown, unlisted, revoked and stale-sanitizer links return the existing generic 404. Private planner copies never inherit ratings/comments.

| Method | Suffix | Contract |
|---|---|---|
| GET | empty | Public aggregate: nullable `ratingAverage`, `ratingCount`, `commentCount`; authenticated caller additionally receives nullable `myRating` and `publisher` boolean. |
| PUT | `/rating` | Authenticated `{score:1..5}`; one rating per user/publication, upsert; publisher cannot rate their own plan. Returns summary. |
| DELETE | `/rating` | Authenticated, idempotently removes own rating; returns summary. |
| GET | `/comments?page=0&parentId=<optional UUID>` | Public, 20 rows/page; top-level newest first, replies oldest first; stable timestamp/UUID ordering. `{content,hasMore,total,page}`. |
| POST | `/comments` | Authenticated `{content,authorName?,parentId?}`; plain text 1–1500 characters; optional public byline max100; replies limited to one level and same publication. 201. |
| PUT | `/comments/{id}` | Author only `{content,version}`; rejects stale edit with409. 204. |
| DELETE | `/comments/{id}` | Author or publication owner only; erases text/name and leaves tombstone for replies; idempotent. 204. |
| POST | `/comments/{id}/reports` | Authenticated `{reason:SPAM|HARASSMENT|INAPPROPRIATE|OTHER}`; cannot self-report; idempotent per reporter/comment. 204. |
| GET | `/reports` | Publisher only; at most100 unresolved reported comments with aggregate report count and content, no reporter identities. Publisher can remove through existing DELETE endpoint. |

Comment response: `id,parentId,authorName,content,deleted,createdAt,updatedAt,version,canEdit,canDelete,replyCount`. Deleted text/name are null, with no user UUID/email exposed. Author name is a sanitized public byline, not verified identity. Read permissions/edit/delete capabilities derive from gateway identity, never the submitted byline.

Gateway strips client identity headers. Only exact summary/comments GET routes are anonymous. All mutations and reports GET require authentication. Next proxies reuse authenticated-api-proxy, same-origin mutation checks and optional authenticated public reads; no new token storage.

Explore summary and shared-detail engagement DTOs add nullable `ratingAverage`, numeric `ratingCount` and `commentCount`. Missing fields from older servers remain safely optional in the client. Rating state is real only when count >0 and average is valid. Counts/averages use publication aggregate columns, avoiding per-card feedback queries.

Replies and deleted top-level comments remain browsable; new replies to deleted parents are rejected. Reporting does not auto-remove content or send external messages. No global moderation console or notification delivery is introduced in this phase.
