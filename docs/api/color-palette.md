# Color palette

Implemented 2026-10-14 on `feat/admin-color-palette` (user-management, trip-planning, server, client, root).

Trip days, lists and guide categories take their color from one admin-managed palette. Travelers pick from it; administrators add colors and remove (retire) them. Nothing is ever deleted and a color's hex never changes, because trips, guides and frozen shared-plan snapshots store only the color id.

## Color ids

- Format `^[a-z][a-z0-9-]{0,39}$`, safe to embed in a CSS custom property name.
- The 24 built-in ids (`teal`, `cyan`, `blue`, … `graphite`) are seeded by user-management `V9__palette_colors.sql` with the same ids the client always used, so every saved trip and guide stays valid.
- An added color gets an id from its name: "Sunset Orange" becomes `sunset-orange`, then `sunset-orange-2` if taken.

## Endpoints (user-management-service)

| Method | Path | Who | Result |
| --- | --- | --- | --- |
| GET | `/v1/palette-colors` | anyone, including guests | `200` every color in picker order: `[{ id, name, hex, retired }]`. Retired colors are included so old trips keep rendering; pickers show only `retired: false`. Bounded to 200 rows. |
| GET | `/v1/admin/palette-colors` | ADMIN, OWNER | `200` `[{ id, name, hex, sortOrder, retired, retiredAt, createdAt, updatedAt }]` |
| POST | `/v1/admin/palette-colors` | ADMIN, OWNER | body `{ name (1–40), hex "#rrggbb" }` → `201` the new color, last in picker order |
| POST | `/v1/admin/palette-colors/{id}/retire` | ADMIN, OWNER | `200`; hides the color from pickers. Idempotent. |
| POST | `/v1/admin/palette-colors/{id}/restore` | ADMIN, OWNER | `200`; offers the color again. Idempotent. |

There is no PUT, PATCH or DELETE. Every change is written to the admin audit log (`PALETTE_COLOR_CREATED`, `PALETTE_COLOR_RETIRED`, `PALETTE_COLOR_RESTORED`, resource type `PALETTE_COLOR`).

Errors use the shared `ErrorResponse`:

| Condition | Status |
| --- | --- |
| invalid name, hex or id format | `400` with `validationErrors` |
| anonymous on an admin route | `401` |
| USER or MODERATOR on an admin route | `403` |
| unknown id | `404` "This color was not found" |
| hex or name already in the palette (including retired colors) | `409` |
| color invisible on the light (`#ffffff`) or dark (`#1b1d24`) surface (contrast below 1.5), 48 active colors already, 200 colors in total, or retiring the last active color | `422` |

The same change also maps two previously unhandled cases in this service: an unknown path returns `404` and an unsupported method returns `405` (both used to return `500`).

## Guides

Guide category `colorId` accepts any palette id format, and saving a guide (admin or traveler) requires every category color to exist in the palette. Retired colors are accepted, so a guide saved before its color was retired stays editable.

## Trips and shared plans (trip-planning-service)

- Planner saves are unchanged: `PlannerBlockDto.colorId` still accepts any string up to 50 characters, so trips holding pre-palette values (the column once stored hex codes) keep saving.
- `PublicDayDto` gains a nullable `colorId`. The sanitizer copies the day's color only when it matches the palette id format; anything else is dropped. `SANITIZER_VERSION` is unchanged, so existing shared links keep working; plans published before this change have no `colorId` and readers fall back to the default sequence until the owner publishes again.

## Gateway

`/v1/palette-colors`, `/v1/admin/palette-colors` and `/v1/admin/palette-colors/**` route to user-management (Config Server and `.deploy/config/api-gateway.yml`). Only `GET /v1/palette-colors` is public; the deploy smoke check expects `200` from it.

## Client

- `PaletteProvider` (root layout) loads the palette once, fills a synchronous registry and publishes `--palette-<id>` and `--palette-<id>-fg` CSS variables. Built-in ids keep their `--planner-block-*` theme tokens.
- `getTripBlockColorById` resolves built-ins, admin colors (CSS variable plus hex for map layers) and falls back to teal for unknown or malformed ids. Map layers use `useTripBlockColorResolver` so they re-render when the palette loads.
- The planner Block options picker and the guide category form show the active palette via `usePaletteOptions`, falling back to the built-in set while loading or if the palette is unreachable.
- New days and lists cycle the familiar defaults, skipping retired ones.
- Admin console: **Color palette** (`/admin/colors`, administrators only) adds colors with a two-theme preview, removes them with Undo, and restores removed colors.
