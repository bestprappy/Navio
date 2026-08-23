# Navio API Documentation

**Version:** v1.3
**Base URL:** `https://api.navio.local`
**Auth:** Bearer JWT from Keycloak for all endpoints except `GET /v1/share/{token}`.
**Development entry:** `http://localhost:8080` through Spring Cloud Gateway
**Architecture:** Production NGINX forwards `/v1/**` to the same Spring Cloud Gateway used in development. The gateway resolves four core services and optional AI Planning through Eureka. Non-secret gateway/service configuration comes from Config Server. Keycloak is the Identity Provider. AI inference is selected by configuration: Ollama on the ML VM or a hosted model API through Spring AI.

## Global API Rules

- All public APIs use `/v1`.
- Default response format is JSON.
- Default authentication is `Authorization: Bearer <access_token>`.
- Use `X-Request-Id` for frontend-to-backend correlation.
- Propagate W3C `traceparent`/`tracestate`; responses may expose a safe request ID for support.
- Error responses use `ErrorResponse`.
- Admin/moderator endpoints require `MODERATOR` or `ADMIN` role.
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

### User and role management extensions

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/v1/users/{userId}` | Get a public Navio profile. |
| `GET` | `/v1/users/me/vehicles` | List the current user's saved vehicles. |
| `POST` | `/v1/users/me/vehicles` | Add a saved vehicle. |
| `PATCH` | `/v1/users/me/vehicles/{vehicleId}` | Update nickname, battery defaults, or default selection. |
| `DELETE` | `/v1/users/me/vehicles/{vehicleId}` | Remove a saved vehicle. |
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

### `DELETE /v1/posts/{postId}/comments/{commentId}` — Delete post comment

**Does:** Deletes own comment or moderator/admin deletes it.
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
