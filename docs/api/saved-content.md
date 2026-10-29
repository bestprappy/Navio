# Saved content library (implemented, VM release pending)

IAM owns `/v1/users/me/saved`. Every operation requires the resolved current account, including administrators. Next exposes the matching authenticated, same-origin proxy at `/api/users/me/saved`. Responses are no-store.

| Method/path | Behavior |
| --- | --- |
| GET collection | Paged full-library search; tab ALL/PLAN/PLACE/OPENED/TRASH, search, sort NEWEST/OLDEST/NAME/OPENED, zero-based page, size1–48. Optional country/city/category comma-separated choices (OR within field, AND between fields), source DIRECT/SHARED_PLAN, savedAfter/openedAfter ISO instants. Returns items,total,page,size,active plans/places counts. |
| POST /states | identities array maximum48; active saved state and source links only for this account. |
| POST /places | name,address,providerPlaceId,lat,lng, optional country/city/category/sourceToken. Finite bounded coordinates. Location only; no owner notes/checklists. Same canonical provider identity upserts/restores membership and merges verified sources. |
| POST /plans | token. Metadata comes from Trip's active sanitized publication, never caller-supplied title. Maximum50 active plans; atomic account lock also guards restore. |
| POST /{id}/open | Checks ownership/active membership; plan availability revalidated; records recently opened timestamp. |
| GET /{id}/reference | Active saved Plan's current safe publication reference, including published date for copy dialog. |
| GET /{id}/sources/{token} | Checks source association and current public-link availability. Unavailable source leaves location intact. |
| DELETE /{id} | Trash membership for7days; no trip/anchor/copy is removed. |
| POST /{id}/restore | Same identity restored within7days, active Plan quota applies. |
| DELETE /{id}/permanent | Explicit permanent removal of a trashed membership; source links cascade. |

Trip's internal GET /v1/shared-plans/{token}/reference is side-effect-free and accepts known active unlisted links, with the same sanitizer/status gates as shared reads. It neither enumerates links nor increments views. IAM calls configured navio.library.trip-base-url (production Docker default http://trip-planning-service:8082); no cross-schema access. It is not added to public gateway routing.

Saved coordinate/Mapbox/EV locations reuse the existing atomic POST /v1/trips/{tripId}/planner/my-list/places: provider SAVED_LOCATION plus validated savedLocation:{name,address,lat,lng} and stable providerPlaceId. Existing GOOGLE requests remain unchanged. Same owner/list/version/idempotence rules apply; no full snapshot rewrite or inherited notes. Copy still uses existing published-copy endpoint and retain/change date dialog.

Recents shows Recently saved then Recently opened. Search from Recents covers the full active library. Places have no library cap and are paged; legacy personal Home/Work/favorite picker remains bounded and separate in role. Guide saving, custom categories, shared-plan ratings/comments and share-action preview remain deferred/backlog, not claimed implemented here.
