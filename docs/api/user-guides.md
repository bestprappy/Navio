# User guides

User Management owns `iam.user_guides`, added by V8. Every authenticated role can write guides, but every private read and mutation requires the resolved owner. Being an admin does not grant access to another traveler's drafts. Ownership failures and missing rows return the same 404. Request DTOs contain no owner field.

| Method | Route | Result |
| --- | --- | --- |
| GET | `/v1/users/me/guides?term=&status=&page=0&size=20` | Page of this caller's summaries, including drafts |
| POST | `/v1/users/me/guides` | `{ "guide": <DestinationGuideFields> }`; creates a private draft, 201 |
| GET | `/v1/users/me/guides/{id}` | Owner-only full guide, status, version and timestamps |
| PUT | `/v1/users/me/guides/{id}` | `{ "expectedVersion": 0, "guide": <fields> }`; replace authored fields |
| POST | `/v1/users/me/guides/{id}/publish` | `{ "expectedVersion": 0 }`; requires a resolved place card |
| POST | `/v1/users/me/guides/{id}/unpublish` | `{ "expectedVersion": 0 }`; makes the guide private again |
| DELETE | `/v1/users/me/guides/{id}?expectedVersion=0` | Owner-only version-checked deletion, 204 |
| GET | `/v1/traveler-guides?term=&city=&country=&destination=&page=0&size=20` | Published card summaries only, readable anonymously |
| GET | `/v1/traveler-guides/{id}` | Published document only; private/missing guides return 404 |

Fields, content relationships and size limits match [destination guides](destination-guides.md). Users may create multiple guides per destination. Version conflicts return 409; invalid fields/filters return 400; invalid document relationships or empty publication return 422. Public responses contain `author: { id, displayName, avatarMediaId }`, using the existing public profile UUID and current avatar reference, and never an email or auth subject. The picture is served by the existing anonymous-readable `/v1/users/{id}/picture` endpoint. Missing profiles use a Traveler byline with null identity/avatar; profiles without a picture show initials. Authors are fetched in one batch per discovery page.

Public search matches title, canonical destination name and country case-insensitively, escaping SQL wildcard characters. `country` matches an exact name or ISO code, including existing country-wide guides whose destination is that country and whose country field was left empty. New country guides infer their country from the selected destination when autocomplete omits secondary text. Repeated `city` values match exact destination names; repeated `destination` values identify `GOOGLE:<id>` or `MAPBOX:<id>`. Cities and identities are ORed together; country and term are ANDed. Up to 30 locations per filter; page size 1–100. Public ordering is publication date descending then UUID; the private library uses update date descending then UUID. Both endpoints return Spring page metadata.

Next.js forwards only allowlisted methods and UUID/publication paths through `/api/users/me/guides` and `/api/traveler-guides`, using the shared session and cross-origin mutation protections. Public collection responses are compact summaries; documents are fetched when opened. TanStack Query keys and Jotai editor drafts are isolated by account. Autosave preserves edits made during a request and flushes all outstanding edits before publishing, deleting or leaving through the editor's back link. Conflicts stop autosave until explicit reload.

UI routes are `/dashboard/guides` (library), `/dashboard/guides/{id}` (shared editor) and `/explore/guides/{id}` (public reader). Dashboard ordering is Explore plans, Your Guides, Explore guides. There is no Your Guides sidebar item. `/explore?tab=guides` selects guide discovery and `term` prefills the country/city/title search. Trip Explore groups itinerary destinations by country and displays all published guides for each visited country, including other cities and country-wide guides. It falls back to provider/city matching only when the country is unavailable. The public reader fills the viewport with an independently scrolling document and resizable fixed map; mobile offers Guide/Map controls. Admin guide APIs and the itinerary's Navio team guide slot remain separate.
