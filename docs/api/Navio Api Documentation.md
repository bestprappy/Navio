# Navio API Documentation

**Version:** v1.3
**Base URL:** `https://api.navio.local`
**Auth:** Bearer JWT from Keycloak by default. Exceptions: `GET /v1/share/{token}` and public group discovery, detail, and search reads.
**Development entry:** `http://localhost:8080` through Spring Cloud Gateway
**Architecture:** Production NGINX forwards `/v1/**` to the same Spring Cloud Gateway used in development. The gateway resolves four core services and optional AI Planning through Eureka. Non-secret gateway/service configuration comes from Config Server. Keycloak is the Identity Provider. AI inference is selected by configuration: Ollama on the ML VM or a hosted model API through Spring AI.

## Global API Rules

### Admin color palette (2026-10-14)

Trip days, lists and guide categories use one admin-managed palette served by user-management: public `GET /v1/palette-colors`, and `GET`/`POST /v1/admin/palette-colors` plus `POST /v1/admin/palette-colors/{id}/retire|restore` for administrators. Colors are never deleted and their hex never changes. Shared-plan days now carry `colorId`. Full contract: [color-palette.md](color-palette.md).

### Precise charging contract (Phase 4C, 2026-10-13)

Planner snapshots advertise `precise-charging-v1` and accept nullable `evCharger.chargingDurationMinutes` (continuous minutes, 0–2147483647) and `evCharger.plannedDepartureSocPct` (0–100). `estimatedChargeMinutes` remains the rounded legacy value. The optimizer target is separate from the user's `targetBatteryPct`: a manual target takes precedence and locks the stop, while an optimizer target does not create a user lock. Replay uses the precise duration before the legacy integer. An unchanged legacy snapshot preserves existing precise fields; changing its legacy duration or manual target replaces that charging instruction. Removing the charger clears its charging state.

The client requires `precise-charging-v1` for precise saves and requires it together with `canonical-optimization-v1` before optimization. Unsupported saves are rejected without reporting a successful synchronization. Guest state remains temporary and does not change account vehicle data.

Trip Planning calls private Mobility endpoint `POST /internal/v1/ev-route/optimize-canonical-v2`, carrying `precedingDays`, selected-day `stops`, and `followingDays` in chronological order. Stops may contain both precise fields. Older private routes remain available for old callers, but the current Trip Planning client does not fall back to them. A successful selected-day result is replayed through the unchanged later itinerary; unavailable, disconnected, unreachable, or below-reserve state prevents application. Response `finalSocPct` and driving/charging totals describe the selected day. Rated-range models remain preview-only for automatic application.

Apply revalidates ownership and trip version and writes atomically. Retained movable chargers follow the verified route without losing identity or notes; protected stops remain in place. Shared-plan publication excludes private charging duration and target values. Mobility, Trip Planning (including V17), and the client must be deployed together; an older Mobility service fails closed on the new route.

### Vehicle energy provenance (Phase 1, 2026-09-19)

Garage responses from `/v1/users/me/vehicles` and its catalogue endpoints add an `energyProfile` object. Existing scalar specifications and calculation behaviour are unchanged. Old payloads remain accepted; older responses without this object remain supported by the client.

The version-1 profile contains `modelKind` (`CONSUMPTION`, `RATED_RANGE`, `UNAVAILABLE`), `selectionMode` (`CATALOG_DEFAULT`, `USER_OVERRIDE`, `LEGACY_UNCONFIRMED`), nullable `consumptionKwhPer100km`, `consumptionSource` (`USER_OBSERVED`, `MANUFACTURER_REPORTED`, `REGULATORY_REPORTED`, `UNKNOWN`), `consumptionMeasurementBasis` (`BATTERY_SIDE`, `WALL_SIDE`, `TRIP_COMPUTER`, `UNKNOWN`), `consumptionStandard`, nullable consumption-evidence `sourceUrl`, nullable `usableBatteryCapacityKwh`, `capacityBasis` (`USABLE`, `GROSS`, `MANUFACTURER_DECLARED_UNSPECIFIED`, `UNKNOWN`), `ratedRangeKm`, and `ratedRangeStandard`. Standards are `NEDC`, `WLTP`, `EPA`, `CLTC`, `OTHER`, or `NONE`.

Range standard and consumption standard are independent. Current catalogue entries have NEDC range, no direct consumption specification, no confirmed usable capacity, and no consumption source URL. Their existing top-level specification URL and manufacturer-declared capacity remain intact.

Create, catalogue-add and update requests may include `consumptionProvenance` alongside a numeric consumption value:

```json
{"consumptionKwhPer100km":18.125,"consumptionProvenance":{"consumptionSource":"USER_OBSERVED","consumptionMeasurementBasis":"UNKNOWN"}}
```

Only `USER_OBSERVED` is writable by users. Basis may be `UNKNOWN`, `TRIP_COMPUTER`, or `BATTERY_SIDE`; omitted basis means `UNKNOWN`. Authoritative source claims are rejected with 400. Provenance without a consumption value is rejected with 422. Existing owner-scoped authorization is unchanged.

Absent provenance is represented as legacy/unknown without recalculating consumption or writing a read-time migration. Numeric writes without provenance invalidate stale source claims; unrelated settings updates preserve them. Vehicle specification edits invalidate the old catalogue/profile claim. Phase 1 does not enforce future model eligibility, change standard factors, change the optimizer multiplier, or alter charger planning. Deploy backend contract support before the client that sends provenance.

### Public vehicle catalogue (Phase 1.1, 2026-09-21)

Only `GET /v1/users/me/vehicles/catalog` is anonymously readable, through both gateway and user-service security. The matching Next.js proxy allows anonymous access only to this exact GET operation. It returns the curated catalogue, never personal garage records, and does not provision a user. All saved-vehicle reads/writes and other private user endpoints remain authenticated. Deploy the gateway and user service before enabling guest catalogue reads on the client.

Both guest and signed-in Add Vehicle dialogs default to Catalogue and offer Custom EV. Guest catalogue selections copy validated specifications, catalogue identity and the catalogue energy profile into in-memory trip state only; their active consumption provenance remains unknown for the existing estimate, or USER_OBSERVED for an explicit average. Signed-in commands continue posting only catalogue ID and existing consumption/settings/provenance inputs; the browser catalogue snapshot is never posted as trusted server specifications. Phase 1 calculations and Phase 2 policy remain unchanged.

### Vehicle energy selection (Phase 2, 2026-09-22)

Create, catalogue-add and update requests accept optional `energySelection`:

- `USE_DEFAULT` / `RESET_DEFAULT`: omit numeric consumption and provenance. The service resolves the current catalogue entry by ID (never browser specifications), selects independently evidenced manufacturer/regulatory battery-side consumption if suitable, otherwise explicit `RATED_RANGE`, or `UNAVAILABLE` without range. Custom defaults use their reference range. Default selection stores null consumption for range fallback; no standard-factor or capacity/range derivation is performed.
- `USER_OVERRIDE`: supply positive `consumptionKwhPer100km`; provenance becomes `USER_OBSERVED`. Basis remains `UNKNOWN` unless explicitly supplied in the existing restricted provenance object. The override takes precedence; reset discards it only on the user's explicit command.
- `USE_RATED_RANGE`: explicitly select NAVIO Estimate even if direct consumption is available. Resolves server catalogue/reference range, requires a positive range, clears direct consumption and its source/standard/evidence, and preserves range/capacity metadata. Stores `RATED_RANGE` with null consumption; no numeric derivation. Guest selection applies the same contract to temporary state.
- `CONFIRM_LEGACY`: update an existing legacy vehicle without supplying consumption/provenance or changing specifications. Preserves the exact scalar and unknown provenance; stores a separate `legacyConsumptionConfirmed` boolean. Response includes that boolean. Consumption/specification edits and explicit default/override selection invalidate confirmation. No automatic migration or provenance reclassification occurs.

Omitting the command preserves old-client Phase 1 write semantics. An empty catalogue-add body is still invalid: a numeric legacy value or explicit default command is required. Invalid enum/field values return 400; contradictory command combinations and invalid legacy confirmation return 422. Unrelated metadata/settings survive updates. Null-consumption profiles survive JSONB and API mapping. No schema migration is added.

Both account modes remain catalogue-first and offer Custom EV. Custom consumption is optional. Guests resolve defaults from the fetched catalogue snapshot into temporary state only; authenticated defaults resolve on the server. The UI supports retaining current settings, using the vehicle default, entering an observed average and confirming a legacy estimate.

Phase boundary: range-only vehicles remain active for identity and connector filtering, but are withheld from the existing consumption-only calculator/optimizer until the Phase 3 model is available. The UI reports estimates unavailable instead of inventing consumption. Legacy positive-value estimates remain available; automatic application requires confirmation. Client Auto Add and optimizer Apply handlers enforce selection eligibility, including the local insertion atom. This is a client selection policy, not a redesign of the raw backend optimizer contract or its reachability validation (Phase 4). Existing calculation arithmetic and backend 1.12 multiplier remain unchanged. Deploy user-service command support before this client; real PostgreSQL/live authenticated integration still require verification.

### Canonical trip energy (Phase 3, 2026-09-24)

Phase 3.1 trip garage correction: capability `trip-garage-v1` adds optional `energyState.garageVehicleIds`, an ordered unique array of at most 25 vehicle UUIDs. Omission preserves membership; `[]` explicitly empties the trip garage. Clearing the whole energy state clears membership too. Membership does not fetch another user's vehicles: the frontend intersects it with the authenticated user's own private vehicle list. Existing trip ownership/version checks protect writes. Account list and vehicle specifications remain reusable; the planner no longer imports that entire list or its default selection into every trip. Historical trips retain only an explicitly selected vehicle snapshot, never all account vehicles. Selecting/removing a trip vehicle does not PATCH the account default or DELETE the saved vehicle. Custom EVs remain in the user's private reusable list after trip removal. Guests retain the existing temporary in-memory lifecycle and make no account writes. Servers missing the membership capability leave the energy state in the recoverable local draft instead of falsely acknowledging membership persistence.

Runtime planner snapshot contract (`GET` / `PUT /v1/trips/{tripId}/planner`): capability `trip-energy-v1` adds nullable `energyState = { initialSocPct, vehicleSnapshot }`; capability `observed-soc-v1` adds nullable `observedSocCheckpoint = { socPct }` on place items. SoC accepts 0-100 inclusive, with at most two decimal places for persisted user inputs. Omitted fields preserve stored state; explicit null clears it; 0 is a valid observation. Existing ownership and optimistic version checks remain in force. Clients without server capability keep unsynced settings in the existing recoverable local draft and do not claim server persistence.

Leg travel modes (capability `leg-travel-mode-v1`): place items accept nullable `arrivalMode` (`drive`, `transit`, `rail`, `bus`, `bike` or `walk`), meaning how the stop is reached from the previous one, and `placeType`, the provider's machine type (for example `subway_station`). Omitted `arrivalMode` preserves the stored value; explicit null returns the leg to automatic. Automatic means `transit` when both ends of the leg are stations (`subway_station`, `train_station`, `light_rail_station`, `transit_station`, or a stored label such as "Subway Station"), otherwise `drive`; day anchors are never stations. `POST /v1/routes/directions` accepts the resolved mode per point as `arrivalMode` (omitted means drive) and each segment returns `travelMode` plus `steps`: transit legs list each ride (`line { name, shortName, color, textColor, vehicleType }`, `departureStop`, `arrivalStop`, `stopCount`) and each merged walk with its own geometry. Line colours are validated hex. A transit leg's `durationSeconds` is riding plus walking time, excluding the wait for the next departure. Transit legs are routed one at a time (Google Routes cannot take transit waypoints); a missing transit route is a `fallback` segment with reason "No public transit route was found". Place details return `primaryType`. Charging optimization replays every leg as a road route, so `POST /v1/trips/{tripId}/ev-optimization/preview` and `/apply` return `422` when the selected day or an earlier day contains a transit, cycling or walking leg.

Travel options (additional capabilities `cycling-legs-v1`, `transit-preferences-v1` and `transit-route-choice-v1`, implemented locally): `bike` uses the cycling provider profile. The client compares Drive, Public transit, Bike and Walk for a single leg only when its leg icon opens the inline panel. Shadcn buttons select the mode or All transit / MRT & rail / Bus preference; shadcn accordions expose the station timeline. Rail and bus searches work between any places, including airport day anchors and hotel destinations. All transit merges confirmed alternatives from all three searches, deduplicating matching line/station sequences. Switching any mode or alternative previews its own geometry on both map providers without saving; walks are dotted and exact provider boarding/alighting coordinates create station markers. There is no departure-time input. Rail and bus preferences persist in the existing arrivalMode string; saves require transit-preferences-v1 before PUT and retain the draft on older services. Shadcn radio controls select the journey independently of Details. Use this route saves nullable arrivalRouteKey, a versioned line/station sequence capped at 4096 characters, through the additive V18 text column. On reload, the route is matched to current alternatives; missing choices become an explicit fallback rather than silently switching. Omission preserves the selection; explicit null clears it; changing mode clears the old choice. Capability checks protect the local draft against older trip services. No timetable IDs, fares or map geometry are stored. Automatic transit between rail stations sends `railOnly: true`; an explicit `transit` choice allows buses and mixed transit as well. Transit line/stop details remain provider data, not hard-coded city networks. Station insertion first searches and confirms a provider place, then inserts an independent visit before the destination. A fallback is labelled Connection unverified and exposes a question-mark explanation; direct distance is not navigable distance and no travel time is invented. Cycling saves require the capability and stop before PUT against older services, retaining the local draft. Coordinated client/Trip Planning/Mobility rollout is required.


