# Shared Plan public routes

Implemented locally on 2026-10-27; not deployed. Existing public item JSON gains three optional nullable properties: arrivalMode (drive, transit, rail, bus, bike, walk), arrivalRouteKey (bounded validated v1 transit ride sequence), and placeType (bounded provider type identifier).

The publication sanitizer emits arrival metadata only between adjacent located public itinerary stops. It omits the first incoming leg, private anchors, coordinates hidden by publication, and paths across unlocated/unknown stops. No route geometry, private schedule, account vehicle or private list is exposed. Notes and checklists do not create spatial legs. Implicit rail-station routing retains rail-only behavior.

New copies retain published mode, validated transit selection and place type through existing planner fields. Copy API and frozen-snapshot ownership remain unchanged. Reader comparisons are isolated Jotai state; they never alter the snapshot or copy payload.

Older snapshots remain readable without changing sanitizer version. A missing mode is unknown, not an authored drive choice. Readers may calculate current suggested routes and compare them; the UI labels these separately. To publish original mode choices for existing links, run the updated trip service and have the owner republish. No automatic snapshot rewrite or deployment is performed. This change adds no entity, column or migration. Existing unrelated V21 card metrics work retains its own release requirements.
