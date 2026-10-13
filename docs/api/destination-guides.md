# Destination guides

User Management owns the shared guide library in `iam.guides`. ADMIN and OWNER can create, read, edit, publish, unpublish and delete every guide, including guides created by another admin. Creator/editor IDs are attribution, never ownership filters. MODERATOR and USER cannot manage guides. Travelers, including anonymous visitors, read published guides only.

| Method | Route | Result |
| --- | --- | --- |
| GET | `/v1/admin/guides?term=&status=&page=0&size=50` | Page of summaries, including drafts; optional name/country search and DRAFT/PUBLISHED filter |
| POST | `/v1/admin/guides` | Create a draft; body `{ "guide": <fields> }`; 201 |
| GET | `/v1/admin/guides/{id}` | Full guide and version; 200 |
| PUT | `/v1/admin/guides/{id}` | Replace authored fields; body `{ "expectedVersion": 0, "guide": <fields> }`; 200 |
| POST | `/v1/admin/guides/{id}/publish` | Body `{ "expectedVersion": 0 }`; requires at least one resolved place card; 200 |
| POST | `/v1/admin/guides/{id}/unpublish` | Body `{ "expectedVersion": 0 }`; return to draft; 200 |
| DELETE | `/v1/admin/guides/{id}?expectedVersion=0` | Delete for all admins and travelers; 204 |
| GET | `/v1/guides?page=0&size=50` | Published full guides only; anonymous; 200 |
| GET | `/v1/guides/{id}` | Published full guide; drafts/missing guides return 404 |

Page size is 1–100; page is nonnegative. Lists use deterministic country/name/ID ordering. The frontend follows every page, rather than silently omitting guides after the first 100. The Next.js proxies are `/api/admin/guides` and `/api/guides`; path and method allowlists prevent arbitrary forwarding.

Authored fields are:

```json
{
  "name": "Chiang Mai",
  "country": "Thailand",
  "countryCode": "TH",
  "destination": { "provider": "GOOGLE", "providerPlaceId": "ChIJ-city", "name": "Chiang Mai", "lat": 18.79, "lng": 98.98 },
  "description": "A guide written by the Navio team.",
  "coverPlaceId": "GOOGLE:ChIJ-city",
  "content": {
    "categories": [{ "id": "visit", "name": "Places to visit", "iconId": "landmark", "colorId": "blue" }],
    "lists": { "visit": { "id": "visit", "categoryId": "visit" } },
    "places": {},
    "body": "<div data-embed=\"placeList\" data-list-id=\"visit\"></div>"
  }
}
```

`content.body` is block-editor markdown. `placeList` markers start sections; `guidePlace` markers use `data-place-id` to identify the place in `content.places`. Document order determines which section a card belongs to. A place contains provider/name/address/coordinates, optional primaryType/category and up to six 24-character tags. Photos, ratings and opening hours are fetched live, rather than frozen into guide content. Country code is nullable. DTO limits include title 120 characters, description 4,000, body 200,000, 30 categories, 200 lists and 600 remembered places.

The full admin response contains `id`, `status`, `version`, `guide` (fields above), timestamps (`createdAt`, `updatedAt`, nullable `publishedAt`) and nullable `createdByName`/`updatedByName`. A summary contains destination identifiers, title, country, cover, status, version, place count, used categories, update/publication timestamps and last editor name. A public response contains only `id`, `guide`, `publishedAt` and `updatedAt`.

Each destination has one guide, enforced by a database unique index on provider/place ID. Stale writes, publication changes and deletes return 409; missing guides return 404; invalid DTO fields return 400; invalid document relationships or empty publication return 422. Frontend autosave retains in-flight edits, uses the version returned by each save before publishing/deleting, and stops after a conflict until the admin explicitly reloads the latest guide. Activity records include creation, throttled edits, publication changes and deletion; only summary fields are exposed through the admin activity API.

V7 is additive and seeds the original Bangkok guide as published with 24 places. Existing browser-only guides are not automatically uploaded: the admin dashboard offers **Import browser guides** for missing destinations. Import creates shared drafts without overwriting an existing server guide and leaves browser copies intact. Browser guides on another device must be imported from that device.