Rail-station directions: an optional `railOnly` boolean on a directions point constrains the transit leg ending there; omitted/null/false retains general public transit, and the flag is ignored for driving/cycling/walking and the first point. The planner automatically sends `railOnly: true` between two rail stations (`subway_station`, `train_station`, `light_rail_station`, or legacy rail-station labels), including repeat visits. Generic `transit_station`/bus stops and manual transit between other places remain general transit; explicit Drive/Walk/Bike and general Transit overrides clear the restriction. Google is asked for `RAIL` modes and alternative routes, then responses are checked: at least one rail ride, all rides on rail, with access/transfer walks allowed. Bus transfers, unknown vehicles and walking-only results are rejected. If no eligible route exists, the segment is `fallback` with reason "No rail route was found" and the UI shows "Connection unverified" with a question-mark explanation. Rail and general-transit caches are separate. The client also rejects bus results from older backends. This flag is derived for directions only; there is no new saved-trip field or database migration. Explicit saved rail and bus modes request the appropriate vehicle preference and compare balanced/fewer-transfer requests, then validate every ride; rail, bus and unrestricted cache entries are separate. These mode strings use the existing arrivalMode column; the independent arrivalRouteKey field uses V18. The UI does not send departure times. API clients may opt into includeTransitAlternatives and an optional bounded RFC3339 departureTime; each segment can then carry up to four provider-independent journeys with geometry, elapsed duration, walking duration, steps, nullable schedules/timezone and fares. Step details include headsign and exact boarding/alighting coordinates. Legacy requests and constructors retain the previous contract. Unknown values remain nullable. Google still determines region coverage; nearest stations alone do not prove a connected service, and no standalone GTFS routing engine or Japan provider has been configured.

The version-1 vehicle snapshot contains vehicleId (identity only, no foreign key), label, the Phase 1 profile, nullable maxAcKw/maxDcKw, connectorTypes and legacyConsumptionConfirmed. It is copied only on explicit vehicle/model selection, never overwritten by garage/catalogue refresh. No account details are stored. Trip Starting SoC updates immediately, saves with the trip, and is restored on reopen without updating garage defaults. Historical absent values retain the existing assumed garage starting value (80% if absent), labelled as assumed; no migration backfill. Guest state follows the existing in-memory lifecycle and resets on refresh; no account writes.

`navio-energy-v1` returns nullable nominal energy/depletion, raw and display arrival SoC, observed SoC, departure SoC, predicted-leg feasibility, predicted-arrival reserve status, availability/reasons, distance quality (ROUTED/FALLBACK/UNAVAILABLE), provisional status and UNCALIBRATED uncertainty with null allowance. Reserve defaults to 12% and is not an uncertainty correction. CONSUMPTION uses distance * consumption / 100; SoC additionally needs explicitly usable capacity. RATED_RANGE uses 100 * distance / ratedRange; energy is available only with independently usable capacity. It never fabricates consumption. Known zero-distance driving consumes zero; missing distance is unavailable.

Chronology is driving prediction -> predicted arrival -> optional observed arrival -> planned charging -> departure, continuing across days. Negative raw arrival remains infeasible and stops downstream prediction until an observation restores forward state; previous failure/reserve status is retained. An observed charger stop is retained as a state constraint. Charging does not discharge when the target is below arrival. Nominal minutes = 60 * energyAdded / known compatible effective power, bounded by station and vehicle mode limits. Unknown power means null duration; unknown compatibility cannot establish charged departure. A compatible explicit target can establish intended departure SoC when capacity/time remain unknown. No taper, hidden multiplier, calibration or learning is added.

Optimizer vehicle input accepts additive `energyModel` (modelKind, consumptionKwhPer100km, usableBatteryCapacityKwh, ratedRangeKm), and stops accept observedSocPct. SoC and preview charging minutes are continuous; unknown final SoC is null. Old payloads are accepted, but their unspecified capacity is not promoted to usable capacity. The 1.12 multiplier and minimum/ceil integer depletion are removed. Search uses dominance/tolerance, at most 256 labels per node and 100,000 expansions per span, returning an explicit unavailable result if capped. Approximate route/detour inputs are warned about. Existing discrete charge targets and candidate/ranking policy remain.

Planner and Explore use the same projection. Template capacity remains declared, charging power/duration evidence may be unknown, and Explore labels its assumed 80% initial state. The legacy optimizer-application storage adapter still rounds charging minutes into the existing integer column; broader preview/apply and target persistence fixes are Phase 4. Automatic application eligibility is not loosened. Low-start Auto Add, hidden 5% candidate reserve, discovery/ranking, final road verification, complete reserve enforcement, stale-preview/application verification, later-day starting state and optimizer anchors remain deferred. Phase 5 UI consolidation is not implemented.

### Canonical optimization context (Phase 4A, 2026-10-03)

Planner snapshots advertise `canonical-optimization-v1`. Before optimization, the client flushes pending/in-flight autosave, reads the saved snapshot and requires matching versions and this capability. Preview and apply send `expectedVersion`; local itinerary, energy or budget changes invalidate the preview. A delayed apply response cannot overwrite newer local edits. Such a conflict retains the local draft for reconciliation; it is not a claim that the server operation was cancelled.

The trip service enforces ownership and resolves the energy model, charging limits/connectors and initial SoC from the saved trip, ignoring request-supplied vehicle specifications and starting SoC. A missing explicitly saved trip starting SoC is rejected rather than replaced with an assumed garage value. Consumption requires positive consumption and explicitly usable capacity. Rated range supports provisional preview only; apply rejects it. Apply requires user-observed override, suitable battery-side authoritative catalogue provenance with consumption evidence, or explicitly confirmed legacy selection. Legacy numeric values and unknown provenance are preserved.

The additive internal request to `POST /internal/v1/ev-route/optimize-canonical` includes chronological `precedingDays: [{ blockId, stops }]`. Stop context carries `observedSocPct`, `targetBatteryPct` and nullable integer `estimatedChargeMinutes`. Earlier days are replayed unchanged through road routes and the existing canonical energy model; observations replace only forward state and charging follows observations. Unknown/unreachable earlier legs, disconnected day boundaries and incomplete charger specifications cannot certify a later-day optimization. First/last charger stops are protected as day boundaries within the request without changing saved lock settings. Only the selected day is optimized. Versions are checked around preview computation and by the transactional apply path.

The old internal `/optimize` route remains available for existing callers. The new route prevents an old mobility deployment from silently ignoring chronological context; coordinated mobility, trip and frontend deployment is required. Anonymous/account permissions are unchanged. No database migration, new consumption formula, automatic calibration or UI consolidation is introduced. Complete charger feasibility/reserve policy and continuous preview/apply/reload precision remain Phase 4B/4C work; Phase 4A is not completion of all Phase 4 release gates.

### Routed charging feasibility (Phase 4B, 2026-10-06)

The canonical optimizer excludes `OTHER` as evidence of connector compatibility and requires an active station and known compatible effective power for a required charge. Unknown, stale, or busy availability is disclosed as a warning rather than a guarantee of a free connector. The unused frontend `planAutoEvChargers` helper is not the active planning path.

The selected itinerary is replayed on road routes, splitting expanded routes into at most 25 points per call with a shared boundary point. Missing, duplicate, or fallback road legs cannot certify feasibility. For each replaceable or inserted charging stop, detour distance is routed incoming plus outgoing distance minus the routed bypass between its neighbours, floored at zero. It must not exceed `maximumDetourKm`; retained mandatory stops are not treated as optional detours.

Starting battery is not an arrival: a compatible charger at the actual origin can charge from below reserve, including zero. The optimizer does not teleport to a nearby charger. Every driving arrival is checked before an observed checkpoint. Physical depletion and reserve insufficiency return distinct failure reasons. Earlier-day reserve violations prevent later-day certification. Final observations below reserve also prevent a feasible result. Saved charging targets and durations are replayed at retained stops, including the final stop. Targets below current SoC never discharge the vehicle, and unavailable prior charging state cannot be erased to certify an earlier leg.

No energy formula or public request shape changed in Phase 4B. Search remains bounded and corridor based; road verification can reject its selected candidate without claiming every alternative was exhausted.

### Common conventions

- All public APIs use `/v1`.
- Default response format is JSON.
- Default authentication is `Authorization: Bearer <access_token>`.
- Use `X-Request-Id` for frontend-to-backend correlation.
- Propagate W3C `traceparent`/`tracestate`; responses may expose a safe request ID for support.
- Error responses use `ErrorResponse`.
- Platform admin/moderator endpoints require `MODERATOR` or `ADMIN` role. Group moderator operations require an active `moderator` or `admin` membership in that group; global roles do not grant these resource-scoped rights.
- EV charger reads must be local database first; provider refresh happens only on cache miss, stale tile, manual refresh, or low-confidence coverage.

## Service Routing

These are explicit Spring Cloud Gateway routes. Raw Eureka `/serviceId/**` routes and direct service ports are private. NGINX does not maintain a second set of domain routes in production; it forwards application traffic to the gateway.

Config Server, Eureka dashboards, Gateway Actuator, service Actuator, and Grafana Alloy management endpoints are observability and operational interfaces intentionally excluded from the public OpenAPI contract. They require private-network and operator access.

| Prefix | Service | Local Port |
| --- | --- | ---: |
| `/v1/users/**`, `/v1/admin/users/**` | User Management Service | 8081 |
| `/v1/trips/**`, `/v1/public-trips/**`, `/v1/share/**` | Trip Planning Service | 8082 |
| `/v1/geo/**`, `/v1/places/**`, `/v1/routes/**`, `/v1/ev/**`, `/v1/chargers/**`, `/v1/admin/ev/**` | Mobility & EV Service | 8083 |
| `/v1/posts/**`, `/v1/groups/**`, `/v1/community/**`, `/v1/feed/**`, `/v1/notifications/**`, `/v1/media/**` | Community Service | 8084 |
| `/v1/ai/**` | AI Planning Service | 8085 |

## Trip Planning Service

### `POST /v1/trips` — Create trip

**Does:** Creates a new private trip owned by the authenticated user.
**Auth:** Bearer JWT required
**Success:** `201` `Trip`

**Request body:** `TripRequest`

```json
{
  "title": "Bangkok to Hua Hin EV Weekend",
  "description": "2-day EV-friendly road trip",
  "startDate": "2026-06-01",
  "endDate": "2026-06-02",
  "stops": [
    {
      "name": "Bangkok",
      "location": {
        "lat": 13.7563,
        "lng": 100.5018,
        "address": "Bangkok"
      },
      "orderIndex": 0
    },
    {
      "name": "Hua Hin",
      "location": {
        "lat": 12.5684,
        "lng": 99.9577,
        "address": "Hua Hin"
      },
      "orderIndex": 1
    }
  ],
  "evProfile": {
    "vehicleName": "BYD Atto 3",
    "batteryCapacityKwh": 60.5,
    "currentBatteryPercent": 80,
    "minArrivalBatteryPercent": 15,
    "consumptionKwhPer100Km": 16.5,
    "connectorTypes": ["CCS2"]
  }
}
```

**Example response:** `Trip`

```json
{
  "id": "trip_01HX",
  "ownerUserId": "user_123",
  "title": "Bangkok to Hua Hin EV Weekend",
  "visibility": "private",
  "stops": [
    {
      "name": "Bangkok",
      "location": {
        "lat": 13.7563,
        "lng": 100.5018,
        "address": "Bangkok"
      },
      "orderIndex": 0
    },
    {
      "name": "Hua Hin",
      "location": {
        "lat": 12.5684,
        "lng": 99.9577,
        "address": "Hua Hin"
      },
      "orderIndex": 1
    }
  ],
  "routeLegs": [],
  "evProfile": {
    "vehicleName": "BYD Atto 3",
    "batteryCapacityKwh": 60.5,
    "currentBatteryPercent": 80,
    "minArrivalBatteryPercent": 15,
    "consumptionKwhPer100Km": 16.5,
    "connectorTypes": ["CCS2"]
  },
  "sourceMetadata": {},
  "createdAt": "2026-05-07T05:00:00Z",
  "updatedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/trips' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"title": "Bangkok to Hua Hin EV Weekend", "description": "2-day EV-friendly road trip", "startDate": "2026-06-01", "endDate": "2026-06-02", "stops": [{"name": "Bangkok", "location": {"lat": 13.7563, "lng": 100.5018, "address": "Bangkok"}, "orderIndex": 0}, {"name": "Hua Hin", "location": {"lat": 12.5684, "lng": 99.9577, "address": "Hua Hin"}, "orderIndex": 1}], "evProfile": {"vehicleName": "BYD Atto 3", "batteryCapacityKwh": 60.5, "currentBatteryPercent": 80, "minArrivalBatteryPercent": 15, "consumptionKwhPer100Km": 16.5, "connectorTypes": ["CCS2"]}}'
```

### `GET /v1/trips/{tripId}` — Get trip

**Does:** Returns one trip if the user has access or the trip is public.
**Auth:** Bearer JWT required
**Success:** `200` `Trip`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `tripId` | path |     true | `string` | tripId path parameter |

**Request body:** none

