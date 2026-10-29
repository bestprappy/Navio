# Shared Plan complete publishing and copying

Status: proposed for user review, 2026-10-29. Planning Mode is optional. Only the independent zoom-icon correction has been implemented this session.

## Findings and approach

The real public snapshot contains itinerary, optional dates/notes/budget and public transport metadata. Garage, My List and introduction exist only in the development-only presentation fixture. The real publisher has no selection for them; copying reconstructs itinerary only, assigns teal, uses dates from today and loses original day titles. Preview-only presentation is inadequate for this request.

Selected direction from the user's requirements: implement the complete planner -> selected frozen publication -> shared reader -> new private planner flow. Do not put fixture overlays into real publications or fetch private owner data during anonymous reads. Keep the existing dedicated shared-reader visual style and normal planner/map behavior except requested My List additions.

## Reading order

Keep cover, author/activity/copy controls and existing social/related sections. Main content: Starting Part -> My List contents -> Garage when included -> Trip/Itinerary -> Budget. Contents navigation follows this order. Author text is authored in Planner, never generated from provider descriptions. Lists and itinerary preserve original block/item order; shared presentation can improve typography, spacing and photo layout without changing content.

## Starting Part

My List gains + Add Starting Part, a single optional document pinned immediately below saved Places and above ordinary lists. Reuse the existing block editor and read-only rich-text renderer. Title plus headings, paragraphs, bold/italic, links, bullet/numbered lists and supported text checklists; no uploaded images in this first version (user confirmed). Inline editing, normal save/reload, undo and remove/restore behavior consistent with planner notes. Empty document must not become a blank publication section.

Persist the document in the planner's own trip data, not reader presentation props or browser-only storage. Make publishing inclusion explicit. Reader opening shows its formatted introduction/tips naturally, expanded and comfortably readable; preserve semantic headings and safe links. Copy restores the editable document in the same fixed planner location.

## Publication contract and privacy

Add backward-compatible, optional Starting Part, selected lists, frozen trip vehicle descriptors and required content fields to the public DTO. Save publication selections, not transient UI-only choices. Existing links remain readable and new fields appear only after republishing; never invent missing owner content. Version additive document/DTO changes separately from sanitizer security invalidation: do not bump SANITIZER_VERSION just for new optional fields, because existing anonymous reads reject older sanitizer versions.

Catalogue trip vehicles are included by default unless excluded. Custom vehicles require explicit owner confirmation. My List selection is explicit; selected list notes/checklists retain the relevant content permission. Selections and skipped content must be visible before publication. Carry only the owner's selected public information: never account identifiers, unrelated account Garage entries, private home/work coordinates or hidden historical telemetry. Keep existing private-anchor redaction.

The published snapshot is authoritative for both reader and copy. Public reads must not consult private planner/account endpoints. Use schema-validated safe rich text/links, bounded values and freshly generated public identifiers. Add only new Flyway migrations where required, never modify V21 or other merged migrations. Persist presentation/selection metadata with additive defaults; old clients must not silently erase fields they do not understand. Add server capability checks where needed.

## Garage and copy ownership

Freeze the selected vehicles' relevant catalogue/custom specification, connectors, display identity and trip configuration. Copy these as trip-scoped vehicle data, with a new identity mapping, not references to the original owner's saved account vehicles. Do not add vehicles to the reader's account-wide Garage automatically. Resolve catalogue models by stable catalogue identity while preserving the published spec needed for the copied trip. Use the existing energy model/validation for calculations; do not fabricate range or reuse owner vehicle IDs. Current Garage filters the account library, so implement first-class rendering, selection and trip-scoped edit/remove commands for imported vehicles; merely assigning new IDs and data would otherwise leave copied Garage empty.

## Place cards, notes and checklists

Audit every currently supported planner item field against publication, rendering and copying. Preserve all selected notes, rich formatting, checklist labels/order, stop timetable entries, published transport selections, colour, day title, location/charging information and budget associations that are within the public contract. Display these using shared-reader components with full accessible detail, not just plain excerpts or truncated strings. Keep personal progress (visited status/private telemetry) separate from reusable authored plan content and document intentional omissions. Do not migrate standalone notes/checklists into a different position simply to improve appearance.

## Copy dates

User confirmed: ask first whether to retain published dates or choose new dates; either can be changed later. If dates were not published, request a start date without inferring private dates. Preserve relative day spacing/duration when changing dates. Validate before copying. Re-key days, items, list/expense associations and trip-scoped vehicles; no dangling owner IDs. Preserve day titles/colours, content order, selected Starting Part/lists/vehicles and supported budget information. Keep copying atomic: no partial trip reported as success and no copy event on failure.

## Examples and acceptance

Find the source of maintained Navio-owned example plans; do not edit real travelers' trips. Refresh every maintained review example through actual planner and publication APIs so the example proves the production contract. Each review example should provide a varied Starting Part, mixed ordered My List content, included EV Garage, populated itinerary and budget, with rich notes/checklists and varied transport. Fixture-only preview is supplementary, never proof of backend functionality. Additional automated cases cover omitted sections/non-EV/no dates/empty content.

Round-trip acceptance compares selected normalized source data to published JSON and the persisted copied planner after reload. Test document formatting/links, list/item order, day titles/colours, duplicate/unlocated places, checklist content, timetables, vehicle ownership/specs and budget ID remapping; verify exclusions/revocation and no private leakage. Test retain/change dates and rollback on failure. Run frontend type/lint/build, relevant existing tests plus meaningful contract/integration regressions, full changed-service suites and real PostgreSQL fresh/upgrade/old-schema compatibility checks. Review actual publish -> anonymous view -> copy -> reload UI, not just mock props.

## Delivery order and boundaries

1. Complete field-by-field audit and versioned contract/compatibility design.
2. Persist Starting Part and build its compact planner editor.
3. Implement selection-aware publication and trip-scoped imported Garage/list data.
4. Implement atomic complete copying and the date-choice dialog.
5. Arrange and enrich shared-reader sections/cards.
6. Populate maintained example sources and verify end-to-end before UI review.

No release/deployment authorized by this new request; implement locally first for feedback. Comments/ratings/Save/Share persistence and deferred PLACES_EDITORIAL remain outside this task. Icon uses ZoomIn with the existing action/accessible label/disabled state unchanged.

Read-only builder review: no important design gaps or remaining user decisions found. The imported Garage rendering/command model and separate additive versioning constraints above were incorporated. Larger implementation awaits review of this written proposal; the ZoomIn-only change already passes TypeScript, scoped lint and11 existing reader tests.
