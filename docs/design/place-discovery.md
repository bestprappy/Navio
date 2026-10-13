# Place discovery

Status: proposal. A frontend-only prototype with mock data exists for Bangkok (see "Prototype" at the end); the backend in this note is not built.

## Goal

Show the popular places in a destination, such as Taipei, in three groups: **Sights**, **Eat** and **Do**. A traveller can add any of them to a day of their trip.

This is separate from shared plans:

| | Shared plans (exists) | Place discovery (this note) |
|---|---|---|
| Unit | A whole trip another user published | One place |
| Source | Navio database, community-service | Google Places, fetched live |
| Example | "5-day Taipei road trip" | Taipei 101, Raohe Night Market, Din Tai Fung |

## Why Google Places

- Mobility already integrates Google Places. `GooglePlacesAdapter` calls Text Search and Nearby Search and requests `rating`, `userRatingCount` and `primaryType`.
- Planner items already store Google place IDs. A discovered place can go into a day with no conversion and appears on the existing place cards.
- `PlaceService` already wraps provider calls in an in-memory cache (15 min fresh, 24 h stale fallback) and a circuit breaker.
- Other sources (Foursquare, TripAdvisor Content API, OpenTripMap) would need matching to Google IDs. Reconsider them only if cost becomes a problem.

## Backend: mobility-and-ev-service

### Endpoint

```
GET /v1/geo/places/discover?destination=Taipei&lat=25.033&lng=121.565&category=SIGHTS
```

| Param | Rule |
|---|---|
| `destination` | Required. 2 to 120 characters, the destination's display name |
| `lat`, `lng` | Required together. The destination's centre, used as the location bias |
| `category` | `SIGHTS`, `FOOD` or `ACTIVITIES` |

The response reuses `PlaceSearchResponse` (`items: PlaceDetailResponse[]`), so the client parser and `placeDetailToSearchResult` work unchanged. A later version adds an optional photo reference per item (see Photos).

- **Route collision:** `/discover` is a literal segment beside `/{providerPlaceId}`. Add a `@WebMvcTest` asserting that `/discover` reaches `discover()` and never `getDetail()` (see `.claude/rules/server/api-conventions.md`).
- **Auth:** the gateway already requires a JWT for `/v1/geo/places/search` and `/nearby`; only `GET /v1/geo/places/{placeId}` is public. Keep `/discover` authenticated in the same way, and add a case to `GroupPublicRoutesTest` asserting an anonymous call gets `401`. A public endpoint would let anonymous traffic spend Google quota with arbitrary destinations.

### Category to Google query

Each category is one Text Search (New) request with `locationBias` as a circle around `lat`/`lng` (about 20 km) and `pageSize` 20.

| Category | `textQuery` | `includedType` |
|---|---|---|
| `SIGHTS` | `top tourist attractions in {destination}` | `tourist_attraction` |
| `FOOD` | `best restaurants in {destination}` | `restaurant` |
| `ACTIVITIES` | `things to do in {destination}` | none |

`ACTIVITIES` has no type filter because Google has no confirmed type for things like night markets. Text Search accepts a single `includedType`, and `strictTypeFiltering` makes it exclusive. Set `languageCode` from the user's locale, defaulting to `en`, or Taipei results may come back in Chinese.

### Ranking "popular"

Google returns no popularity value. Results arrive in relevance order, which leans towards well-known places. On top of that:

1. Drop places with fewer than a minimum number of ratings: `SIGHTS` 200, `FOOD` 100, `ACTIVITIES` 100. These are starting values to tune against real results.
2. Sort the rest by a Bayesian average, `(C * m + rating * n) / (C + n)` with prior mean `m = 4.0` and weight `C = 200`. A 4.9 rating with 12 reviews no longer beats a 4.5 with 40,000.
3. Use Google's order as the tie-break.

Put the constants in one `PlaceDiscoveryRanking` class. Its `*Tests` cover the threshold boundary, the prior pulling down low-count places, ties and an empty result. Also test category mapping and the cache key (`discover:{category}:{normalized destination}:{rounded lat}:{rounded lng}:{lang}`).

### Code shape

- `PlaceProvider.discover(query, includedType, lat, lng, languageCode)`, implemented in `GooglePlacesAdapter` with its own field mask
- A `PlaceDiscoveryService` that maps the category, calls the provider through the existing `cachedSearch` path and applies the ranking
- A `PlaceDiscoveryCategory` enum
- Provider failures map as the existing search does: `503` when the provider is unavailable and nothing is cached
- Add the endpoint and its error model to `docs/api/Navio Open API.yaml`

No entity, migration or database change.

## Frontend

### Shared pieces

Folder: `client/app/feature/discover/`