**Example response:** `Trip`

```json
{
  "id": "trip_01HX",
  "ownerUserId": "user_123",
  "title": "Bangkok to Hua Hin EV Weekend",
  "visibility": "private",
  "stops": [
    {
      "name": "Bangkok",
      "location": {
        "lat": 13.7563,
        "lng": 100.5018,
        "address": "Bangkok"
      },
      "orderIndex": 0
    },
    {
      "name": "Hua Hin",
      "location": {
        "lat": 12.5684,
        "lng": 99.9577,
        "address": "Hua Hin"
      },
      "orderIndex": 1
    }
  ],
  "routeLegs": [],
  "evProfile": {
    "vehicleName": "BYD Atto 3",
    "batteryCapacityKwh": 60.5,
    "currentBatteryPercent": 80,
    "minArrivalBatteryPercent": 15,
    "consumptionKwhPer100Km": 16.5,
    "connectorTypes": ["CCS2"]
  },
  "sourceMetadata": {},
  "createdAt": "2026-05-07T05:00:00Z",
  "updatedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/trips/trip_01HX' \
  -H 'Authorization: Bearer <JWT>'
```

### `PATCH /v1/trips/{tripId}` — Update trip

**Does:** Updates title, dates, stops, route legs, EV profile, or notes and writes a revision.
**Auth:** Bearer JWT required
**Success:** `200` `Trip`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `tripId` | path |     true | `string` | tripId path parameter |

**Request body:** `TripRequest`

```json
{
  "title": "Bangkok to Hua Hin EV Weekend",
  "description": "2-day EV-friendly road trip",
  "startDate": "2026-06-01",
  "endDate": "2026-06-02",
  "stops": [
    {
      "name": "Bangkok",
      "location": {
        "lat": 13.7563,
        "lng": 100.5018,
        "address": "Bangkok"
      },
      "orderIndex": 0
    },
    {
      "name": "Hua Hin",
      "location": {
        "lat": 12.5684,
        "lng": 99.9577,
        "address": "Hua Hin"
      },
      "orderIndex": 1
    }
  ],
  "evProfile": {
    "vehicleName": "BYD Atto 3",
    "batteryCapacityKwh": 60.5,
    "currentBatteryPercent": 80,
    "minArrivalBatteryPercent": 15,
    "consumptionKwhPer100Km": 16.5,
    "connectorTypes": ["CCS2"]
  }
}
```

**Example response:** `Trip`

```json
{
  "id": "trip_01HX",
  "ownerUserId": "user_123",
  "title": "Bangkok to Hua Hin EV Weekend",
  "visibility": "private",
  "stops": [
    {
      "name": "Bangkok",
      "location": {
        "lat": 13.7563,
        "lng": 100.5018,
        "address": "Bangkok"
      },
      "orderIndex": 0
    },
    {
      "name": "Hua Hin",
      "location": {
        "lat": 12.5684,
        "lng": 99.9577,
        "address": "Hua Hin"
      },
      "orderIndex": 1
    }
  ],
  "routeLegs": [],
  "evProfile": {
    "vehicleName": "BYD Atto 3",
    "batteryCapacityKwh": 60.5,
    "currentBatteryPercent": 80,
    "minArrivalBatteryPercent": 15,
    "consumptionKwhPer100Km": 16.5,
    "connectorTypes": ["CCS2"]
  },
  "sourceMetadata": {},
  "createdAt": "2026-05-07T05:00:00Z",
  "updatedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X PATCH 'https://api.navio.local/v1/trips/trip_01HX' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"title": "Bangkok to Hua Hin EV Weekend", "description": "2-day EV-friendly road trip", "startDate": "2026-06-01", "endDate": "2026-06-02", "stops": [{"name": "Bangkok", "location": {"lat": 13.7563, "lng": 100.5018, "address": "Bangkok"}, "orderIndex": 0}, {"name": "Hua Hin", "location": {"lat": 12.5684, "lng": 99.9577, "address": "Hua Hin"}, "orderIndex": 1}], "evProfile": {"vehicleName": "BYD Atto 3", "batteryCapacityKwh": 60.5, "currentBatteryPercent": 80, "minArrivalBatteryPercent": 15, "consumptionKwhPer100Km": 16.5, "connectorTypes": ["CCS2"]}}'
```

### `DELETE /v1/trips/{tripId}` — Delete trip

**Does:** Soft-deletes or deletes a trip owned by the current user.
**Auth:** Bearer JWT required
**Success:** `204` no body

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `tripId` | path |     true | `string` | tripId path parameter |

**Request body:** none

**Example usage**

```bash
curl -X DELETE 'https://api.navio.local/v1/trips/trip_01HX' \
  -H 'Authorization: Bearer <JWT>'
```

### `GET /v1/trips/{tripId}/revisions` — List trip revisions

**Does:** Lists revision history for rollback and audit display.
**Auth:** Bearer JWT required
**Success:** `200` `RevisionList`

**Parameters**

| Name     | In    | Required | Type      | Notes                 |
| -------- | ----- | -------: | --------- | --------------------- |
| `tripId` | path  |     true | `string`  | tripId path parameter |
| `page`   | query |    false | `integer` |                       |
| `size`   | query |    false | `integer` |                       |

**Request body:** none

**Example response:** `RevisionList`

```json
{
  "items": [
    {
      "id": "rev_01HX",
      "tripId": "trip_01HX",
      "revisionNumber": 1,
      "message": "Initial version",
      "createdAt": "2026-05-07T05:00:00Z"
    }
  ],
  "meta": {
    "page": 0,
    "size": 20,
    "totalItems": 1,
    "totalPages": 1,
    "hasNext": false
  }
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/trips/trip_01HX/revisions' \
  -H 'Authorization: Bearer <JWT>'
```

### `POST /v1/trips/{tripId}/rollback` — Rollback trip

**Does:** Restores a trip snapshot from a specific revision and creates a new revision.
**Auth:** Bearer JWT required
**Success:** `200` `Trip`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `tripId` | path |     true | `string` | tripId path parameter |

**Request body:** `RollbackRequest`

```json
{
  "revisionId": "rev_01HX"
}
```

**Example response:** `Trip`

```json
{
  "id": "trip_01HX",
  "ownerUserId": "user_123",
  "title": "Bangkok to Hua Hin EV Weekend",
  "visibility": "private",
  "stops": [
    {
      "name": "Bangkok",
      "location": {
        "lat": 13.7563,
        "lng": 100.5018,
        "address": "Bangkok"
      },
      "orderIndex": 0
    },
    {
      "name": "Hua Hin",
      "location": {
        "lat": 12.5684,
        "lng": 99.9577,
        "address": "Hua Hin"
      },
      "orderIndex": 1
    }
  ],
  "routeLegs": [],
  "evProfile": {
    "vehicleName": "BYD Atto 3",
    "batteryCapacityKwh": 60.5,
    "currentBatteryPercent": 80,
    "minArrivalBatteryPercent": 15,
    "consumptionKwhPer100Km": 16.5,
    "connectorTypes": ["CCS2"]
  },
  "sourceMetadata": {},
  "createdAt": "2026-05-07T05:00:00Z",
  "updatedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/trips/trip_01HX/rollback' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"revisionId": "rev_01HX"}'
```

### `POST /v1/trips/{tripId}/visibility` — Change visibility

**Does:** Changes visibility between private, unlisted, and public.
**Auth:** Bearer JWT required
**Success:** `200` `Trip`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `tripId` | path |     true | `string` | tripId path parameter |

**Request body:** `VisibilityRequest`

```json
{
  "visibility": "public",
  "reason": "Ready to share"
}
```

**Example response:** `Trip`

```json
{
  "id": "trip_01HX",
  "ownerUserId": "user_123",
  "title": "Bangkok to Hua Hin EV Weekend",
  "visibility": "private",
  "stops": [
    {
      "name": "Bangkok",
      "location": {
        "lat": 13.7563,
        "lng": 100.5018,
        "address": "Bangkok"
      },
      "orderIndex": 0
    },
    {
      "name": "Hua Hin",
      "location": {
        "lat": 12.5684,
        "lng": 99.9577,
        "address": "Hua Hin"
      },
      "orderIndex": 1
    }
  ],
  "routeLegs": [],
  "evProfile": {
    "vehicleName": "BYD Atto 3",
    "batteryCapacityKwh": 60.5,
    "currentBatteryPercent": 80,
    "minArrivalBatteryPercent": 15,
    "consumptionKwhPer100Km": 16.5,
    "connectorTypes": ["CCS2"]
  },
  "sourceMetadata": {},
  "createdAt": "2026-05-07T05:00:00Z",
  "updatedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/trips/trip_01HX/visibility' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"visibility": "public", "reason": "Ready to share"}'
```

### `POST /v1/trips/{tripId}/copy` — Copy trip

**Does:** Copies a public/community/shared trip into the current user's private trip library as an independent snapshot.
**Auth:** Bearer JWT required
**Success:** `201` `Trip`
**Implementation note:** Copied trip starts private. Source deletion or edits do not affect the copy.
**Copy includes:**

- Trip title and description
- Trip dates
- Public sections/lists
- Saved places
- Itinerary items
- Public trip/place/day notes
- Route summary
- EV profile
  **Copy excludes by default:**
- Private attachments
- Reservation confirmation numbers
- Personal reservations
- Personal expenses
- Expense splits and group balances
- Tripmates/member list
- Private notes

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `tripId` | path |     true | `string` | tripId path parameter |

**Request body:** `CopyTripRequest`

```json
{
  "sourcePostId": "post_01HX",
  "newTitle": "My Copy of Hua Hin Trip"
}
```

**Example response:** `Trip`

```json
{
  "id": "trip_01HX",
  "ownerUserId": "user_123",
  "title": "Bangkok to Hua Hin EV Weekend",
  "visibility": "private",
  "stops": [
    {
      "name": "Bangkok",
      "location": {
        "lat": 13.7563,
        "lng": 100.5018,
        "address": "Bangkok"
      },
      "orderIndex": 0
    },
    {
      "name": "Hua Hin",
      "location": {
        "lat": 12.5684,
        "lng": 99.9577,
        "address": "Hua Hin"
      },
      "orderIndex": 1
    }
  ],
  "routeLegs": [],
  "evProfile": {
    "vehicleName": "BYD Atto 3",
    "batteryCapacityKwh": 60.5,
    "currentBatteryPercent": 80,
    "minArrivalBatteryPercent": 15,
    "consumptionKwhPer100Km": 16.5,
    "connectorTypes": ["CCS2"]
  },
  "sourceMetadata": {
    "copiedFromTripId": "trip_source_123",
    "copiedFromPostId": "post_123",
    "copiedFromTitle": "Bangkok EV Weekend",
    "copiedFromAuthorDisplayName": "Somchai",
    "copiedAt": "2026-05-07T08:00:00Z"
  },
  "createdAt": "2026-05-07T05:00:00Z",
  "updatedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/trips/trip_01HX/copy' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"sourcePostId": "post_01HX", "newTitle": "My Copy of Hua Hin Trip"}'
```

### `POST /v1/trips/{tripId}/share-links` — Create share link

**Does:** Creates an unlisted share token, optionally expiring and allowing copy.
**Auth:** Bearer JWT required
**Success:** `201` `ShareLink`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `tripId` | path |     true | `string` | tripId path parameter |

**Request body:** `ShareLinkRequest`

```json
{
  "expiresAt": "2026-07-01T00:00:00Z",
  "allowCopy": true
}
```

**Example response:** `ShareLink`

```json
{
  "id": "token_01HX",
  "tripId": "trip_01HX",
  "token": "shr_abc",
  "url": "https://api.navio.local/v1/share/shr_abc",
  "allowCopy": true,
  "expiresAt": "2026-07-01T00:00:00Z",
  "createdAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/trips/trip_01HX/share-links' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"expiresAt": "2026-07-01T00:00:00Z", "allowCopy": true}'
```

### `DELETE /v1/trips/{tripId}/share-links/{tokenId}` — Revoke share link

**Does:** Revokes an existing share token.
**Auth:** Bearer JWT required
**Success:** `204` no body

**Parameters**

| Name      | In   | Required | Type     | Notes                  |
| --------- | ---- | -------: | -------- | ---------------------- |
| `tripId`  | path |     true | `string` | tripId path parameter  |
| `tokenId` | path |     true | `string` | tokenId path parameter |

**Request body:** none

**Example usage**

```bash
curl -X DELETE 'https://api.navio.local/v1/trips/trip_01HX/share-links/shr_abc_01HX' \
  -H 'Authorization: Bearer <JWT>'
```

### `GET /v1/share/{token}` — Resolve share link

**Does:** Public endpoint that returns a shareable trip view from a token.
**Auth:** Public, no JWT
**Success:** `200` `ShareResolve`

**Parameters**

| Name    | In   | Required | Type     | Notes                |
| ------- | ---- | -------: | -------- | -------------------- |
| `token` | path |     true | `string` | token path parameter |

**Request body:** none

**Example response:** `ShareResolve`

```json
{
  "trip": {
    "id": "trip_01HX",
    "title": "Bangkok to Hua Hin EV Weekend",
    "visibility": "unlisted",
    "stops": []
  },
  "canCopy": true
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/share/shr_abc'
```

### `POST /v1/trips/{tripId}/permissions` — Update trip permissions

