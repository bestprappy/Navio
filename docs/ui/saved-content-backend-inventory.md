# Saved content and shared-plan engagement inventory

2026-10-29. Read-only source audit requested by user before adjusting scope. This is an inventory/proposal, not an approved implementation plan. No feature/schema/UI work authorized in this step.

## Confirmed missing or preview-only

- Shared-plan comments: reader-feedback.tsx stores draft/preview in React state only; no plan-comment API/entity. Durable posting/listing/edit/delete/replies/pagination/authorization and moderation behavior need design. Existing Community post-comment implementation is real, but has post UUID ownership and is not connected to shared plans.
- Shared-plan 1-5 ratings: React preview only. No plan-rating storage/API; public engagement DTO has views/copies/unique copiers only. Need per-user create/update/remove policy and real average/count returned to reader/cards; distribution optional.
- Save/unsave shared plans: PreviewAction dialog only. No account plan-bookmark persistence/listing. Must stay distinct from copying into an editable planner and from source publication.
- Save/unsave guides: published traveler/official guides and author-owned guide CRUD exist; reader bookmark persistence/action/listing does not. Your Guides is authored content, not saved reading.
- Save place in shared-reader map panel: PreviewAction dialog only. Reusable Home/Work/CUSTOM favorite-place CRUD already exists at /v1/users/me/places with50 active records/user. Need connect/unify reader/Explore saves and existing favorites, dedupe metadata and saved state; avoid duplicating storage and private anchor behavior.
- Unified private Saved library: no existing page/aggregate listing for saved plans/guides/places. Proposed All/Plans/Guides/Places tabs, search/sort/filter/pagination, unsave, previews and suitable actions. Collections/folders/tags/bulk actions are proposed optional additions, not current preview promises. Need unavailable/deleted/unpublished item behavior without retaining exposed private content.
- Shared reader Share plan action: placeholder UI, but public publication/token/revoke/Explore listing backend is already real. Copy-link/Web Share wiring generally does not require a new backend feature. Guide/place URLs also exist; share UI parity optional.

## Confirmed working foundations

- Planner source saving and trip My List/Starting Part/notes/checklists.
- Explore Places Add to Plan -> chosen trip My List.
- Publishing selected sections and trip vehicles; frozen public snapshots, existing links and revocation.
- Copy shared plan with retain/change dates and trip-scoped vehicles.
- View counts, successful copy counts and distinct copier counts.
- Favorite Home/Work/CUSTOM places API and planner favorite UI.
- Guide authoring, own-guide management, publishing and public reading; account Garage.
- Community post comments/replies/edit/delete/votes/reactions; real Discuss in Community plan attachment.

## Scope decisions for user adjustment

A. Guide comments/ratings, personal place reviews/ratings, saved Community posts, author following, notifications and collections sharing are optional extensions; they are not silently part of the existing shared-reader preview backlog.
B. Keep Save (private reference for later), Copy (new editable trip), Add to Plan (place in chosen My List) and Publish/Share (owner-selected public link) distinct.
C. Decide saved-card update behavior, revoked/unpublished handling, rating eligibility/own-plan ratings, comment reply/moderation rules and the current50 favorite-place cap before implementation.
D. Default proposed Saved library is private per account; Home/Work must never become public through a collection.

Evidence: client/app/feature/planner/_components/share/reader/{reader-feedback,reader-ui,shared-reader,reader-place-panel}.tsx; server/trip-planning-service publication controller/DTOs; server/user-management-service guide/saved-place controllers/service; server/community-service CommentController/PostController and applied migration source. Deferred experiments excluded by report scope. No tests needed for this source-only audit; previous unfinished client changes preserved.
