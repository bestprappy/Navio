# Saved content library - draft for adjustment

Status: planning only, no feature implementation. User postponed Guides and prioritized persistent Save Place buttons on Explore Places list/cards and place reader, to the right of Add to Plan with appropriate consistent spacing. Build from existing functionality, integrating it rather than creating another disconnected collection.

## Confirmed direction

- Save Place bookmarks an account-wide reusable location; Add to Plan remains a separate action adding into a chosen trip My List. Removing a bookmark does not remove an existing trip stop. Saving a plan does not copy it.
- Navigation order: Recents, All, Plans, Guides (implementation later), Places, Recently Deleted, User Custom Category (TBD).
- Recents has two clearly labeled sections: Recently Saved on top, Recently Opened saved items below (user confirmed both). Opening unrelated unsaved pages does not silently save them.
- Recently Deleted retains removed saved items for7days, then removes them permanently from the library. Active quotas exclude deleted items; restoring a plan requires space. User selected7days.
- Interpret quota as50 saved plans and50 saved guides each; Places has no user-visible count cap. Guide saving remains later. This quota interpretation is stated for user correction, not yet independently confirmed.
- Shared reader comments/ratings remain in the earlier backlog; this discussion does not implement or expand them.

## Integration requirements found in current code

Existing /v1/users/me/places stores Home/Work/CUSTOM, enforces50 active entries, returns the complete active list, soft-deletes, and makes the first saved place a default start anchor. A library cannot simply remove the cap and reuse creation unchanged: new discovery bookmarks must never change Home/Work/default trip-start choices, and unlimited lists must be queried in pages rather than loaded wholesale into every picker. Keep one canonical saved location and separate its library membership from personal anchor roles/default behavior. Preserve existing favorites and planner choices through additive, backward-compatible changes.

The stored deletedAt field does not itself provide trash listing, restore, expiry or permanent-removal behavior. Those still need APIs/lifecycle implementation. Existing trip My List already persists its own copies and remains trip-scoped. Shared map Save place is currently preview-only and should use the same actual account saved state as Explore and existing favorite controls.

## First priority: Save Place actions

Use a shared action row: flexible Add to Plan, consistent gap, trailing Save/Saved bookmark control. Same order/alignment on list cards and reader; responsive layout must keep both usable, without overlapping/wrapping card actions inconsistently. Save starts with one action and no trip-selection dialog; Add to Plan keeps its existing selection flow. Signed-out save uses existing auth flow. Query state is account-scoped and synchronized across cards, reader, shared map and library. Same provider/place saved from multiple entry points is one saved location, not repeated records. Pending/success/failure states must never falsely show Saved; removal offers Undo and moves to trash.

Confirmed by user: Shared Plan place saves contain only the location, not owner notes/checklists or trip schedules/progress. Provide a source-plan link/button. Shared Plan and Explore origins belong to the same Places collection, never separate origin categories. Deduplicate by canonical place identity and preserve applicable source provenance without making a duplicate place. A revoked source makes its provenance link unavailable, not the independent location bookmark.

## Saved page functionality / QOL proposal

Private per-account page, reachable from sidebar Saved below Dashboard and profile navigation on pages without sidebar (placement proposed). Reuse existing plan/place cards, photo handling, authentication, tokens, query state and planner picker.

Basic search searches saved names, location and user labels, handling case/accents/partial terms and useful typo tolerance; suggestions come from the user's own library, not live worldwide provider search. Clear search, result counts, loading/empty/error states and saved query/filter state on Back are required.

Advanced controls open progressively rather than occupying the initial screen: content type, country/city, date saved, last opened and save source; contextual filters (place type for Places, author/trip duration for Plans) appear only where useful. Allow multi-select with explicit AND across filter groups/OR within a group, visible chips and Clear all. Sorting includes newest/oldest saved, recently opened and name. Search/filter/sort must query the full collection on the server and load results in pages; unlimited Places must not mean an unbounded response. Search scope should be explicit; searching from Recents should reach the complete library rather than only a short displayed slice. Recently Deleted searches only removed saved entries.

Place cards offer Open / Add to Plan / remove or restore as appropriate. Plan cards offer Open / Copy Plan / remove or restore. All distinguishes content types clearly. Guides/custom user categories retain the requested architecture/position without pretending those deferred functions work. Keep selection actions accessible by keyboard and label icon-only buttons. Optional bulk actions/grid-list toggles can follow after core flow approval; do not silently add collaboration, public collections or unrelated social features.

## Lifecycle and source rules to confirm in final design

Bookmarks are references, not copies of someone else's whole trip: use the latest published version when opened; private/revoked/deleted sources become unavailable and must not expose a stale public snapshot. Existing copied trips remain independent. User-owned private places stay private. Unsave affects only library membership, not authored trips/guides, comments/ratings, or copied plans. Restore keeps the original saved item identity and collection metadata, checks duplicates and quota atomically; re-saving a trashed item should restore it rather than create a duplicate. Show deletion age/time remaining and a clear permanent-delete boundary. Final purge must respect audit data relationships without retaining recoverable private bookmark content beyond the promised lifecycle.

No code, schema, VM data, source push or deployment in this planning step. Pending user adjustment/approval before an implementation plan.
