# Shared Plan reader: UI review

Implemented locally on 2026-10-26 for the approved UI-first review. Nothing deployed or pushed by this task.

## Where to review

- Open any listed plan from Explore, or its existing shared link. Both now use the dedicated reader. Existing anonymous access rules and copying endpoint are unchanged.
- Open **http://localhost:3000/preview/shared-plan** while running the development server for the full demonstration. This route returns a not-found page in production. It contains explicitly marked example data, never a real public plan.
- In the demonstration, open **Publishing preview** to try a temporary JPG/PNG/WebP cover (under 5 MB), vertical positioning, catalogue vehicle exclusion, custom vehicle inclusion/exclusion and list selection. Close the dialog to inspect the result. No file is uploaded or publication saved.

## Implemented reading behavior

The hero reuses the locally bundled destination covers and preferred published photos. The drawer has compact author/activity information, contents navigation, optional vehicle/list/budget sections, itinerary, draft feedback and related real plans. Stops retain the owner's published content, dates, notes and numbering. Undated and unlocated stops remain readable. The renderer never fetches the owner's private planner or account Garage.

The isolated map supports both configured Google and Mapbox providers, grouped repeated visits and day/list navigation. Entering a new day/list selects its first stop without issuing a camera command. Closing the card is respected while scrolling. The counter steps through that group's place/charging occurrences, including unlocated stops; zoom is disabled when coordinates are missing. Explicit zoom positions the location above the bounded panel. Selecting another day's marker synchronizes the By date picker. Place-card tabs cover Overview, Photos, Reviews and In this plan; current provider information is labeled separately from the owner's shared notes. Reviews link to actual provider reviews, with no invented review text.

## Deliberate preview boundaries

- Ratings and comments are local drafts/previews only, not posted or saved. Public ratings still say Not rated yet. Save/Share open preview dialogs and perform no save, clipboard or sharing action.
- Actual older public snapshots have no Garage, My List, owner-cover or introduction fields. Those sections are shown only when explicitly supplied by the development demonstration; they are not filled from private account data.
- Catalogue vehicles are included by default in the publishing preview unless excluded. Custom vehicles require an explicit choice; lists start excluded. Exclusions never remove data from the source trip.
- Existing real Copy this plan remains token-gated and uses the unchanged endpoint. The demonstration supplies no token and cannot copy fixture/local draft content. Backend persistence and copying of newly shared vehicle/list setup remain the next phase after UI approval. That future copy belongs to the copied trip, never automatically to the reader's account Garage.
- Related plans use the real listing feed, limited to its first 48 candidates: same city, then country and similar length; current token and duplicates excluded, maximum six. No unrelated filler when there are no matches.

## Verification and limitations

483 active frontend tests pass, including nine new reader/model/render tests. Full TypeScript, scoped ESLint, whitespace checks and production build pass. Real listed-plan and development-preview HTTP responses are 200; real page server HTML contains the reader, photo, copy action, feedback and related sections, without fixture content. The generated production preview artifact is a not-found page and contains no reader fixture.

Independent review found a nested thumbnail/credit interaction, which was fixed and covered by a render test, then reported no remaining important findings. Chrome was discovered but app-access approval timed out; no browser connector was available. Live visual, mobile, zoom/scroll interaction and keyboard review therefore remain for the user. Do not represent HTTP/source checks as completed browser visual QA.

Normal planner/map components, Guides, Admin, backend/schema/configuration and deferred Places editorial were not changed by this redesign. Existing unrelated unfinished work remains intact.


## 2026-10-27 feedback revision

The hero now separates its image/gradient/title from one matching photo-credit footer, eliminating overlapping attribution and the exposed image strip. During live-photo replacement or an empty refresh, the loaded photo stays visible with its matching credit until a replacement loads or fails.

Stop cards now pair photos and numbered markers with concise place facts, owner tips and explicit map navigation. Day headers have larger color-coded numbers, a tinted heading and summary so consecutive dates are easier to distinguish.

Shared-only route rows reuse the planner routing/travel-options engine. Expand a leg to compare Drive, Transit, Bike and Walk, see line/walking details and focus its geometry on either map. The owner's published mode/validated transit sequence remains In plan; local comparisons have a restore control and never enter the copy request. Routes are current estimates, not the owner's historical journey. Only adjacent located public stops within one day are connected: no private anchors, lists, cross-day links or bridging across unlocated stops.

Public transport metadata is an additive backend correction, described in ../api/Shared Plan Public Routes.md. Existing frozen snapshots may lack authored modes and then say Owner's mode not shared; drive is explicitly a suggested comparison. Running the updated trip service and republishing is required to expose owner choices for those snapshots. No migration, deployment or source commit was performed for this revision.

Verification: 488 frontend tests pass; final cover edge-case regression, TypeScript/scoped lint and production build pass. Backend unit/controller suite: 264 run, zero failures/errors, 10 optional Postgres skips, using an isolated config location and excluding the two infrastructure startup tests. The ordinary full backend invocation could not start its contexts because the local config server was unavailable. Development preview HTTP200; current live listing API HTTP502, so real-plan end-to-end/provider geometry verification is pending. Fresh static review found and verified fixes for photo/credit refresh transitions, with no remaining important findings. Browser visual/mobile/keyboard/zoom acceptance is still pending; no successful interactive browser check is claimed. Normal planner visuals remain unchanged.


## Complete round-trip review update, 2026-10-29

The previous UI-only section boundaries above are historical. Starting Part, selected My List and Garage now have real persistence/publication/copy implementations, pending backend release. Social ratings/comments and Save/Share remain previews. Starting Part supports text formatting, headings, links and lists, without uploaded images.

With npm run dev:vm, open /preview/shared-plan and choose among three complete varied examples. Prepare connected examples opens an explicit confirmation: after the updated backend is released, this creates caller-owned editable plans and listed shared links on the configured VM. Existing matching examples are reused without overwrite. It requires sign-in; no local backend is required for this workflow. Synthetic charging data is labeled, and does not represent verified charger availability.

Review both retained/changed copy dates, editable Starting Part below saved Places, mixed list ordering, Garage select/edit/remove (trip-only), notes/checklists/timetables and linked budget expenses after reload. Backend integration has verified all three sources and both date choices via real HTTP/Postgres. Browser visual/keyboard review and actual VM preparation remain pending. Old public snapshots do not gain these sections until owners republish.