- `discover-api.ts`: fetches `/api/geo/places/discover` and checks the response shape, mirroring `liveSearch` in `place-api.ts`
- `use-discover-places.ts`: a TanStack Query hook keyed on `["discover", destination, lat, lng, category]` with `staleTime` 15 min to match the server cache
- `data.ts`: typed mock results for development
- Proxy: `client/app/api/geo/places/discover/route.ts`, copying `search/route.ts`

Cards reuse `PlaceCardVisual`, which the planner and Explore already share. Category switching uses shadcn `Tabs` or a toggle group, with keyboard support and a visible selected state.

### In the planner

Add a "Top places in {destination}" carousel under the existing shared-plan carousel in `explore-section.tsx`. Clicking a card calls `startPlaceSearchAtom` with the discovery results, the selected index and the active day's `blockId`. That opens the existing place preview panel with its Add flow, so no new add-to-day logic is needed. With no active day, use the first day.

### On /explore

Add tabs, **Shared plans** and **Places**. Places needs a destination picker, which reuses the planner's destination autocomplete (`destination-api.ts`). Signed-out visitors see a sign-in prompt in the Places tab instead of results, matching the endpoint's auth.

Every list has loading (Skeleton), error (retry) and empty states, and sits inside `ExploreErrorBoundary`.

## Photos

The current search field mask has no photos, so search results have no images. Discovery cards need one.

- Add `places.photos` to the discovery field mask and return the first photo's resource name plus its `authorAttributions`.
- A new proxy route turns a photo name into an image through the media endpoint, as `GooglePlacesAdapter.loadPhotoUrl` does. Load images lazily as cards scroll into view. Each image is a separately billed call.
- Show the photo's author attribution on the card. Show "Google Maps" attribution wherever Places data appears without a Google map.

## Cost and Google terms

| Item | Detail |
|---|---|
| Billing tier | Requesting `rating`/`userRatingCount` bills Text Search at the Enterprise tier: 1,000 free calls a month, then about $35 per 1,000 |
| Photos | Each photo media request is billed separately |
| Exposure | One call per destination × category × language per 15 min, because the existing cache absorbs repeats. Authentication keeps anonymous traffic out |
| Storage | Place IDs may be stored. Names, ratings, addresses and photos may not be stored persistently. Coordinates may be cached for up to 30 days. The in-memory cache with its 24 h stale fallback is the only copy |

Confirm the exact tier of each field in the Places data-fields table before choosing the field mask. In particular, check whether `photos` or `editorialSummary` raises the tier.

## Later: a Navio popularity signal

Trip-planning-service already holds every planned place's Google place ID. Counting how many trips include each place gives "Popular with Navio travellers". This is Navio's own data, so it can be stored and ranked freely. It needs a read model in trip-planning-service, so it is out of scope for the first version.

## Open questions

1. Should signed-out visitors see places on /explore? If so, the endpoint needs a public, rate-limited variant whose cache key space is bounded, for example by accepting only a destination place ID.
2. Photos in the first version, or text cards first?
3. Should the default language follow the user's locale or always be English?

## Unverified at the time of writing

- Nearby Search's `POPULARITY` rank preference is not used here; it was not confirmed in current documentation.
- No `night_market` or `food_court` type was confirmed in Table A, which is why `ACTIVITIES` has no type filter.
- The billing tier of `photos` and `editorialSummary` in Text Search.

## Prototype (frontend only, mock data)

Code: `client/app/feature/planner/planId/_components/guide/`. The direction changed from live Google discovery to curated guides, and this prototype follows the curated model.

- **Data:** `data.ts` holds one guide (Bangkok) with three sections of eight places: Places to visit, Top places to eat, Places to stay. Each place stores its Google place ID, name, address, coordinates, Navio's own description and tags. Photos and ratings are never stored; each card loads them through the existing public place-detail endpoint.
- **Which days show it:** a day shows **Popular places in {city}** only when its destination matches a guide, by place ID or by name (`findDestinationGuide`). Samut Prakan, for example, shows nothing.
- **Day card:** a shadcn Carousel of nine portrait cards (photo, name, two tags), taking the top place of each section in turn. The + button adds the place to that day. Clicking a card opens the guide on that place. **Browse all** opens the guide.
- **Guide view:** it replaces the planning drawer, which stays mounted but hidden so its state survives; scroll position and focus come back on return. It has a cover photo (Wat Arun, loaded live), a description, section jump buttons, and per section five rows with Show more, See all and Show less. Each row has a pin number, live rating, type, tags, a photo and **Add to {day}**. Escape or **Back to planning** returns to the plan.
- **Map:** shows numbered pins in each section's colour for the listed places only. The trip's pins are dimmed and its routes hidden while browsing. Selecting a row or a pin opens the existing place preview, with Previous/Next within the section and Add to trip.
- **Limits:** Google map only (Mapbox has no guide pins), and one hard-coded guide. Moving to the backend means replacing `DESTINATION_GUIDES` with a TanStack Query fetch of the guide by destination.
