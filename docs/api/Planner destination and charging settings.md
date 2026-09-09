# Planner destination and charging settings

Last verified: 2026-09-09. This contract is implemented in the local changes and requires the corresponding service deployment.

## Planner snapshot

`GET /v1/trips/{tripId}/planner` and the save acknowledgement from `PUT /v1/trips/{tripId}/planner` advertise:

```json
{ "capabilities": ["day-destinations", "charge-targets"] }
```

The existing versioned snapshot request is unchanged except for two optional fields:

```json
{
  "destination": {
    "id": "provider-place-id",
    "name": "Chiang Mai",
    "lat": 18.7883,
    "lng": 98.9853,
    "country": "Thailand"
  }
}
```

`blocks[].destination` stores a city/region change on an itinerary day. Missing/null means inherit the trip destination or the most recent preceding day override, in chronological order. Changing a destination preserves all existing stops. Clearing a later override restores inheritance. The UI also updates the trip's root destination through the existing trip metadata PUT when the first day's destination changes. Renaming uses that same metadata endpoint; it does not rename places or later destination overrides.

`blocks[].items[].evCharger.targetBatteryPct` is an optional integer from 0 to 100. New manually added stations default to 100. A target below arrival charge means no charging; it never drains the battery. Missing/null preserves the duration-based behavior of older stops. Charging estimates depend on the selected vehicle, matching connectors, and available route distances.

The trip service forwards this target as `stops[].targetBatteryPct` in mobility optimization requests. An explicit target retains its station and constrains the optimizer's departure charge (at least arrival charge). Automatically suggested charging stops may remain duration-based until the user chooses a target.

## Compatibility and persistence

- Flyway V8 adds nullable destination columns to `trip.list_block` and `target_battery_pct` to `trip.block_item`, with coordinate/percentage constraints. Existing rows need no backfill.
- Existing snapshot fields, item IDs, ordering, expenses, and optimistic version checks remain in place.
- The client checks advertised capabilities before saving a snapshot containing new settings. With an older service, it saves supported itinerary and budget fields while retaining unsupported day destinations and charge targets in a versioned local draft. The UI distinguishes an itinerary save from settings that remain on this device. Optimization is unavailable when it could overwrite unsupported settings. Cross-device persistence of those settings requires the service update.
- Trip metadata updates and planner autosaves share a serialized mutation scope. After metadata changes, the client refreshes the planner version without replacing unsaved itinerary edits.
- New trips use their country as the default name. Existing custom names stay unchanged. The trip list supports renaming and shows the selected destinations, including same-version local settings. Every date in the trip range gets an itinerary day when the planner loads; existing stops and days remain intact.
- The planner Explore section is headed by country and groups matching published plans by the trip's selected destinations. Browse all opens Explore. It does not substitute unrelated plans when no destination match exists.
- Suggested places use the effective day's city/region, coordinate bias, and an address match. Results without a matching region are omitted. Provider address language can therefore reduce suggestions; manual search remains available.

## Verification

- Frontend: TypeScript, ESLint, production build, and `node scripts/verify-planner-models.cjs`.
- Trip service: `PlannerServiceTest`, `TripEvOptimizationServiceTest`, `TripEvOptimizationApplierTest`, `PlannerControllerTest`, and `TripControllerTest` (22 tests).
- Mobility: `EvRouteOptimizationServiceTests` and `EvRouteOptimizationRequestJsonTests` (5 tests).
- Local browser fixtures cover destination inheritance, retained stops, renamed trip, charge targets, reloads, responsive layouts, and separate community scrolling. They do not replace the authenticated VM smoke test or executing V8 against PostgreSQL.

For isolated trip controller tests without Config Server, use the Maven arguments `-Dspring.cloud.config.enabled=false` and `-Dspring.config.location=optional:classpath:/application-test.yml`. This overrides external configuration for that command only.
