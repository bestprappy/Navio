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
