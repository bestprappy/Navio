# Color palette

Implemented 2026-10-14 on `feat/admin-color-palette` (user-management, trip-planning, server, client, root).

Trip days, lists and guide categories take their color from one admin-managed palette. Travelers pick from it; administrators add colors, choose the label text drawn on each, remove (retire) them, and can delete a removed color for good. A color's hex never changes, because trips, guides and frozen shared-plan snapshots store only the color id.

**2026-11-02 (user-management V12):** per-theme label text and permanent deletion. Deleting reserves the id in `iam.deleted_palette_colors`; everything saved with it renders the default color (teal), and no new color can take the id over. Teal itself cannot be deleted.

## Color ids

- Format `^[a-z][a-z0-9-]{0,39}$`, safe to embed in a CSS custom property name.
- The 24 built-in ids (`teal`, `cyan`, `blue`, … `graphite`) are seeded by user-management `V9__palette_colors.sql` with the same ids the client always used, so every saved trip and guide stays valid.
- An added color gets an id from its name: "Sunset Orange" becomes `sunset-orange`, then `sunset-orange-2` if taken or deleted.

## Endpoints (user-management-service)

| Method | Path | Who | Result |
| --- | --- | --- | --- |
| GET | `/v1/palette-colors` | anyone, including guests | `200` every color in picker order: `[{ id, name, hex, retired, deleted, textOnLight, textOnDark }]`. Retired colors are included so old trips keep rendering; pickers show only `retired: false`. Up to 200 colors, then each deleted id with `deleted: true`, `retired: true`, name "Deleted color" and teal's hex (older clients therefore draw it in teal too). |
| GET | `/v1/admin/palette-colors` | ADMIN, OWNER | `200` `[{ id, name, hex, sortOrder, retired, retiredAt, createdAt, updatedAt, textOnLight, textOnDark }]`; deleted colors are not listed |
| POST | `/v1/admin/palette-colors` | ADMIN, OWNER | body `{ name (1–40), hex "#rrggbb", textOnLight?, textOnDark? }` (`auto`, `white` or `black`, default `auto`) → `201` the new color, last in picker order |
| PATCH | `/v1/admin/palette-colors/{id}` | ADMIN, OWNER | body `{ textOnLight, textOnDark }` → `200`; name and hex stay fixed |
| DELETE | `/v1/admin/palette-colors/{id}` | ADMIN, OWNER | `204`; only a retired color, never teal |
| POST | `/v1/admin/palette-colors/{id}/retire` | ADMIN, OWNER | `200`; hides the color from pickers. Idempotent. |
| POST | `/v1/admin/palette-colors/{id}/restore` | ADMIN, OWNER | `200`; offers the color again. Idempotent. |

There is no PUT and no name or hex edit. Every change is written to the admin audit log (`PALETTE_COLOR_CREATED`, `PALETTE_COLOR_TEXT_CHANGED`, `PALETTE_COLOR_RETIRED`, `PALETTE_COLOR_RESTORED`, `PALETTE_COLOR_DELETED`, resource type `PALETTE_COLOR`).

Errors use the shared `ErrorResponse`:

| Condition | Status |
| --- | --- |
| invalid name, hex or id format | `400` with `validationErrors` |
| anonymous on an admin route | `401` |
| USER or MODERATOR on an admin route | `403` |
| unknown id | `404` "This color was not found" |
| hex or name already in the palette (including retired colors) | `409` |
| color invisible on the light (`#ffffff`) or dark (`#1b1d24`) surface (contrast below 1.5), 48 active colors already, 200 colors in total, retiring the last active color, deleting a color still in the palette, or deleting teal | `422` |

The same change also maps two previously unhandled cases in this service: an unknown path returns `404` and an unsupported method returns `405` (both used to return `500`).

## Guides

Guide category `colorId` accepts any palette id format, and saving a guide (admin or traveler) requires every category color to exist in the palette. Retired and deleted colors are accepted, so a guide saved before its color was retired or deleted stays editable; readers draw a deleted color as teal.

## Trips and shared plans (trip-planning-service)

- Planner saves are unchanged: `PlannerBlockDto.colorId` still accepts any string up to 50 characters, so trips holding pre-palette values (the column once stored hex codes) keep saving.
- `PublicDayDto` gains a nullable `colorId`. The sanitizer copies the day's color only when it matches the palette id format; anything else is dropped. `SANITIZER_VERSION` is unchanged, so existing shared links keep working; plans published before this change have no `colorId` and readers fall back to the default sequence until the owner publishes again.

## Gateway

`/v1/palette-colors`, `/v1/admin/palette-colors` and `/v1/admin/palette-colors/**` route to user-management (Config Server and `.deploy/config/api-gateway.yml`). Only `GET /v1/palette-colors` is public; the deploy smoke check expects `200` from it.

## Client

- `PaletteProvider` (root layout) loads the palette once, fills a synchronous registry and publishes `--palette-<id>` and `--palette-<id>-fg` CSS variables (`-fg` overridden under `.dark` when the dark-theme label differs). A deleted id's variables point at teal's. Built-in ids use `var(--palette-<id>, var(--planner-block-<id>))`, so label choices and deletion apply to them too.
- `getTripBlockColorById` resolves built-ins, admin colors (CSS variable plus hex for map layers) and falls back to teal for deleted, unknown or malformed ids. Map layers use `useTripBlockColorResolver` so they re-render when the palette loads.
- The planner Block options picker and the guide category form show the active palette via `usePaletteOptions`, falling back to the built-in set while loading or if the palette is unreachable.
- New days and lists cycle the familiar defaults, skipping retired ones.
- Admin console: **Color palette** (`/admin/colors`, administrators only) adds colors with an inline picker (saturation area, hue track, screen eyedropper where supported, HEX/RGB/HSL fields), a label-text choice (automatic, white, black, or white/black per theme) with a low-contrast warning and a two-theme preview; edits label text on existing colors; removes them with Undo; restores removed colors; and deletes removed colors after a confirmation. The picker is the reusable compound `components/color-picker`.
