# Community posts and pictures

Community posts, replies and votes now persist in PostgreSQL. The frontend uses shadcn/Base UI, React Hook Form + Zod for forms, TanStack Query for server state and Jotai for shared UI state. Post links use UUIDs, so duplicate titles and later edits do not break navigation.

## Implemented endpoints

| Endpoint | Behavior |
| --- | --- |
| `GET /v1/posts?group={slug}&q={query}&sort=new&page=0&size=20` | Paginated feed/search. Omit group for active communities; the caller's muted communities are excluded. `new`, `top`, and `best` are supported. |
| `POST /v1/posts` | Create from JSON, or multipart with JSON `post` and binary `file` parts. |
| `GET /v1/posts/{id}` | Fetch a post independently of feed pagination. |
| `PATCH /v1/posts/{id}` | Author edits title and body. |
| `DELETE /v1/posts/{id}` | Author or group moderator removes a post, comments, votes and stored picture. |
| `GET /v1/posts/{id}/image` | Read sanitized pixels with the post's visibility checks. |
| `PUT /v1/posts/{id}/vote` | Set `{ "value": -1 | 0 | 1 }`; repeated votes do not accumulate. |
| `GET/POST /v1/posts/{id}/comments` | Read a page or add a comment; optional `parentCommentId` must belong to this post. |
| `DELETE /v1/posts/{id}/comments/{commentId}` | Author or moderator removes text; replies remain. |
| `PUT /v1/posts/{id}/comments/{commentId}/vote` | Set a comment vote. |
| `GET/POST/DELETE /v1/groups/{slug}/banner` | Read, upload/replace or remove a managed community banner. |
| `GET/POST/DELETE /v1/users/me/picture` | Read, upload/replace or remove the caller's profile picture. |
| `GET /v1/users/{userId}/picture` | Signed-in users can read a public profile's picture. |
| `GET /v1/users/by-subject/{subject}` | Map a community author's sign-in subject to their public profile and internal profile ID. |

Create payload: `{ groupSlug, title, body, linkUrl?, flairId?, sharedTripId?, requestId? }`. The composer supplies a stable UUID `requestId` for an unchanged draft so retrying a publish does not duplicate the post or image. Reusing it for different content returns 409. Title is required (300 characters); body is limited to 40,000 characters. Links accept HTTP/HTTPS only. Comments are limited to 10,000 characters. Post flairs must belong to the target community and be post flairs. `sharedTripId` refers to the existing public Explore-plan catalog; it does not publish a private planner itinerary.

All post/comment writes require active group membership. Archived groups are read-only. Hidden groups are readable only to their owner/moderators, including their images. Group membership, moderation and post writes share the group lock. Author checks use the validated JWT subject; profile uploads use the provisioned caller's internal user ID. Client identity headers cannot change either target.

## Upload handling

- Only decoded PNG/JPEG pixels are accepted. File extensions and caller-supplied MIME types never establish trust.
- Files are limited to 5 MiB, 4096 pixels per side, and 12 million pixels. Empty, corrupted, truncated and disguised markup uploads are rejected.
- Images are decoded and re-encoded before storage, removing uploaded metadata and trailing payloads. SVG, HTML and scripts are not served as uploaded content.
- The cookie-authenticated Next.js proxy rejects cross-origin mutations and bounds multipart streams to 6 MiB, including uploads without `Content-Length`. It forwards raw bytes instead of converting them to text.
- Image responses use a server-selected image content type, `X-Content-Type-Options: nosniff`, and `Cache-Control: no-store`. Frontend managed-image requests use the authenticated same-origin proxy.
- Post/banner object keys are server-generated. Failed transactions clean up attempted objects; replacement/deletion removes old objects after commit. Cleanup failures are logged and need operational orphan cleanup.
- Profile pictures are bounded PostgreSQL `BYTEA` records. A composite foreign key prevents assigning another user's picture. Arbitrary `avatarMediaId` profile patches are rejected.
- Post/comment text is rendered as text, never inserted as HTML.

## Deployment and verification

Apply community migration **V5** and user-management migration **V4** through Flyway. V4 clears old profile media identifiers that never referred to a managed picture; identity-provider pictures remain the frontend fallback.

Posts and banners use the existing private S3/MinIO configuration (`COMMUNITY_S3_*` and AWS credential chain). The bucket must exist; `docker-compose.storage.yml` provisions local MinIO. Profile pictures need no object-store credentials. Upload failures return an error and keep the chosen file/draft available for retry. Deploy the client, community service, user-management service and gateway together.

Verification performed with Java 25 and the existing Spring Boot 4.1.1 dependencies; no application dependencies were added:

- Community and user-management unit/controller tests, including image rejection and authorization tests.
- Real PostgreSQL migrations and integration tests for post creation/read/update/delete, comments/replies, votes, search/pagination, hidden images, banner replacement/removal and profile picture ownership.
- Client TypeScript, targeted ESLint, API/transport regression tests.
- Headless Chrome tests with mocked API responses for upload failure/retry, publish/reload, escaped text, votes, comment/reply, edit/delete, banners, profile pictures and responsive layouts. These browser tests are separate from the real PostgreSQL backend tests; they do not claim a live deployed end-to-end test.

Run backend tests with `./mvnw -o test` in each service. Set `COMMUNITY_TEST_DB_URL` (plus optional username/password) to a disposable PostgreSQL database to include community integration tests. Profile integration tests use `PROFILE_TEST_DB_URL` with test role `community_test` and an empty password. Never point these tests at production.

Client regression tests: `node --experimental-transform-types --test tests/community/*.test.mjs tests/auth-session.test.mjs`. The optional `tests/community/browser-check.mjs` uses Playwright and Chrome against an isolated dev server on port 3107 with its documented test-only secret. Set `NAVIO_BUILD_DIR=.next/community-check` for a separate development/build directory.
