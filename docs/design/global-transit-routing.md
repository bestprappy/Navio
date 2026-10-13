# Transit coverage beyond Google

Status: implemented, enabled and verified in the local app, 2026-10-13. OpenTripPlanner remains disabled by default; local settings enable the verified central Tokyo graph for the shared Mobility service. Production has not enabled it.

## Confirmed cause

Navio previously injected `GoogleRoutesAdapter` as its only `RouteProvider`. It sends worldwide coordinates to the same Google Routes endpoint; there is no application country allowlist to remove. Google's [official FAQ](https://developers.google.com/maps/faq#transit_directions_countries) excludes Japanese transit partners and the Indian Railway Catering and Tourism Corporation from Routes API transit results. Displaying the Google transit map layer does not supply the route calculation API with those journeys.

Read-only POSTs to local `/v1/routes/directions`, with alternatives enabled and general transit rather than rail-only selection, returned:

| Check | Result | Evidence |
| --- | --- | --- |
| Shinjuku station -> Tokyo Skytree, transit | `fallback` | 10,195 m direct distance; null duration; zero steps and journeys; `No public transit route was found` |
| Same Tokyo endpoints, drive | `routed` | 12,212 m; 2,215 seconds |
| Taipei Main Station -> Taipei 101, transit | `routed` | 7,114 m; 1,575 movement seconds; three steps; four journeys |

These checks reproduce the same provider limitation as the user's screenshot. The Shinjuku test uses the station coordinates, not the screenshot's broader Shinjuku City place. Successful driving and Taipei transit show that the local routing integration is operating. The existing UI correctly declines to invent a journey for an empty transit response.

Only Google routing credentials were found in the local configuration. The user confirmed that no additional transit provider access exists. No credentials were printed.

## Data-source decision

The user confirmed no additional provider access and suggested MLIT/open-source data and routing engines. The implemented choice is self-hosted OpenTripPlanner 2.10.0 with published GTFS and OpenStreetMap. The downloaded [MLIT N02 archive](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N02-2023.html) has railway and station GeoJSON, but no timetables or service calendars, so it cannot calculate scheduled journeys alone. Station-only repositories likewise cannot replace schedules. Japan Transfer MCP wraps Jorudan web results rather than supplying an independent open timetable dataset.

