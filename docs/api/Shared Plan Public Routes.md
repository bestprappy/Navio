# Shared Plan public routes

Implemented locally on 2026-10-27; not deployed. Existing public item JSON gains three optional nullable properties: arrivalMode (drive, transit, rail, bus, bike, walk), arrivalRouteKey (bounded validated v1 transit ride sequence), and placeType (bounded provider type identifier).

The publication sanitizer emits arrival metadata only between adjacent located public itinerary stops. It omits the first incoming leg, private anchors, coordinates hidden by publication, and paths across unlocated/unknown stops. No route geometry, private schedule, account vehicle or private list is exposed. Notes and checklists do not create spatial legs. Implicit rail-station routing retains rail-only behavior.

New copies retain published mode, validated transit selection and place type through existing planner fields. Copy API and frozen-snapshot ownership remain unchanged. Reader comparisons are isolated Jotai state; they never alter the snapshot or copy payload.

Older snapshots remain readable without changing sanitizer version. A missing mode is unknown, not an authored drive choice. Readers may calculate current suggested routes and compare them; the UI labels these separately. To publish original mode choices for existing links, run the updated trip service and have the owner republish. No automatic snapshot rewrite or deployment is performed. This change adds no entity, column or migration. Existing unrelated V21 card metrics work retains its own release requirements.


## Complete selected sections (2026-10-29, implemented; release pending)

Planner GET advertises publication-sections-v1 and trip-vehicles-v1. Optional energyState.vehicles contains at most25 validated descriptors {scope: account|trip, vehicle: SavedVehicle}; omitted data is preserved for older clients. Imported vehicles remain trip-scoped and do not create account Garage records. New client blocks lossy imported-vehicle saves/new-section publishing against older servers.

Publication options additionally accept includeStartingPart, includeGarage, listIds, excludedVehicleIds and confirmedCustomVehicleIds. Missing flags are closed by default. Owner selections persist privately; anonymous included metadata omits selection IDs. Catalogue trip vehicles are eligible unless excluded; custom vehicles require explicit confirmation. Only Garage membership is eligible, not unrelated account records.

Frozen public snapshots optionally include startingPart {title, content}, ordered lists, garage, public item id/schedule/timeSource and budget expense itemRef. Rich author notes and checklist labels follow includeNotes; Starting Part has its own explicit permission. No private anchor identity/coordinate or derived charge projection is introduced. Old links remain readable without changing sanitizer version1. Republish to gain new fields.

POST /v1/shared-plans/{token}/copies accepts optional {dateMode: retain|change, startDate: YYYY-MM-DD}. Retain requires published dates; change requires a start date. Relative spacing and declared trip duration survive. Legacy no-body clients keep their previous default. All copied identities, timetables and budget associations are remapped atomically. Custom/catalogue vehicles receive new trip identities. Visited/checklist progress resets; reusable authored content remains.

Development-only POST /api/preview/shared-plans with {confirm:true} prepares three complete caller-owned review plans on NAVIO_API_BASE_URL. Requires authenticated session, same-origin request and updated capability; production404. No private owner data is fetched anonymously, existing trips are not overwritten. Demonstration charger remains explicitly synthetic; ordinary sample places use resolved provider records. This endpoint does not deploy the backend.
