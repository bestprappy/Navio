# Transit coverage beyond Google

Status: investigation and implementation outline, 2026-10-13. No new provider is enabled.

## Confirmed cause

Navio's Mobility service injects `GoogleRoutesAdapter` as its only `RouteProvider`. It sends worldwide coordinates to the same Google Routes endpoint; there is no application country allowlist to remove. Google's [official FAQ](https://developers.google.com/maps/faq#transit_directions_countries) excludes Japanese transit partners and the Indian Railway Catering and Tourism Corporation from Routes API transit results. Displaying the Google transit map layer does not supply the route calculation API with those journeys.

Read-only POSTs to local `/v1/routes/directions`, with alternatives enabled and general transit rather than rail-only selection, returned:

| Check | Result | Evidence |
| --- | --- | --- |
| Shinjuku station -> Tokyo Skytree, transit | `fallback` | 10,195 m direct distance; null duration; zero steps and journeys; `No public transit route was found` |
| Same Tokyo endpoints, drive | `routed` | 12,212 m; 2,215 seconds |
| Taipei Main Station -> Taipei 101, transit | `routed` | 7,114 m; 1,575 movement seconds; three steps; four journeys |

These checks reproduce the same provider limitation as the user's screenshot. The Shinjuku test uses the station coordinates, not the screenshot's broader Shinjuku City place. Successful driving and Taipei transit show that the local routing integration is operating. The existing UI correctly declines to invent a journey for an empty transit response.

Only Google routing credentials were found in the local configuration. The user confirmed that no additional transit provider access exists. No credentials were printed.

## Available paths

| Path | Work needed | Coverage limit |
| --- | --- | --- |
| Google plus a licensed Japan provider | Obtain NAVITIME/Jorudan access, implement a backend adapter and provider selection, verify live Japan results | Japan contract scope and the existing providers' coverage elsewhere |
| Google plus a self-hosted open-data engine | Operate OpenTripPlanner or MOTIS, import and refresh GTFS and street data, implement an adapter, verify operator coverage | Only networks and service dates represented by maintained feeds |

[NAVITIME's transit specification](https://api-sdk.navitime.co.jp/api/specs/api_guide/route_transit.html) exposes route sections, departure/arrival search and optional geometry. Authentication, language, timetable entitlement and the contracted operator coverage must be established before relying on live results.

[OpenTripPlanner](https://www.opentripplanner.org/) computes multimodal journeys from GTFS and OpenStreetMap. This avoids purchasing a routing API subscription but still requires feeds, hosting and updates. The [Transitous Japan feed registry](https://github.com/public-transport/transitous/blob/main/feeds/jp.json) includes Japan rail and Tokyo rail sources; this is a candidate inventory, not proof that either source covers the exact journey or has current timetables. Inspect and verify the selected feeds before using them.

The community [Transitous hosted API](https://transitous.org/api/) requires an open-source, noncommercial project and asks developers to contact the maintainers before using routing endpoints. It must not be silently configured as Navio's production fallback. No hosted Transitous routing calls or contacts were made during this investigation.

The smallest Japan integration is the licensed-provider adapter once access is available. If avoiding that subscription is a requirement, choose the self-hosted path and validate Tokyo operator coverage first. No provider can create a scheduled route when the necessary transport data is absent; "all countries" should mean extensible provider coverage with explicit gaps, rather than a guarantee that every pair of places has a transit journey.

## Implementation outline

1. Keep the existing provider-independent `TransitJourneyResponse`, steps, route selection and saved route keys. Preserve null schedules/fares when a source omits them.
2. Add a transit provider registry with explicit configured coverage. Use trusted country metadata or service-area geometry, not a rectangular Japan bounding box or a client's unchecked country hint.
3. Preserve Google for driving, walking and cycling. For transit, choose a configured provider that covers both endpoints and the requested service date. Try another eligible source after an empty result or provider failure; bound the attempts and total timeout.
4. Give each provider a separate circuit breaker and cache namespace. A transit source outage must not open the breaker used by Google road routing. Never reuse Google cached emptiness as another provider's answer.
5. Normalize walking, ride/transfer order, exact boarding/alighting coordinates, elapsed time, timezone, fare/currency and geometry into the common response. Retain per-ride validation for rail-only and bus-only requests.
6. Distinguish unsupported coverage, missing provider configuration, provider outage and a valid search with no service. Keep straight-line distance unverified and duration null until a journey is confirmed.
7. Include provider and network identity in new journey keys so identically named lines from different sources cannot collide. Preserve old saved keys and mark unmatched choices unverified after recomputation.
8. Supply the itinerary's date/time and local timezone to the routing search. Do not mistake an overnight gap or a feed outside its valid dates for an unsupported country.
9. Configure server-side credentials or a trusted self-hosted endpoint, source attribution and operational checks. Do not expose secret tokens in client bundles or accept arbitrary provider URLs from route requests.

## Acceptance before enabling coverage

- Real Shinjuku -> Tokyo Skytree journeys show provider-confirmed stations, lines, transfers, walks, duration and map geometry; save/reload selects the same line/station sequence.
- Verify another Tokyo route, Osaka/Kyoto and a regional Japan route against the selected source. Record unsupported operators instead of claiming nationwide coverage from a Tokyo-only feed.
- Existing Taipei and Bangkok journeys still work; driving/walking/cycling retain their current provider and behavior.
- Rail-only excludes bus transfers; bus-only excludes rail; unrestricted transit retains mixed journeys.
- Provider timeout, quota rejection, missing configuration, empty results and absent/expired feeds produce distinct truthful outcomes. A failed transit source leaves road routing available.
- Check local service dates, timezones, cross-midnight journeys, source attribution, keyboard operation, light/dark and mobile layout.

No application source, schema, account or production change was made for this investigation. Provider access or the self-hosted engine/feed choice remains the prerequisite for implementation.