**Does:** Adds or removes authoritative viewer/editor permissions owned by Trip Planning.
**Auth:** Bearer JWT required
**Success:** `200` `PermissionsResponse`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `tripId` | path |     true | `string` | tripId path parameter |

**Request body:** `PermissionsRequest`

```json
{
  "add": [
    {
      "userId": "user_456",
      "role": "viewer"
    }
  ],
  "removeUserIds": []
}
```

**Example response:** `PermissionsResponse`

```json
{
  "items": [
    {
      "userId": "user_456",
      "role": "viewer",
      "displayName": "Nok"
    }
  ]
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/trips/trip_01HX/permissions' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"add": [{"userId": "user_456", "role": "viewer"}], "removeUserIds": []}'
```

### `GET /v1/trips/{tripId}/permissions` — Get trip permissions

**Does:** Returns current trip-scoped permission entries.
**Auth:** Bearer JWT required
**Success:** `200` `PermissionsResponse`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `tripId` | path |     true | `string` | tripId path parameter |

**Request body:** none

**Example response:** `PermissionsResponse`

```json
{
  "items": [
    {
      "userId": "user_456",
      "role": "viewer",
      "displayName": "Nok"
    }
  ]
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/trips/trip_01HX/permissions' \
  -H 'Authorization: Bearer <JWT>'
```