The [TokyoGTFS railway dataset](https://github.com/MKuranowski/TokyoGTFS/blob/main/readme.md#railway) and [BBBike Tokyo street extract](https://download.bbbike.org/osm/bbbike/Tokyo/) were downloaded and inspected. The railway feed includes 165 routes and 2,896 stops, with published calendar dates 2026-10-05 through 2027-10-05. To fit the development host, the verified graph selects six complete lines: Toei Oedo/Asakusa/Shinjuku, Tokyo Metro Marunouchi/Hanzomon and JR East Chuo-Sobu Local. Its street bounds are 139.68/35.65/139.84/35.74; 6,239 published trips and their original schedules are preserved. The verification build restricts its service interval to 2026-10-01 through 2026-11-01; the saved graph must be rebuilt for later searches despite the feed's longer calendar. This graph does not establish nationwide Japan coverage.

## Provider options

| Path | Work needed | Coverage limit |
| --- | --- | --- |
| Google plus a licensed Japan provider | Obtain NAVITIME/Jorudan access, implement a backend adapter and provider selection, verify live Japan results | Japan contract scope and the existing providers' coverage elsewhere |
| Google plus a self-hosted open-data engine | Operate OpenTripPlanner or MOTIS, import and refresh GTFS and street data, implement an adapter, verify operator coverage | Only networks and service dates represented by maintained feeds |

[NAVITIME's transit specification](https://api-sdk.navitime.co.jp/api/specs/api_guide/route_transit.html) exposes route sections, departure/arrival search and optional geometry. Authentication, language, timetable entitlement and the contracted operator coverage must be established before relying on live results.

[OpenTripPlanner](https://www.opentripplanner.org/) computes multimodal journeys from GTFS and OpenStreetMap. This avoids purchasing a routing API subscription but still requires feeds, hosting and updates. The [Transitous Japan feed registry](https://github.com/public-transport/transitous/blob/main/feeds/jp.json) includes Japan rail and Tokyo rail sources; this is a candidate inventory, not proof that either source covers the exact journey or has current timetables. Inspect and verify the selected feeds before using them.

The community [Transitous hosted API](https://transitous.org/api/) requires an open-source, noncommercial project and asks developers to contact the maintainers before using routing endpoints. It must not be silently configured as Navio's production fallback. No hosted Transitous routing calls or contacts were made during this investigation.

Licensed providers remain an option for broader Japan coverage if access becomes available. The implemented open-data fallback accepts worldwide coordinates and uses its loaded graph to determine service coverage. No provider can create a scheduled route when the necessary transport data is absent; "all countries" requires maintained regional feeds and verified operator coverage.

## Implemented behavior

- Google remains the primary provider. Empty or failed Google transit searches try configured OTP; road, walking and cycling searches stay with Google.
- Google road, Google transit and OTP have independent circuit breakers. Enabled transit cache keys include the graph revision; a provider outage can retain a stale confirmed route.
- The OTP 2.10 GraphQL adapter maps actual geometry, walking paths, stations, lines, headsigns, transfers, local timezone and scheduled departure/arrival times into the existing response. Unknown fares remain null. Rail/bus restrictions apply to every ride. The graph's available modes are cached so absent bus data does not count as a router outage.
- The planner preserves the selected line/station route through save/reload. OSM attribution appears on both planner map providers and the public Explore map, including when Google supplies the base map.
- The dedicated HTTP client uses HTTP/1.1. OTP's local combined build/save/serve mode left an empty RAPTOR index; the starter builds/saves first and serves from a fresh load process.
- Preparation scripts retain original calendars, metadata and attribution. Local Java startup binds to loopback and records its PID; an optional pinned container overlay exposes no public router port. It is not wired into the normal production deployment.

Setup, source licenses, graph preparation, activation and deployment limits: [self-hosted transit README](../../.deploy/transit/README.md).

## Remaining coverage work

1. Load and validate additional Tokyo operators, Osaka/Kyoto, regional Japan and other required countries. Maintain feed licensing, street coverage, valid dates and refresh jobs. A feed-directory entry is only a candidate.
2. For multiple separately hosted regional graphs, add a coverage-aware registry that bounds attempts and total timeout. The current adapter calls one configured graph, which can itself contain multiple feeds.
3. Add richer diagnostic reasons for unsupported data, expired feeds and outages. The existing API/UI retains unverified straight-line distance and null duration when no journey is confirmed.
4. Add itinerary departure date/time selection in the UI. The API already accepts bounded `departureTime`; current planner requests use the present time.
5. Integrate the optional overlay into deployment, budget resources, establish readiness and graph refresh/rollback, then follow the release checks before production activation.

## Verification

The isolated Mobility API on localhost:18803 uses the real router on localhost:18801, actual local PostgreSQL startup validation and existing Google credentials. It returns four confirmed Shinjuku City -> Tokyo Skytree alternatives with actual walking/rail geometry. General transit and rail requests route; missing bus data and Osaka return unverified empty results. Tokyo drive/walk remain routed, and Taipei/Bangkok transit remain Google journeys.

Backend: 117 tests, zero failures/errors, one ordinary schema-check skip; includes an explicitly enabled live OTP check. Client: whole-project TypeScript, scoped lint and 50 existing transit tests pass. A synthetic-account browser test requests actual API routes while intercepting all trip/account writes: real Tokyo directions, route attribution, selection save/reload and desktop/mobile/light/dark pass. The first parallel browser/test attempt hit host JVM attach/resource failures; serial tests with an explicit Mockito agent and a subsequent browser run pass.

The shared service is now enabled locally. Tokyo Tower -> Shinjuku City returns a confirmed Toei Oedo journey through Mobility 8083, gateway 8080 and actual Next `/api/routes/directions` on 3000; Shinjuku -> Skytree, driving and Taipei transit also pass at the Next boundary. The updated browser regression defaults to this normal app path, with unchanged directions responses and intercepted account/trip writes only. Exact Tower -> Shinjuku directions, source credit, selection/save/reload and desktop/mobile/light/dark pass with 19 real API responses.

Initial automatic review rejected the scoped restart. The user's manual command stopped the old process but exposed a shutdown race: a missing process after a stale port snapshot was falsely treated as a changed owner. The runner now tolerates exited listener/launcher processes, rejects unrelated owners and fails when the port remains occupied. Ten isolated process-operation tests cover the guard. After confirming port 8083 was free, the authorized start succeeded and the app uses OTP. The runner loads three persisted allowlisted OTP settings from local `.env.local`, with shell values taking precedence; explicit false disables it.

Evidence and graph: `C:/Users/User/.codex/tmp/navio-open-transit-20261013/`; activated app checks are `activated-app-regression.json` and `browser-activated/`. Application edits remain uncommitted across Mobility/client/server/root; no schema change or real account/trip write. Production is unchanged.

## Acceptance for additional coverage

- Real Shinjuku -> Tokyo Skytree journeys show provider-confirmed stations, lines, transfers, walks, duration and map geometry; save/reload selects the same line/station sequence.
- Verify another Tokyo route, Osaka/Kyoto and a regional Japan route against the selected source. Record unsupported operators instead of claiming nationwide coverage from a Tokyo-only feed.
- Existing Taipei and Bangkok journeys still work; driving/walking/cycling retain their current provider and behavior.
- Rail-only excludes bus transfers; bus-only excludes rail; unrestricted transit retains mixed journeys.
- Provider timeout, quota rejection, missing configuration, empty results and absent/expired feeds produce distinct truthful outcomes. A failed transit source leaves road routing available.
- Check local service dates, timezones, cross-midnight journeys, source attribution, keyboard operation, light/dark and mobile layout.

Enable additional coverage only after real journeys pass these checks against the corresponding loaded data. The current local Tokyo graph is an integration proof, not a worldwide coverage guarantee.