### Public Explore catalogue

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/v1/public-trips` | Search/filter public trip templates for Explore. |
| `GET` | `/v1/public-trips/{tripId}` | Load a public trip template. |
| `POST` | `/v1/trips/{tripId}/copy` | Copy the public template as an independent private trip. |

Supported catalogue query parameters include `q`, `destination`, `tags`, `sort`, `page`, and `size`. Trip Planning owns this search and enforces visibility.

### Trip planning extensions (v1.3)

These endpoints support detailed trip planning (dates, sections, places, itinerary, reservations, attachments, notes, budgeting, expenses, and tripmates). All endpoints in this section require Bearer JWT.

#### Trip dates

`PATCH /v1/trips/{tripId}/dates`

Request body: `TripDatesRequest`

```json
{
  "startDate": "2026-05-15",
  "endDate": "2026-05-21"
}
```

#### Day start and end anchors

Each itinerary day carries an optional `startAnchor` and `endAnchor` on its block in the planner snapshot (`GET`/`PUT /v1/trips/{tripId}/planner`, gated by the `day-anchors` capability in the snapshot response).

```json
{
  "id": "places/ChIJ...",
  "kind": "PLACE",
  "name": "Hua Hin Resort",
  "address": "Phetkasem Rd, Hua Hin",
  "lat": 12.57,
  "lng": 99.95
}
```

**A day's start is derived, not stored.** You wake up where you went to sleep, so day *n* starts at day *n−1*'s `endAnchor`. `startAnchor` is written only when that is not true — on day one, where it is the trip origin, and on any day the traveller sets out from somewhere other than last night's stop. Storing both ends on every day would let them drift apart the moment a hotel changes.

An anchor is written in full or not at all; a partly-filled anchor is rejected with `400`, because a named place at null coordinates skews drive time and EV state-of-charge silently instead of failing.

`kind` decides what happens when the trip is shared:

| kind | source | travels with a shared or published trip |
| --- | --- | --- |
| `SAVED_PLACE` | the owner's `/v1/users/me/places` | **no** — strip it server-side and substitute a placeholder anchor |
| `PLACE` | a provider place, e.g. a hotel | yes — this is what makes a template useful |
| `MANUAL` | an ad-hoc pin | yes |

The kind set is closed and validated on write. An unrecognised kind would otherwise be published by default, which is the unsafe direction.

Day one's derived distance, drive time, and state-of-charge are computed from the owner's own origin, so a copy must recompute them after the new traveller sets their start point rather than presenting the original figures.

#### Trip sections / custom lists

| Method   | Endpoint                                  | Purpose                           |
| -------- | ----------------------------------------- | --------------------------------- |
| `GET`    | `/v1/trips/{tripId}/sections`             | List sections/lists.              |
| `POST`   | `/v1/trips/{tripId}/sections`             | Create a section/list.            |
| `PATCH`  | `/v1/trips/{tripId}/sections/{sectionId}` | Rename/collapse/update a section. |
| `DELETE` | `/v1/trips/{tripId}/sections/{sectionId}` | Delete a section.                 |
| `PATCH`  | `/v1/trips/{tripId}/sections/reorder`     | Reorder sections.                 |

Create section request:

```json
{
  "title": "Restaurants",
  "sectionType": "CUSTOM"
}
```

Reorder request:

```json
{
  "sectionIds": ["sec_places", "sec_restaurants", "sec_hotels"]
}
```

#### Places inside sections

| Method   | Endpoint                                                 | Purpose                         |
| -------- | -------------------------------------------------------- | ------------------------------- |
| `GET`    | `/v1/trips/{tripId}/sections/{sectionId}/places`         | List places inside one section. |
| `POST`   | `/v1/trips/{tripId}/sections/{sectionId}/places`         | Add a provider/manual place.    |
| `PATCH`  | `/v1/trips/{tripId}/places/{placeId}`                    | Update a saved place.           |
| `DELETE` | `/v1/trips/{tripId}/places/{placeId}`                    | Remove a saved place.           |
| `PATCH`  | `/v1/trips/{tripId}/sections/{sectionId}/places/reorder` | Reorder places.                 |

Add place request:

```json
{
  "provider": "GOOGLE",
  "providerPlaceId": "ChIJ4zGFAZpYwokRGUGph3Mf37k",
  "name": "Central Park",
  "address": "New York, NY, USA",
  "lat": 40.785091,
  "lng": -73.968285,
  "notes": "Go early morning."
}
```

#### Notes

| Method   | Endpoint                            | Purpose                                    |
| -------- | ----------------------------------- | ------------------------------------------ |
| `GET`    | `/v1/trips/{tripId}/notes`          | List notes, optionally filtered by target. |
| `POST`   | `/v1/trips/{tripId}/notes`          | Create note.                               |
| `PATCH`  | `/v1/trips/{tripId}/notes/{noteId}` | Edit note.                                 |
| `DELETE` | `/v1/trips/{tripId}/notes/{noteId}` | Delete note.                               |

Create note request:

```json
{
  "targetType": "PLACE",
  "targetId": "place_123",
  "content": "Go early morning to avoid crowds."
}
```

#### Itinerary days and items

| Method   | Endpoint                                           | Purpose                 |
| -------- | -------------------------------------------------- | ----------------------- |
| `GET`    | `/v1/trips/{tripId}/itinerary`                     | Return days and items.  |
| `POST`   | `/v1/trips/{tripId}/itinerary/items`               | Add item to a day.      |
| `PATCH`  | `/v1/trips/{tripId}/itinerary/items/{itemId}`      | Update item.            |
| `DELETE` | `/v1/trips/{tripId}/itinerary/items/{itemId}`      | Remove item.            |
| `PATCH`  | `/v1/trips/{tripId}/itinerary/days/{date}/reorder` | Reorder items in a day. |

Create itinerary item:

```json
{
  "date": "2026-05-16",
  "itemType": "PLACE",
  "refId": "place_123",
  "title": "Visit Central Park",
  "startTime": "09:00",
  "endTime": "11:00"
}
```

#### Reservations

| Method   | Endpoint                                          | Purpose             |
| -------- | ------------------------------------------------- | ------------------- |
| `GET`    | `/v1/trips/{tripId}/reservations`                 | List reservations.  |
| `POST`   | `/v1/trips/{tripId}/reservations`                 | Create reservation. |
| `GET`    | `/v1/trips/{tripId}/reservations/{reservationId}` | Get reservation.    |
| `PATCH`  | `/v1/trips/{tripId}/reservations/{reservationId}` | Update reservation. |
| `DELETE` | `/v1/trips/{tripId}/reservations/{reservationId}` | Delete reservation. |

Create reservation:

```json
{
  "category": "LODGING",
  "title": "Hotel in Bangkok",
  "providerName": "Agoda",
  "confirmationNumber": "ABC123",
  "startDateTime": "2026-05-15T15:00:00+07:00",
  "endDateTime": "2026-05-18T11:00:00+07:00",
  "costAmount": 4500,
  "currency": "THB",
  "notes": "Check-in after 3 PM"
}
```

#### Attachments

Upload flow:

1. `POST /v1/media/upload-url`
2. Upload file to returned URL
3. `POST /v1/media/complete`
4. `POST /v1/trips/{tripId}/attachments` to link it

| Method   | Endpoint                                        | Purpose                                              |
| -------- | ----------------------------------------------- | ---------------------------------------------------- |
| `GET`    | `/v1/trips/{tripId}/attachments`                | List linked attachments.                             |
| `POST`   | `/v1/trips/{tripId}/attachments`                | Attach media to trip/place/reservation/expense/note. |
| `DELETE` | `/v1/trips/{tripId}/attachments/{attachmentId}` | Remove attachment link.                              |

Attach uploaded media:

```json
{
  "mediaId": "media_123",
  "targetType": "RESERVATION",
  "targetId": "res_456",
  "label": "Hotel confirmation PDF"
}
```

#### Budgeting

The current planner supports `THB`, `USD`, `EUR`, `JPY`, and `TWD` (New Taiwan Dollar, displayed as `NT$`). Changing the default currency converts the budget, expenses, and planned place costs using the latest available rate from `GET /v1/trips/currencies/rate?base=THB&quote=TWD`. The response contains `base`, `quote`, `rate`, `asOf`, and `source`; rates come from Frankfurter v2. Conversion works in both directions. If rate retrieval fails, the currency and amounts remain unchanged. Saved and shared planner budgets retain `TWD`.

| Method  | Endpoint                             | Purpose                                     |
| ------- | ------------------------------------ | ------------------------------------------- |
| `GET`   | `/v1/trips/{tripId}/budget`          | Get budget amount/currency.                 |
| `PATCH` | `/v1/trips/{tripId}/budget`          | Set budget amount/currency.                 |
| `GET`   | `/v1/trips/{tripId}/budget/summary`  | Total spent, remaining, category breakdown. |
| `GET`   | `/v1/trips/{tripId}/budget/balances` | Group balance calculation.                  |

Set budget:

```json
{
  "budgetAmount": 30000,
  "currency": "THB"
}
```

Budget summary response:

```json
{
  "tripId": "trip_123",
  "budgetAmount": 30000,
  "currency": "THB",
  "totalSpent": 12500,
  "remaining": 17500,
  "categoryBreakdown": [
    { "category": "FOOD", "amount": 2500 },
    { "category": "LODGING", "amount": 8000 }
  ]
}
```

#### Expenses

| Method   | Endpoint                                  | Purpose         |
| -------- | ----------------------------------------- | --------------- |
| `GET`    | `/v1/trips/{tripId}/expenses`             | List expenses.  |
| `POST`   | `/v1/trips/{tripId}/expenses`             | Create expense. |
| `GET`    | `/v1/trips/{tripId}/expenses/{expenseId}` | Get expense.    |
| `PATCH`  | `/v1/trips/{tripId}/expenses/{expenseId}` | Update expense. |
| `DELETE` | `/v1/trips/{tripId}/expenses/{expenseId}` | Delete expense. |

Create expense:

```json
{
  "title": "Dinner",
  "category": "FOOD",
  "amount": 850,
  "currency": "THB",
  "paidByUserId": "user_123",
  "expenseDate": "2026-05-16",
  "splits": [
    { "userId": "user_123", "splitType": "EQUAL" },
    { "userId": "user_456", "splitType": "EQUAL" }
  ]
}
```

#### Tripmates

| Method   | Endpoint                              | Purpose          |
| -------- | ------------------------------------- | ---------------- |
| `GET`    | `/v1/trips/{tripId}/members`          | List tripmates.  |
| `POST`   | `/v1/trips/{tripId}/members/invite`   | Invite tripmate. |
| `DELETE` | `/v1/trips/{tripId}/members/{userId}` | Remove tripmate. |

Invite request:

```json
{
  "email": "friend@example.com",
  "role": "EDITOR",
  "displayName": "Friend"
}
```

## User Management Service

Keycloak performs login and token issuance. User Management stores Navio-specific profiles, preferences, vehicles, suspension/audit history, and manages global role assignments through the Keycloak Admin API. Keycloak remains authoritative for `USER`, `MODERATOR`, and `ADMIN` roles.

### `GET /v1/users/me` — Get current user

**Does:** Returns the authenticated user's mirrored app profile and preferences.
**Auth:** Bearer JWT required
**Success:** `200` `UserProfile`

**Request body:** none

**Example response:** `UserProfile`

```json
{
  "id": "user_123",
  "displayName": "Somchai",
  "email": "somchai@example.com",
  "roles": ["USER"],
  "preferences": {
    "language": "en",
    "distanceUnit": "km",
    "notificationEmail": true,
    "notificationPush": false
  }
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/users/me' \
  -H 'Authorization: Bearer <JWT>'
```

### `PATCH /v1/users/me/preferences` — Update preferences

**Does:** Updates current user's language, distance, and notification preferences.
**Auth:** Bearer JWT required
**Success:** `200` `UserProfile`

**Request body:** `UserPreferences`

```json
{
  "language": "en",
  "distanceUnit": "km",
  "notificationEmail": true,
  "notificationPush": false
}
```

**Example response:** `UserProfile`

```json
{
  "id": "user_123",
  "displayName": "Somchai",
  "email": "somchai@example.com",
  "roles": ["USER"],
  "preferences": {
    "language": "en",
    "distanceUnit": "km",
    "notificationEmail": true,
    "notificationPush": false
  }
}
```

**Example usage**

```bash
curl -X PATCH 'https://api.navio.local/v1/users/me/preferences' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"language": "en", "distanceUnit": "km", "notificationEmail": true, "notificationPush": false}'
```

### `POST /v1/admin/users/{userId}/suspend` — Suspend user

**Does:** Disables the account through Keycloak, records the Navio suspension/audit entry, and publishes `UserSuspended.v1` through the user outbox.
**Auth:** Bearer JWT required; requires `MODERATOR` or `ADMIN` role
**Success:** `200` `ModerationResponse`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `userId` | path |     true | `string` | userId path parameter |

**Request body:** `ModerationRequest`

```json
{
  "reason": "Spam reports confirmed",
  "expiresAt": "2026-06-01T00:00:00Z"
}
```

**Example response:** `ModerationResponse`

```json
{
  "userId": "user_456",
  "status": "suspended",
  "reason": "Spam reports confirmed",
  "updatedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/admin/users/user_01HX/suspend' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"reason": "Spam reports confirmed", "expiresAt": "2026-06-01T00:00:00Z"}'
```

### `POST /v1/admin/users/{userId}/reactivate` — Reactivate user

**Does:** Re-enables an eligible account through Keycloak, closes the active suspension record, records the audit action, and publishes `UserReactivated.v1`.
**Auth:** Bearer JWT required; requires `MODERATOR` or `ADMIN` role
**Success:** `200` `ModerationResponse`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `userId` | path |     true | `string` | userId path parameter |

**Request body:** `ModerationRequest`

```json
{
  "reason": "Spam reports confirmed",
  "expiresAt": "2026-06-01T00:00:00Z"
}
```

**Example response:** `ModerationResponse`

```json
{
  "userId": "user_456",
  "status": "active",
  "reason": "Spam reports confirmed",
  "updatedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/admin/users/user_01HX/reactivate' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"reason": "Spam reports confirmed", "expiresAt": "2026-06-01T00:00:00Z"}'
```

#### Saved personal anchors

`/v1/users/me/places` holds the places a traveller starts and ends days from — home, work, anywhere recurring. They are **owner-only**: the route carries no user id, so it cannot be pointed at anyone else, and a `404` is returned both for a missing place and for someone else's place so ids cannot be enumerated.

```json
{
  "id": "b8f0c2a4-0000-4000-8000-000000000001",
  "label": "Home",
  "kind": "HOME",
  "name": "Sukhumvit 24",
  "address": "Khlong Toei, Bangkok",
  "lat": 13.75,
  "lng": 100.5,
  "providerPlaceId": "places/ChIJ...",
  "isDefault": true
}
```

`HOME` and `WORK` are singletons per user; `CUSTOM` is unconstrained up to 50 saved places. The first place saved becomes the default start point.

Trip Planning **copies** the resolved name and coordinates into a day anchor rather than referencing this row, so correcting an address later never rewrites a trip that was already planned. Because a row here can be a home address, a day anchor whose `kind` is `SAVED_PLACE` must be stripped from any published or shared trip snapshot and replaced with a placeholder — see the day-anchor notes under Trip Planning.

### User and role management extensions

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/v1/users/{userId}` | Get a public Navio profile. |
| `GET` | `/v1/users/me/vehicles` | List the current user's saved vehicles. |
| `POST` | `/v1/users/me/vehicles` | Add a saved vehicle. |
| `PATCH` | `/v1/users/me/vehicles/{vehicleId}` | Update nickname, battery defaults, or default selection. |
| `DELETE` | `/v1/users/me/vehicles/{vehicleId}` | Remove a saved vehicle. |
| `GET` | `/v1/users/me/places` | List the current user's saved personal anchors. |
| `POST` | `/v1/users/me/places` | Save a personal anchor (home, work, or custom). |
| `GET` | `/v1/users/me/places/{placeId}` | Get one owned saved place. |
| `PATCH` | `/v1/users/me/places/{placeId}` | Rename, move, or re-default a saved place. |
| `DELETE` | `/v1/users/me/places/{placeId}` | Remove a saved place. |
| `GET` | `/v1/admin/users` | Search and administer users. |
| `POST` | `/v1/admin/users/{userId}/roles` | Grant a global Keycloak role and write an audit record. |
| `DELETE` | `/v1/admin/users/{userId}/roles/{role}` | Revoke a global Keycloak role and write an audit record. |

Role request:

```json
{
  "role": "MODERATOR",
  "reason": "Approved community moderator"
}
```

Resource roles such as trip editor or group moderator are not global roles and remain in the owning domain service.

## Community Service — Media

### `POST /v1/media/upload-url` — Request media upload URL

**Does:** Creates a media record and returns a pre-signed upload URL.
**Auth:** Bearer JWT required
**Success:** `201` `MediaUploadUrlResponse`

**Request body:** `MediaUploadUrlRequest`

```json
{
  "filename": "charger-photo.jpg",
  "contentType": "image/jpeg",
  "sizeBytes": 524288,
  "purpose": "charger_review_image"
}
```

**Example response:** `MediaUploadUrlResponse`

```json
{
  "mediaId": "media_01HX",
  "uploadUrl": "https://uploads.navio.local/presigned",
  "method": "PUT",
  "headers": {
    "Content-Type": "image/jpeg"
  },
  "expiresAt": "2026-05-07T05:15:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/media/upload-url' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"filename": "charger-photo.jpg", "contentType": "image/jpeg", "sizeBytes": 524288, "purpose": "charger_review_image"}'
```

### `POST /v1/media/complete` — Complete media upload

**Does:** Signals upload completion so the embedded media worker can scan and prepare safe URLs.
**Auth:** Bearer JWT required
**Success:** `200` `Media`

**Request body:** `MediaCompleteRequest`

```json
{
  "mediaId": "media_01HX",
  "objectKey": "uploads/user_123/media_01HX.jpg"
}
```

**Example response:** `Media`

```json
{
  "id": "media_01HX",
  "filename": "charger-photo.jpg",
  "contentType": "image/jpeg",
  "sizeBytes": 524288,
  "status": "ready",
  "safeUrl": "https://cdn.local/media/media_01HX.jpg",
  "thumbnailUrl": "https://cdn.local/media/media_01HX_thumb.jpg",
  "createdAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/media/complete' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"mediaId": "media_01HX", "objectKey": "uploads/user_123/media_01HX.jpg"}'
```

### `GET /v1/media/{mediaId}` — Get media metadata

**Does:** Returns media processing status and safe rendering URLs.
**Auth:** Bearer JWT required
**Success:** `200` `Media`

**Parameters**

| Name      | In   | Required | Type     | Notes                  |
| --------- | ---- | -------: | -------- | ---------------------- |
| `mediaId` | path |     true | `string` | mediaId path parameter |

**Request body:** none

**Example response:** `Media`

```json
{
  "id": "media_01HX",
  "filename": "charger-photo.jpg",
  "contentType": "image/jpeg",
  "sizeBytes": 524288,
  "status": "ready",
  "safeUrl": "https://cdn.local/media/media_01HX.jpg",
  "thumbnailUrl": "https://cdn.local/media/media_01HX_thumb.jpg",
  "createdAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/media/media_01HX' \
  -H 'Authorization: Bearer <JWT>'
```

## Mobility & EV Service

### `GET /v1/geo/places/autocomplete` — Autocomplete place search

**Does:** Autocomplete place search with backend-controlled provider adapters.
**Auth:** Bearer JWT required
**Success:** `200` `PlaceAutocompleteResponse`

**Parameters**

| Name    | In    | Required | Type     | Notes          |
| ------- | ----- | -------: | -------- | -------------- |
| `query` | query |     true | `string` | Search string  |
| `lat`   | query |    false | `number` | Latitude bias  |
| `lng`   | query |    false | `number` | Longitude bias |

**Request body:** none

**Example response:** `PlaceAutocompleteResponse`

```json
{
  "items": [
    {
      "provider": "GOOGLE",
      "providerPlaceId": "ChIJ4zGFAZpYwokRGUGph3Mf37k",
      "mainText": "Central Park",
      "secondaryText": "New York, NY, USA",
      "types": ["park", "tourist_attraction"]
    }
  ]
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/geo/places/autocomplete?query=central%20park&lat=40.7&lng=-73.9' \
  -H 'Authorization: Bearer <JWT>'
```

### `GET /v1/geo/places/{providerPlaceId}` — Get place details

**Does:** Returns normalized place details before saving.
**Auth:** Bearer JWT required
**Success:** `200` `PlaceDetails`

**Parameters**

| Name              | In    | Required | Type     | Notes             |
| ----------------- | ----- | -------: | -------- | ----------------- |
| `providerPlaceId` | path  |     true | `string` | Provider place id |
| `provider`        | query |     true | `string` | Provider name     |

**Request body:** none

**Example response:** `PlaceDetails`

```json
{
  "provider": "GOOGLE",
  "providerPlaceId": "ChIJ4zGFAZpYwokRGUGph3Mf37k",
  "name": "Central Park",
  "address": "New York, NY, USA",
  "lat": 40.785091,
  "lng": -73.968285,
  "phone": "+1 212-310-6600",
  "website": "https://www.centralparknyc.org/",
  "photoUrl": "https://maps.example/central-park.jpg"
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/geo/places/ChIJ4zGFAZpYwokRGUGph3Mf37k?provider=GOOGLE' \
  -H 'Authorization: Bearer <JWT>'
```

### `POST /v1/geo/geocode` — Geocode place

**Does:** Provider-hidden geocoding endpoint for address/place search.
**Auth:** Bearer JWT required
**Success:** `200` `GeocodeResponse`

**Request body:** `GeocodeRequest`

```json
{
  "query": "CentralWorld Bangkok",
  "countryBias": "TH"
}
```

**Example response:** `GeocodeResponse`

```json
{
  "items": [
    {
      "placeId": "ChIJ...",
      "name": "CentralWorld",
      "formattedAddress": "999/9 Rama I Rd, Bangkok",
      "location": {
        "lat": 13.7466,
        "lng": 100.5391
      },
      "provider": "GOOGLE_MAPS"
    }
  ]
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/geo/geocode' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"query": "CentralWorld Bangkok", "countryBias": "TH"}'
```

### `POST /v1/geo/route` — Compute map route

**Does:** Provider-hidden route endpoint using Google Maps v1.0 adapter.
**Auth:** Bearer JWT required
**Success:** `200` `RouteResponse`

**Request body:** `RouteRequest`

```json
{
  "origin": {
    "lat": 13.7563,
    "lng": 100.5018
  },
  "destination": {
    "lat": 12.5684,
    "lng": 99.9577
  },
  "waypoints": [],
  "travelMode": "DRIVE"
}
```

**Example response:** `RouteResponse`

```json
{
  "distanceKm": 191.2,
  "durationMinutes": 165,
  "polyline": "encoded_polyline",
  "legs": [],
  "provider": "GOOGLE_MAPS"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/geo/route' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"origin": {"lat": 13.7563, "lng": 100.5018}, "destination": {"lat": 12.5684, "lng": 99.9577}, "waypoints": [], "travelMode": "DRIVE"}'
```

### `POST /v1/ev/route/compute` — Compute EV-aware route

**Does:** Calculates EV feasibility and recommends charging stops.
**Auth:** Bearer JWT required
**Success:** `200` `EvRouteResponse`

**Request body:** `EvRouteRequest`

```json
{
  "origin": {
    "lat": 13.7563,
    "lng": 100.5018
  },
  "destination": {
    "lat": 12.5684,
    "lng": 99.9577
  },
  "waypoints": [],
  "evProfile": {
    "vehicleName": "BYD Atto 3",
    "batteryCapacityKwh": 60.5,
    "currentBatteryPercent": 80,
    "minArrivalBatteryPercent": 15,
    "consumptionKwhPer100Km": 16.5,
    "connectorTypes": ["CCS2"]
  },
  "preferredConnectors": ["CCS2"],
  "minChargerKw": 50
}
```

**Example response:** `EvRouteResponse`

```json
{
  "feasible": true,
  "summary": "Route is feasible with 1 charging stop.",
  "distanceKm": 191.2,
  "durationMinutes": 165,
  "estimatedEnergyKwh": 31.5,
  "route": {
    "distanceKm": 191.2,
    "durationMinutes": 165,
    "polyline": "encoded",
    "legs": [],
    "provider": "GOOGLE_MAPS"
  },
  "chargeStops": [],
  "warnings": []
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/ev/route/compute' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"origin": {"lat": 13.7563, "lng": 100.5018}, "destination": {"lat": 12.5684, "lng": 99.9577}, "waypoints": [], "evProfile": {"vehicleName": "BYD Atto 3", "batteryCapacityKwh": 60.5, "currentBatteryPercent": 80, "minArrivalBatteryPercent": 15, "consumptionKwhPer100Km": 16.5, "connectorTypes": ["CCS2"]}, "preferredConnectors": ["CCS2"], "minChargerKw": 50}'
```

### `GET /v1/ev/chargers/near` — Search chargers near point

**Does:** Returns charger markers from local Postgres/PostGIS first; external provider refresh only on cache miss/stale/low confidence.
**Auth:** Bearer JWT required
**Success:** `200` `ChargerList`

**Parameters**

| Name        | In    | Required | Type      | Notes                              |
| ----------- | ----- | -------: | --------- | ---------------------------------- |
| `lat`       | query |     true | `number`  | Latitude                           |
| `lng`       | query |     true | `number`  | Longitude                          |
| `radiusKm`  | query |    false | `number`  | Search radius in km                |
| `connector` | query |    false | `string`  | Connector filter                   |
| `minKw`     | query |    false | `number`  | Minimum charging power             |
| `refresh`   | query |    false | `boolean` | Request backend-controlled refresh |

**Request body:** none

**Example response:** `ChargerList`

```json
{
  "items": [],
  "meta": {
    "source": "local_cache",
    "tileKey": "tile_13_6502_3811",
    "stale": false,
    "refreshed": false
  }
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/ev/chargers/near?lat=13.7563&lng=100.5018' \
  -H 'Authorization: Bearer <JWT>'
```

### `GET /v1/ev/chargers/{chargerId}` — Get charger detail

**Does:** Returns charger details, ratings, confidence, and verification status. May lazy-refresh stale details.
**Auth:** Bearer JWT required
**Success:** `200` `Charger`

**Parameters**

| Name        | In   | Required | Type     | Notes                    |
| ----------- | ---- | -------: | -------- | ------------------------ |
| `chargerId` | path |     true | `string` | chargerId path parameter |

**Request body:** none

**Example response:** `Charger`

```json
{
  "id": "chg_01HX",
  "name": "PEA VOLTA CentralWorld",
  "operatorName": "PEA VOLTA",
  "location": {
    "lat": 13.7466,
    "lng": 100.5391
  },
  "connectorTypes": ["CCS2"],
  "maxKw": 120,
  "totalConnectors": 4,
  "availableConnectors": 2,
  "source": "GOOGLE_PLACES",
  "verificationStatus": "GOOGLE_CACHED",
  "status": "active",
  "ratingAvg": 4.4,
  "ratingCount": 12,
  "confidenceScore": 0.82,
  "stale": false
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/ev/chargers/charger_01HX' \
  -H 'Authorization: Bearer <JWT>'
```

### `POST /v1/ev/chargers/suggest` — Suggest missing charger

**Does:** Creates a pending verification charger suggestion.
**Auth:** Bearer JWT required
**Success:** `201` `Charger`

**Request body:** `SuggestChargerRequest`

```json
{
  "name": "New EV Station Sukhumvit",
  "operatorName": "EA Anywhere",
  "location": {
    "lat": 13.736,
    "lng": 100.56,
    "address": "Sukhumvit Rd"
  },
  "connectorTypes": ["CCS2"],
  "maxKw": 120,
  "notes": "Located behind the mall",
  "mediaIds": []
}
```

**Example response:** `Charger`

```json
{
  "id": "chg_01HX",
  "name": "PEA VOLTA CentralWorld",
  "operatorName": "PEA VOLTA",
  "location": {
    "lat": 13.7466,
    "lng": 100.5391
  },
  "connectorTypes": ["CCS2"],
  "maxKw": 120,
  "totalConnectors": 4,
  "availableConnectors": 2,
  "source": "GOOGLE_PLACES",
  "verificationStatus": "GOOGLE_CACHED",
  "status": "active",
  "ratingAvg": 4.4,
  "ratingCount": 12,
  "confidenceScore": 0.82,
  "stale": false
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/ev/chargers/suggest' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"name": "New EV Station Sukhumvit", "operatorName": "EA Anywhere", "location": {"lat": 13.736, "lng": 100.56, "address": "Sukhumvit Rd"}, "connectorTypes": ["CCS2"], "maxKw": 120, "notes": "Located behind the mall", "mediaIds": []}'
```

### `GET /v1/ev/chargers/{chargerId}/reviews` — List charger reviews

**Does:** Lists reviews for one charger.
**Auth:** Bearer JWT required
**Success:** `200` `ReviewList`

**Parameters**

| Name        | In    | Required | Type      | Notes                    |
| ----------- | ----- | -------: | --------- | ------------------------ |
| `chargerId` | path  |     true | `string`  | chargerId path parameter |
| `page`      | query |    false | `integer` |                          |
| `size`      | query |    false | `integer` |                          |

**Request body:** none

**Example response:** `ReviewList`

```json
{
  "items": [],
  "meta": {
    "page": 0,
    "size": 20,
    "totalItems": 0,
    "totalPages": 0,
    "hasNext": false
  }
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/ev/chargers/charger_01HX/reviews' \
  -H 'Authorization: Bearer <JWT>'
```

### `POST /v1/ev/chargers/{chargerId}/reviews` — Create or replace review

**Does:** Creates or replaces the current user's review. Enforces one review per user per charger.
**Auth:** Bearer JWT required
**Success:** `201` `Review`

**Parameters**

| Name        | In   | Required | Type     | Notes                    |
| ----------- | ---- | -------: | -------- | ------------------------ |
| `chargerId` | path |     true | `string` | chargerId path parameter |

**Request body:** `ReviewRequest`

```json
{
  "rating": 5,
  "reviewText": "Worked well, easy parking.",
  "visitDate": "2026-05-01",
  "chargingSuccessful": true,
  "waitTimeMinutes": 5,
  "connectorUsed": "CCS2",
  "mediaIds": []
}
```

**Example response:** `Review`

```json
{
  "id": "review_01HX",
  "chargerId": "chg_01HX",
  "userId": "user_123",
  "rating": 5,
  "reviewText": "Worked well, easy parking.",
  "visitDate": "2026-05-01",
  "chargingSuccessful": true,
  "createdAt": "2026-05-07T05:00:00Z",
  "updatedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/ev/chargers/charger_01HX/reviews' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"rating": 5, "reviewText": "Worked well, easy parking.", "visitDate": "2026-05-01", "chargingSuccessful": true, "waitTimeMinutes": 5, "connectorUsed": "CCS2", "mediaIds": []}'
```

### `PATCH /v1/ev/chargers/{chargerId}/reviews/{reviewId}` — Edit charger review

**Does:** Edits the current user's review, or moderator/admin can edit if policy allows.
**Auth:** Bearer JWT required
**Success:** `200` `Review`

**Parameters**

| Name        | In   | Required | Type     | Notes                    |
| ----------- | ---- | -------: | -------- | ------------------------ |
| `chargerId` | path |     true | `string` | chargerId path parameter |
| `reviewId`  | path |     true | `string` | reviewId path parameter  |

**Request body:** `ReviewRequest`

```json
{
  "rating": 5,
  "reviewText": "Worked well, easy parking.",
  "visitDate": "2026-05-01",
  "chargingSuccessful": true,
  "waitTimeMinutes": 5,
  "connectorUsed": "CCS2",
  "mediaIds": []
}
```

**Example response:** `Review`

```json
{
  "id": "review_01HX",
  "chargerId": "chg_01HX",
  "userId": "user_123",
  "rating": 5,
  "reviewText": "Worked well, easy parking.",
  "visitDate": "2026-05-01",
  "chargingSuccessful": true,
  "createdAt": "2026-05-07T05:00:00Z",
  "updatedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X PATCH 'https://api.navio.local/v1/ev/chargers/charger_01HX/reviews/review_01HX' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"rating": 5, "reviewText": "Worked well, easy parking.", "visitDate": "2026-05-01", "chargingSuccessful": true, "waitTimeMinutes": 5, "connectorUsed": "CCS2", "mediaIds": []}'
```

### `DELETE /v1/ev/chargers/{chargerId}/reviews/{reviewId}` — Delete charger review

**Does:** Deletes own review or moderator/admin deletes inappropriate review.
**Auth:** Bearer JWT required
**Success:** `204` no body

**Parameters**

| Name        | In   | Required | Type     | Notes                    |
| ----------- | ---- | -------: | -------- | ------------------------ |
| `chargerId` | path |     true | `string` | chargerId path parameter |
| `reviewId`  | path |     true | `string` | reviewId path parameter  |

**Request body:** none

**Example usage**

```bash
curl -X DELETE 'https://api.navio.local/v1/ev/chargers/charger_01HX/reviews/review_01HX' \
  -H 'Authorization: Bearer <JWT>'
```

### `GET /v1/ev/chargers/{chargerId}/comments` — List charger comments

**Does:** Lists charger discussion comments. Omit parentId for top level; provide parentId for replies.
**Auth:** Bearer JWT required
**Success:** `200` `CommentList`

**Parameters**

| Name        | In    | Required | Type     | Notes                    |
| ----------- | ----- | -------: | -------- | ------------------------ |
| `chargerId` | path  |     true | `string` | chargerId path parameter |
| `parentId`  | query |    false | `string` | Parent comment ID        |

**Request body:** none

**Example response:** `CommentList`

```json
{
  "items": [],
  "meta": {
    "page": 0,
    "size": 20,
    "totalItems": 0,
    "totalPages": 0,
    "hasNext": false
  }
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/ev/chargers/charger_01HX/comments' \
  -H 'Authorization: Bearer <JWT>'
```

### `POST /v1/ev/chargers/{chargerId}/comments` — Create charger comment

**Does:** Creates a charger discussion comment or reply.
**Auth:** Bearer JWT required
**Success:** `201` `Comment`

**Parameters**

| Name        | In   | Required | Type     | Notes                    |
| ----------- | ---- | -------: | -------- | ------------------------ |
| `chargerId` | path |     true | `string` | chargerId path parameter |

**Request body:** `CommentRequest`

```json
{
  "parentCommentId": null,
  "commentText": "Is this charger open after midnight?"
}
```

**Example response:** `Comment`

```json
{
  "id": "cmt_01HX",
  "resourceId": "chg_01HX",
  "userId": "user_123",
  "parentCommentId": null,
  "body": "Is this charger open after midnight?",
  "createdAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/ev/chargers/charger_01HX/comments' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"parentCommentId": null, "commentText": "Is this charger open after midnight?"}'
```

### `DELETE /v1/ev/chargers/{chargerId}/comments/{commentId}` — Delete charger comment

**Does:** Deletes own charger comment or moderator/admin deletes it.
**Auth:** Bearer JWT required
**Success:** `204` no body

**Parameters**

| Name        | In   | Required | Type     | Notes                    |
| ----------- | ---- | -------: | -------- | ------------------------ |
| `chargerId` | path |     true | `string` | chargerId path parameter |
| `commentId` | path |     true | `string` | commentId path parameter |

**Request body:** none

**Example usage**

```bash
curl -X DELETE 'https://api.navio.local/v1/ev/chargers/charger_01HX/comments/comment_01HX' \
  -H 'Authorization: Bearer <JWT>'
```

### `POST /v1/ev/chargers/{chargerId}/report` — Report charger

**Does:** Reports incorrect charger information.
**Auth:** Bearer JWT required
**Success:** `201` `Report`

**Parameters**

| Name        | In   | Required | Type     | Notes                    |
| ----------- | ---- | -------: | -------- | ------------------------ |
| `chargerId` | path |     true | `string` | chargerId path parameter |

**Request body:** `ReportRequest`

```json
{
  "reportType": "wrong_connector",
  "description": "App shows CCS2 but only Type2 is available."
}
```

**Example response:** `Report`

```json
{
  "id": "report_01HX",
  "resourceId": "chg_01HX",
  "userId": "user_123",
  "type": "wrong_connector",
  "description": "App shows CCS2 but only Type2 is available.",
  "status": "open",
  "createdAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/ev/chargers/charger_01HX/report' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"reportType": "wrong_connector", "description": "App shows CCS2 but only Type2 is available."}'
```

### `POST /v1/ev/chargers/{chargerId}/suggest-edit` — Suggest charger edit

**Does:** Suggests edits to charger name, address, location, connectors, power, or opening hours.
**Auth:** Bearer JWT required
**Success:** `201` `Suggestion`

**Parameters**

| Name        | In   | Required | Type     | Notes                    |
| ----------- | ---- | -------: | -------- | ------------------------ |
| `chargerId` | path |     true | `string` | chargerId path parameter |

**Request body:** `ChargerSuggestionRequest`

```json
{
  "suggestedMaxKw": 150,
  "description": "Power upgraded to 150 kW."
}
```

**Example response:** `Suggestion`

```json
{
  "id": "sug_01HX",
  "resourceId": "chg_01HX",
  "userId": "user_123",
  "status": "pending",
  "createdAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/ev/chargers/charger_01HX/suggest-edit' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"suggestedMaxKw": 150, "description": "Power upgraded to 150 kW."}'
```

### `GET /v1/admin/ev/charger-reports` — List charger reports

**Does:** Admin/moderator list of charger reports.
**Auth:** Bearer JWT required; requires `MODERATOR` or `ADMIN` role
**Success:** `200` `CommentList`

**Parameters**

| Name     | In    | Required | Type      | Notes         |
| -------- | ----- | -------: | --------- | ------------- |
| `status` | query |    false | `string`  | Report status |
| `page`   | query |    false | `integer` |               |
| `size`   | query |    false | `integer` |               |

**Request body:** none

**Example response:** `CommentList`

```json
{
  "items": [],
  "meta": {
    "page": 0,
    "size": 20,
    "totalItems": 0,
    "totalPages": 0,
    "hasNext": false
  }
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/admin/ev/charger-reports' \
  -H 'Authorization: Bearer <JWT>'
```

### `POST /v1/admin/ev/chargers/{chargerId}/approve` — Approve charger

**Does:** Admin approves a pending/user-submitted charger.
**Auth:** Bearer JWT required; requires `MODERATOR` or `ADMIN` role
**Success:** `200` `AdminDecisionResponse`

**Parameters**

| Name        | In   | Required | Type     | Notes                    |
| ----------- | ---- | -------: | -------- | ------------------------ |
| `chargerId` | path |     true | `string` | chargerId path parameter |

**Request body:** `AdminDecisionRequest`

```json
{
  "reason": "Verified by admin from submitted photo"
}
```

**Example response:** `AdminDecisionResponse`

```json
{
  "id": "chg_01HX",
  "status": "approved",
  "reason": "Verified by admin from submitted photo",
  "reviewedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/admin/ev/chargers/charger_01HX/approve' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"reason": "Verified by admin from submitted photo"}'
```

### `POST /v1/admin/ev/chargers/{chargerId}/reject` — Reject charger

**Does:** Admin rejects a pending/user-submitted charger.
**Auth:** Bearer JWT required; requires `MODERATOR` or `ADMIN` role
**Success:** `200` `AdminDecisionResponse`

**Parameters**

| Name        | In   | Required | Type     | Notes                    |
| ----------- | ---- | -------: | -------- | ------------------------ |
| `chargerId` | path |     true | `string` | chargerId path parameter |

**Request body:** `AdminDecisionRequest`

```json
{
  "reason": "Verified by admin from submitted photo"
}
```

**Example response:** `AdminDecisionResponse`

```json
{
  "id": "chg_01HX",
  "status": "approved",
  "reason": "Verified by admin from submitted photo",
  "reviewedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/admin/ev/chargers/charger_01HX/reject' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"reason": "Verified by admin from submitted photo"}'
```

### `POST /v1/admin/ev/charger-suggestions/{suggestionId}/approve` — Approve charger edit

**Does:** Admin approves a suggested charger edit and applies it.
**Auth:** Bearer JWT required; requires `MODERATOR` or `ADMIN` role
**Success:** `200` `AdminDecisionResponse`

**Parameters**

| Name           | In   | Required | Type     | Notes                       |
| -------------- | ---- | -------: | -------- | --------------------------- |
| `suggestionId` | path |     true | `string` | suggestionId path parameter |

**Request body:** `AdminDecisionRequest`

```json
{
  "reason": "Verified by admin from submitted photo"
}
```

**Example response:** `AdminDecisionResponse`

```json
{
  "id": "chg_01HX",
  "status": "approved",
  "reason": "Verified by admin from submitted photo",
  "reviewedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/admin/ev/charger-suggestions/suggestion_01HX/approve' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"reason": "Verified by admin from submitted photo"}'
```

### `POST /v1/admin/ev/charger-suggestions/{suggestionId}/reject` — Reject charger edit

**Does:** Admin rejects a suggested charger edit.
**Auth:** Bearer JWT required; requires `MODERATOR` or `ADMIN` role
**Success:** `200` `AdminDecisionResponse`

**Parameters**

| Name           | In   | Required | Type     | Notes                       |
| -------------- | ---- | -------: | -------- | --------------------------- |
| `suggestionId` | path |     true | `string` | suggestionId path parameter |

**Request body:** `AdminDecisionRequest`

```json
{
  "reason": "Verified by admin from submitted photo"
}
```

**Example response:** `AdminDecisionResponse`

```json
{
  "id": "chg_01HX",
  "status": "approved",
  "reason": "Verified by admin from submitted photo",
  "reviewedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/admin/ev/charger-suggestions/suggestion_01HX/reject' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"reason": "Verified by admin from submitted photo"}'
```

### `POST /v1/admin/ev/tiles/{tileKey}/refresh` — Refresh EV geo-tile

**Does:** Manually triggers charger refresh for one geo-tile.
**Auth:** Bearer JWT required; requires `MODERATOR` or `ADMIN` role
**Success:** `202` `TileRefreshResponse`

**Parameters**

| Name      | In   | Required | Type     | Notes                  |
| --------- | ---- | -------: | -------- | ---------------------- |
| `tileKey` | path |     true | `string` | tileKey path parameter |

**Request body:** `AdminDecisionRequest`

```json
{
  "reason": "Verified by admin from submitted photo"
}
```

**Example response:** `TileRefreshResponse`

```json
{
  "tileKey": "tile_13_6502_3811",
  "provider": "GOOGLE_PLACES",
  "refreshStatus": "queued",
  "requestedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/admin/ev/tiles/tileKey/refresh' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"reason": "Verified by admin from submitted photo"}'
```

## Community Service

### Group module

The implemented group API, its request/response examples, immutable name/slug contract,
membership rules, and errors are documented in [Community group API](../../server/community-service/GROUP_API.md).
Public reads accept optional identity; all writes, mine, and member lists require identity.

| Method | Path | Identity | Group moderator | Purpose |
| --- | --- | --- | --- | --- |
| `POST` | `/v1/groups` | Required | No | Create a group |
| `GET` | `/v1/groups` | Optional | No | Discover active groups |
| `GET` | `/v1/groups/mine` | Required | No | List caller joined/muted groups |
| `GET` | `/v1/groups/search?q=ev%20charging` | Optional | No | Search active groups |
| `GET` | `/v1/groups/{slug}` | Optional | No | Read detail and caller membership |
| `POST` | `/v1/groups/{slug}/members/me` | Required | No | Join idempotently |
| `DELETE` | `/v1/groups/{slug}/members/me` | Required | No | Leave idempotently |
| `PATCH` | `/v1/groups/{slug}/members/me` | Required | No | Mute or unmute |
| `GET` | `/v1/groups/{slug}/members` | Required | Yes | List active members |
| `PUT` | `/v1/groups/{slug}/moderators` | Required | Yes | Replace moderator set |
| `PATCH` | `/v1/groups/{slug}/profile` | Required | Yes | Update supplied profile fields |
| `PUT` | `/v1/groups/{slug}/rules` | Required | Yes | Replace ordered rules |
| `PUT` | `/v1/groups/{slug}/flairs` | Required | Yes | Replace both flair collections |
| `PUT` | `/v1/groups/{slug}/resources` | Required | Yes | Replace sidebar resources |


### `POST /v1/posts` — Create post

**Does:** Creates a community post, optionally linked to a trip for manual share-to-community flow.
**Auth:** Bearer JWT required
**Success:** `201` `Post`

**Request body:** `PostRequest`

```json
{
  "tripId": "trip_01HX",
  "title": "Bangkok to Hua Hin EV Weekend",
  "body": "Sharing my EV-friendly route with one charging stop.",
  "tags": ["ev-trip", "hua-hin"],
  "visibility": "public"
}
```

**Example response:** `Post`

```json
{
  "id": "post_01HX",
  "tripId": "trip_01HX",
  "authorUserId": "user_123",
  "authorDisplayName": "Somchai",
  "title": "Bangkok to Hua Hin EV Weekend",
  "body": "Sharing my EV-friendly route with one charging stop.",
  "tags": ["ev-trip"],
  "score": 18,
  "commentCount": 5,
  "bookmarkedByMe": false,
  "createdAt": "2026-05-07T05:00:00Z",
  "updatedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/posts' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"tripId": "trip_01HX", "title": "Bangkok to Hua Hin EV Weekend", "body": "Sharing my EV-friendly route with one charging stop.", "tags": ["ev-trip", "hua-hin"], "visibility": "public"}'
```

### `GET /v1/feed` — Get feed

**Does:** Returns community feed sorted by new or top and optionally filtered by tag.
**Auth:** Bearer JWT required
**Success:** `200` `PostList`

**Parameters**

| Name   | In    | Required | Type      | Notes      |
| ------ | ----- | -------: | --------- | ---------- |
| `sort` | query |    false | `string`  | Sort mode  |
| `tag`  | query |    false | `string`  | Tag filter |
| `page` | query |    false | `integer` |            |
| `size` | query |    false | `integer` |            |

**Request body:** none

**Example response:** `PostList`

```json
{
  "items": [],
  "meta": {
    "page": 0,
    "size": 20,
    "totalItems": 0,
    "totalPages": 0,
    "hasNext": false
  }
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/feed' \
  -H 'Authorization: Bearer <JWT>'
```

### `GET /v1/posts/{postId}` — Get post

**Does:** Returns a community post by ID.
**Auth:** Bearer JWT required
**Success:** `200` `Post`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `postId` | path |     true | `string` | postId path parameter |

**Request body:** none

**Example response:** `Post`

```json
{
  "id": "post_01HX",
  "tripId": "trip_01HX",
  "authorUserId": "user_123",
  "authorDisplayName": "Somchai",
  "title": "Bangkok to Hua Hin EV Weekend",
  "body": "Sharing my EV-friendly route with one charging stop.",
  "tags": ["ev-trip"],
  "score": 18,
  "commentCount": 5,
  "bookmarkedByMe": false,
  "createdAt": "2026-05-07T05:00:00Z",
  "updatedAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/posts/post_01HX' \
  -H 'Authorization: Bearer <JWT>'
```

### `GET /v1/posts/{postId}/comments` — List post comments

**Does:** Lists top-level comments or replies by parentId.
**Auth:** Bearer JWT required
**Success:** `200` `CommentList`

**Parameters**

| Name       | In    | Required | Type     | Notes                 |
| ---------- | ----- | -------: | -------- | --------------------- |
| `postId`   | path  |     true | `string` | postId path parameter |
| `parentId` | query |    false | `string` | Parent comment ID     |

**Request body:** none

**Example response:** `CommentList`

```json
{
  "items": [],
  "meta": {
    "page": 0,
    "size": 20,
    "totalItems": 0,
    "totalPages": 0,
    "hasNext": false
  }
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/posts/post_01HX/comments' \
  -H 'Authorization: Bearer <JWT>'
```

### `POST /v1/posts/{postId}/comments` — Create post comment

**Does:** Creates a top-level comment or nested reply on a post.
**Auth:** Bearer JWT required
**Success:** `201` `Comment`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `postId` | path |     true | `string` | postId path parameter |

**Request body:** `PostCommentRequest`

```json
{
  "parentCommentId": null,
  "body": "Can I copy this trip for my own route?"
}
```

**Example response:** `Comment`

```json
{
  "id": "cmt_01HX",
  "resourceId": "chg_01HX",
  "userId": "user_123",
  "parentCommentId": null,
  "body": "Is this charger open after midnight?",
  "createdAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/posts/post_01HX/comments' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"parentCommentId": null, "body": "Can I copy this trip for my own route?"}'
```

### `PATCH /v1/posts/{postId}/comments/{commentId}` — Edit post comment

**Does:** Replaces the text of your own comment. Only the author can edit; deleted comments cannot be edited (`400`), other users get `403`. The response marks the comment `edited: true`.
**Auth:** Bearer JWT required, active group member
**Success:** `200` `Comment`

**Parameters**

| Name        | In   | Required | Type     | Notes                    |
| ----------- | ---- | -------: | -------- | ------------------------ |
| `postId`    | path |     true | `string` | postId path parameter    |
| `commentId` | path |     true | `string` | commentId path parameter |

**Request body:** `UpdateCommentRequest`

```json
{
  "body": "Can I copy this trip for a two-day route?"
}
```

**Example usage**

```bash
curl -X PATCH 'https://api.navio.local/v1/posts/post_01HX/comments/comment_01HX' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"body": "Can I copy this trip for a two-day route?"}'
```

### `DELETE /v1/posts/{postId}/comments/{commentId}` — Delete post comment

**Does:** Deletes own comment or moderator/admin deletes it. If the comment has replies it stays in the thread as a placeholder (`deleted: true`, empty body) shown as "Comment unavailable". If it has no replies it is removed entirely, together with any deleted parent comments that no longer have replies.
**Auth:** Bearer JWT required
**Success:** `204` no body

**Parameters**

| Name        | In   | Required | Type     | Notes                    |
| ----------- | ---- | -------: | -------- | ------------------------ |
| `postId`    | path |     true | `string` | postId path parameter    |
| `commentId` | path |     true | `string` | commentId path parameter |

**Request body:** none

**Example usage**

```bash
curl -X DELETE 'https://api.navio.local/v1/posts/post_01HX/comments/comment_01HX' \
  -H 'Authorization: Bearer <JWT>'
```

### `PUT /v1/posts/{postId}/comments/{commentId}/reactions/{reaction}` — React to a comment

**Does:** Adds the caller's reaction. `reaction` is one of `helpful`, `love`, `funny`, `thanks`, `want_to_go`. Repeating it is a no-op; a member may leave several different reactions on one comment. Deleted comments cannot receive reactions, and soft-deleting a comment clears its reactions.
**Auth:** Bearer JWT required; active member of the post's community
**Success:** `200` `CommunityCommentResponse` with `reactions: [{ reaction, count, reacted }]`, in the fixed order above and only for reactions with at least one member
**Errors:** `400` unknown reaction or deleted comment; `403` not an active member; `404` post or comment not visible; `409` archived community

```bash
curl -X PUT 'https://api.navio.local/v1/posts/post_01HX/comments/comment_01HX/reactions/want_to_go' \
  -H 'Authorization: Bearer <JWT>'
```

### `DELETE /v1/posts/{postId}/comments/{commentId}/reactions/{reaction}` — Remove a comment reaction

**Does:** Removes the caller's reaction of that kind, if present.
**Auth:** Bearer JWT required; active member
**Success:** `204` no body

### `POST|DELETE|GET /v1/groups/{slug}/icon` — Community icon

**Does:** Works exactly like `/v1/groups/{slug}/banner`: owners and moderators upload (`multipart/form-data`, part `file`, PNG/JPEG up to 5 MiB, 4096 px per side, re-encoded before storage) or remove the icon; anyone who can see the community reads it. The detail response and every group list item carry `iconMediaId` and `bannerMediaId`; posts carry `groupIconMediaId`. Clients load `/v1/groups/{slug}/icon?v={iconMediaId}`.
**Auth:** `GET` public; `POST`/`DELETE` Bearer JWT, content editor
**Success:** `201` `GroupDetailResponse` on upload, `204` on delete, image bytes on read

### `GET /v1/posts?joined=true` — Home feed

**Does:** Without `group`, `joined=true` returns only posts from communities the caller has joined (state `joined`). Anonymous callers get an empty page. `sort=best` ranks by `(score + comments × 0.5 + 1) / (age in hours + 2)^1.5`; `top` is score; `new` is newest first.

### `PUT /v1/posts/{postId}/vote` — Vote on post

**Does:** Upserts current user's vote. direction=1 upvote, -1 downvote, 0 retract.
**Auth:** Bearer JWT required
**Success:** `200` `VoteResponse`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `postId` | path |     true | `string` | postId path parameter |

**Request body:** `VoteRequest`

```json
{
  "direction": 1
}
```

**Example response:** `VoteResponse`

```json
{
  "postId": "post_01HX",
  "myVote": 1,
  "score": 19
}
```

**Example usage**

```bash
curl -X PUT 'https://api.navio.local/v1/posts/post_01HX/vote' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"direction": 1}'
```

### `POST /v1/posts/{postId}/report` — Report post

**Does:** Reports a post for moderation.
**Auth:** Bearer JWT required
**Success:** `201` `Report`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `postId` | path |     true | `string` | postId path parameter |

**Request body:** `ReportRequest`

```json
{
  "reportType": "wrong_connector",
  "description": "App shows CCS2 but only Type2 is available."
}
```

**Example response:** `Report`

```json
{
  "id": "report_01HX",
  "resourceId": "chg_01HX",
  "userId": "user_123",
  "type": "wrong_connector",
  "description": "App shows CCS2 but only Type2 is available.",
  "status": "open",
  "createdAt": "2026-05-07T05:00:00Z"
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/posts/post_01HX/report' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"reportType": "wrong_connector", "description": "App shows CCS2 but only Type2 is available."}'
```

### `DELETE /v1/posts/{postId}` — Delete post

**Does:** Moderator/admin deletes a post.
**Auth:** Bearer JWT required; requires `MODERATOR` or `ADMIN` role
**Success:** `204` no body

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `postId` | path |     true | `string` | postId path parameter |

**Request body:** none

**Example usage**

```bash
curl -X DELETE 'https://api.navio.local/v1/posts/post_01HX' \
  -H 'Authorization: Bearer <JWT>'
```

### `POST /v1/posts/{postId}/bookmark` — Bookmark post

**Does:** Bookmarks a post for the current user.
**Auth:** Bearer JWT required
**Success:** `200` `BookmarkResponse`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `postId` | path |     true | `string` | postId path parameter |

**Request body:** none

**Example response:** `BookmarkResponse`

```json
{
  "postId": "post_01HX",
  "bookmarked": true
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/posts/post_01HX/bookmark' \
  -H 'Authorization: Bearer <JWT>'
```

### `DELETE /v1/posts/{postId}/bookmark` — Remove bookmark

**Does:** Removes a bookmark from the current user.
**Auth:** Bearer JWT required
**Success:** `200` `BookmarkResponse`

**Parameters**

| Name     | In   | Required | Type     | Notes                 |
| -------- | ---- | -------: | -------- | --------------------- |
| `postId` | path |     true | `string` | postId path parameter |

**Request body:** none

**Example response:** `BookmarkResponse`

```json
{
  "postId": "post_01HX",
  "bookmarked": true
}
```

**Example usage**

```bash
curl -X DELETE 'https://api.navio.local/v1/posts/post_01HX/bookmark' \
  -H 'Authorization: Bearer <JWT>'
```

### `GET /v1/community/bookmarks` — List bookmarks

**Does:** Lists current user's bookmarked posts.
**Auth:** Bearer JWT required
**Success:** `200` `PostList`

**Parameters**

| Name   | In    | Required | Type      | Notes |
| ------ | ----- | -------: | --------- | ----- |
| `page` | query |    false | `integer` |       |
| `size` | query |    false | `integer` |       |

**Request body:** none

**Example response:** `PostList`

```json
{
  "items": [],
  "meta": {
    "page": 0,
    "size": 20,
    "totalItems": 0,
    "totalPages": 0,
    "hasNext": false
  }
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/community/bookmarks' \
  -H 'Authorization: Bearer <JWT>'
```

### `GET /v1/community/search` — Search community

**Does:** Searches community groups and posts using PostgreSQL full-text search. Attached public-trip snapshot text may improve post matching, but Trip Planning remains authoritative for public-trip search.
**Auth:** Bearer JWT required
**Success:** `200` `SearchResponse`

**Parameters**

| Name   | In    | Required | Type      | Notes        |
| ------ | ----- | -------: | --------- | ------------ |
| `q`    | query |     true | `string`  | Search query |
| `type` | query |    false | `string`  | `posts`, `groups`, or `all` |
| `page` | query |    false | `integer` |              |
| `size` | query |    false | `integer` |              |

**Request body:** none

**Example response:** `SearchResponse`

```json
{
  "items": [
    {
      "type": "post",
      "id": "post_01HX",
      "title": "Bangkok to Hua Hin EV Weekend",
      "snippet": "EV-friendly route...",
      "score": 0.92
    }
  ],
  "meta": {
    "page": 0,
    "size": 20,
    "totalItems": 1,
    "totalPages": 1,
    "hasNext": false
  }
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/community/search?q=hua hin ev' \
  -H 'Authorization: Bearer <JWT>'
```

### `GET /v1/notifications` — List notifications

**Does:** Returns current user's in-app notification inbox.
**Auth:** Bearer JWT required
**Success:** `200` `NotificationList`

**Parameters**

| Name         | In    | Required | Type      | Notes |
| ------------ | ----- | -------: | --------- | ----- |
| `unreadOnly` | query |    false | `boolean` |       |
| `page`       | query |    false | `integer` |       |
| `size`       | query |    false | `integer` |       |

**Request body:** none

**Example response:** `NotificationList`

```json
{
  "items": [
    {
      "id": "notif_01HX",
      "type": "comment_created",
      "title": "New comment",
      "body": "Nok commented on your post.",
      "read": false,
      "createdAt": "2026-05-07T05:00:00Z",
      "data": {
        "postId": "post_01HX"
      }
    }
  ],
  "meta": {
    "page": 0,
    "size": 20,
    "totalItems": 1,
    "totalPages": 1,
    "hasNext": false
  }
}
```

**Example usage**

```bash
curl 'https://api.navio.local/v1/notifications' \
  -H 'Authorization: Bearer <JWT>'
```

### `POST /v1/notifications/{id}/read` — Mark notification read

**Does:** Marks one notification as read.
**Auth:** Bearer JWT required
**Success:** `200` `Notification`

**Parameters**

| Name | In   | Required | Type     | Notes             |
| ---- | ---- | -------: | -------- | ----------------- |
| `id` | path |     true | `string` | id path parameter |

**Request body:** none

**Example response:** `Notification`

```json
{}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/notifications/id/read' \
  -H 'Authorization: Bearer <JWT>'
```

## AI Planning Service

AI Planning uses Spring AI's portable chat and streaming abstractions. Deployment selects one provider profile without changing these public contracts:

- `ollama`: AI Planning and Ollama run on the ML VM; Ollama is loopback-only.
- `hosted`: AI Planning runs on the application VM and calls a hosted model API; no ML VM or Ollama is required.

The model provider never receives database credentials and cannot call arbitrary URLs. All tools are server-owned and allow-listed.

### `POST /v1/ai/plan/suggest` — Suggest plan changes

**Does:** Uses the configured Spring AI provider to produce schema-validated itinerary and EV improvement proposals. This endpoint never applies changes directly; it returns a preview that must be confirmed separately.
**Auth:** Bearer JWT required
**Success:** `200` `AiPlanSuggestResponse`

**Request body:** `AiPlanSuggestRequest`

```json
{
  "tripId": "trip_01HX",
  "goal": "Make this trip safer for an EV with fewer low-battery segments.",
  "constraints": ["Prefer CCS2 chargers above 50 kW"]
}
```

**Example response:** `AiPlanSuggestResponse`

```json
{
  "sessionId": "ai_sess_01HX",
  "summary": "Add one charging stop before Hua Hin.",
  "actions": [
    {
      "type": "recompute_ev_route",
      "description": "Recompute with fresh charger data.",
      "payload": {}
    }
  ],
  "quota": {
    "tokensUsedThisMonth": 12500,
    "monthlyTokenLimit": 100000
  }
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/ai/plan/suggest' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"tripId": "trip_01HX", "goal": "Make this trip safer for an EV with fewer low-battery segments.", "constraints": ["Prefer CCS2 chargers above 50 kW"]}'
```

### `POST /v1/ai/plan/chat` — Chat with plan

**Does:** Conversational plan assistance with a bounded tool loop. Supports JSON for non-streaming clients and `text/event-stream` for the frontend. Any returned actions remain proposals until explicitly confirmed.
**Auth:** Bearer JWT required
**Success:** `200` `AiPlanChatResponse`

**Request body:** `AiPlanChatRequest`

```json
{
  "tripId": "trip_01HX",
  "message": "Can you make day 2 less tiring?"
}
```

**Example response:** `AiPlanChatResponse`

```json
{
  "sessionId": "ai_sess_01HX",
  "message": "I suggest reducing driving on day 2.",
  "actions": []
}
```

**Example usage**

```bash
curl -X POST 'https://api.navio.local/v1/ai/plan/chat' \
  -H 'Authorization: Bearer <JWT>' \
  -H 'Content-Type: application/json' \
  -d '{"tripId": "trip_01HX", "message": "Can you make day 2 less tiring?"}'
```

## Suggested Spring Controller Packages

```txt
user-management-service
  controller/CurrentUserController.java
  controller/UserVehicleController.java
  controller/AdminUserController.java
  controller/AdminUserRoleController.java

trip-planning-service
  controller/TripController.java
  controller/ShareController.java

mobility-service
  controller/GeoController.java
  controller/RouteController.java
  controller/EvRouteController.java
  controller/ChargerController.java
  controller/ChargerReviewController.java
  controller/ChargerCommentController.java
  controller/AdminChargerController.java

community-service
  controller/PostController.java
  controller/GroupController.java
  controller/FeedController.java
  controller/SearchController.java
  controller/NotificationController.java
  controller/MediaController.java

ai-planning-service
  controller/AiPlanController.java
  configuration/AiProviderConfiguration.java
  tool/TripPlanningTools.java
  tool/MobilityTools.java

platform/api-gateway
  configuration/GatewayRoutes.java
  filter/CorrelationFilter.java

platform/configuration-server
  ConfigurationServerApplication.java

platform/discovery-server
  DiscoveryServerApplication.java
```

## Implementation Priority

Destination guides are implemented in User Management. See [Destination guides](destination-guides.md) for the shared ADMIN/OWNER CRUD, versioned writes, publication lifecycle, anonymous published reads and browser-guide import contract.

1. Config Server, Eureka, Spring Cloud Gateway, and production NGINX edge
2. Actuator, structured logs, Micrometer metrics, trace propagation, and Grafana Alloy export
3. Keycloak + User Management + `GET /v1/users/me`
4. User profiles, saved vehicles, role administration, and suspensions
5. Trip CRUD + resource permissions + revisions + visibility
6. Share link + public Explore + copy trip
7. Place/routing APIs + EV charger local DB search + charger detail
8. Charger reviews/reports/suggestions/admin verification
9. Community groups/posts/comments/votes/bookmarks
10. Community media + search + in-app notification module
11. Kafka outbox integration events
12. AI Planning with Spring AI using either Ollama or a hosted provider

Transit route choices also compare earlier alighting followed by walking, using an already confirmed transit prefix and a separate provider-confirmed street walk from the exact station coordinate. Nearby distance is only a prefilter, never proof of a usable connection. Extra walking calls are bounded to two per rail/bus option and reject walks over 2.5 km or 30 minutes; partial-route fares remain unknown. Balanced recommendations consider journey time, walking effort and transfers, and every confirmed alternative remains selectable. The same recommendation rules apply across cities. The provider routing preference follows the [official Routes API transit options](https://developers.google.com/maps/documentation/routes/transit-route).


## Implemented user guides (2026-10-13)

Every authenticated traveler can manage their own guides through `/v1/users/me/guides` (list/create/detail/update/publish/unpublish/delete). Drafts are private; ownership mismatches return 404 and every mutation uses `expectedVersion`. Anonymous discovery at `/v1/traveler-guides` searches the complete published library by title, destination or country and supports exact city, country and provider/destination filters. Published cards include author public profile IDs, display names, avatar media IDs and place counts; documents load on demand. Author fields never include emails or authentication subjects. These routes are separate from admin guides, which retain their existing itinerary placement. See [user-guides.md](user-guides.md) and the OpenAPI paths for request/response details.
