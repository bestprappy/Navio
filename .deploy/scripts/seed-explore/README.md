# Explore seed

Publishes 30 real plans to Explore (5 Thailand, 5 Japan, 20 elsewhere) through the
normal API: create trip -> save itinerary -> publish with `listInExplore`. Stops are
resolved to real Google places at run time, so every plan has photos, ratings and
map pins, and opens, renders and copies like an organic plan. The two Thai EV road
trips also pick the fastest real charger near each charging stop.

Itineraries live in `plans.mjs`. The byline defaults to `Navio Team`.

## Requirements

- `SEED_USER_ID`: the Keycloak user id (`sub`) of the account that will own the plans.
  Create a dedicated account (e.g. "Navio Team"), sign in once so IAM provisions it,
  then copy its id from Keycloak admin -> Users.
- Node 20+ (no dependencies).
- Access to trip-planning (`:8082`) and mobility (`:8083`) **directly**. The script
  sends `X-User-Id` the way the gateway does, so never expose those ports to run it.

## Production (on the VM, inside the private Docker network)

```sh
docker run --rm --network navio-backend \
  -v "$PWD/.deploy/scripts/seed-explore:/seed:ro" -w /seed \
  -e SEED_USER_ID=<uuid> \
  -e TRIP_URL=http://trip-planning-service:8082 \
  -e GEO_URL=http://mobility-and-ev-service:8083 \
  node:22-alpine node seed.mjs
```

Try `-e DRY_RUN=1` first: it resolves every place and prints each day without
creating anything.

## Local

```sh
SEED_USER_ID=<uuid> node seed.mjs   # defaults to localhost:8082 / :8083
```

## Options

| env | default | |
| --- | --- | --- |
| `AUTHOR_NAME` | `Navio Team` | byline shown on each plan |
| `START_DATE` | `2026-12-01` | trips start here, 3 days apart (dates are not published) |
| `ONLY` | all | comma-separated slugs, e.g. `jp-kyoto,th-krabi` |
| `DRY_RUN` | off | `1` resolves places only |
| `PAUSE_MS` | `150` | delay between provider lookups |

The original batch skips existing titles. The maintained seasonal/events batch only skips an active, up-to-date Explore publication; an incomplete, unlisted, revoked or changed record stops that item for explicit owner-side inspection. Never automatically republish a revoked plan.
A plan with too few resolved places is not published and the run exits non-zero.

## Cost

About 330 Places Text Search calls (plus the photo lookups the mobility service
does per result) on the production Google key.

## Removing

Sign in as the seed account and use Stop sharing or delete the trips; deleting a
trip cascades its publication.


## Complete maintained sample standard (2026-10-29)

The actual Explore samples are the deliverable. `/preview/shared-plan` is only an optional developer tool; its separate Kyoto fixtures and creation button do not update this collection and are not required for review.

New runs now save and publish Starting Part, an ordered mixed My List (note, checklist and a saved reference), itinerary and budget together. Existing route content is reused, never invented from a preview. The two designated EV examples also include an actual Navio catalogue model as trip-scoped Garage data; other examples remain non-EV. Budget allowances are explicitly illustrative, not quoted prices. Existing real charger stops are preserved; no synthetic charger is added. Future requested examples must follow this complete-source standard.

### Upgrade the existing Navio Team samples in place

`update-existing.mjs` is dry-run by default. It checks exact manifest titles within the known dedicated Team owner, and only updates active, listed publications with the Navio Team byline. It never creates/deletes trips, overwrites itinerary identities, changes the public link, or revives revoked shares. Original snapshots/options are backed up with private filesystem permissions before each save. It uses expected trip versions and publication revisions and stops on error; rerunning merges additions without duplicating them.

Run inside the VM's existing private network using an already installed Node-capable web image. Download/copy this seed folder to a new maintenance directory first. Do not expose internal API ports or change SSH settings.

```sh
# From a maintenance directory containing this folder's scripts:
umask 077
mkdir -p backups
IMAGE=$(docker inspect -f '{{.Config.Image}}' navio-navio-web-1)
docker run --rm --network navio-backend \
  -v "$PWD:/seed:ro" -v "$PWD/backups:/backups" -w /seed \
  -e BACKUP_DIR=/backups --entrypoint node "$IMAGE" update-existing.mjs
# Inspect dry-run results, then first apply one canary:
docker run --rm --network navio-backend \
  -v "$PWD:/seed:ro" -v "$PWD/backups:/backups" -w /seed \
  -e BACKUP_DIR=/backups -e APPLY=1 -e ONLY=th-chiang-mai \
  --entrypoint node "$IMAGE" update-existing.mjs
# After checking the existing link, repeat without ONLY for all maintained samples.
```

There are 30 definitions in this original manifest; any unrelated 31st feed record must remain untouched. Missing/ambiguous/unlisted records are reported and skipped. Backups contain private owned trip data and stay on the VM; do not commit or publish them. If a save succeeds but publication fails, the prior public snapshot stays intact; use the retained backup and rerun after resolving the reported error. Never bypass an ownership/revision check.

Verification: `node --test .deploy/scripts/seed-explore/*.test.mjs` from the repository root covers preservation/idempotence, all definitions, real pinned catalogue identity, non-EV/EV future seed publication, dry-run, same-link updates and unrelated/revoked account guards.


## Seasonal/events batch (2026-11-06)

`SEED_BATCH=seasonal-events` selects 15 additional definitions in `seasonal-events.mjs`; it does not alter the original 30 definitions. The owner must be the existing dedicated Navio Team account. Use `DRY_RUN=1` first, then `ONLY=se-kyoto-autumn` as a canary, then the entire batch. Explicit dates are published as month/day only by the normal sanitizer. All samples contain an original introduction, official planning references, mixed My List, itinerary and illustrative budget; the Bangkok EV example also contains the catalogue Garage vehicle and a mandatory provider-resolved charger. A missing/failed required charger prevents creation.

If using the existing web image for its Node runtime, its default non-root user cannot read a `umask077` maintenance directory. Run the one-shot maintenance container with `--user 0`, mount the exact maintenance directory read-only, and keep the same private `navio-backend` network. This does not change the user or permissions of running application containers.

Recovery: if a request fails after trip creation, retain the reported trip ID. Inspect its owner planner and publication endpoints before retrying. A draft is deliberately **not** counted as a completed sample, silently overwritten, deleted, or automatically republished. Repair the specific owned draft through normal APIs only after distinguishing it from deliberate unlisting/revocation; re-run after its active publication is complete. Compare the public baseline and all 15 new snapshots independently of the runner tally.

Current attempt: dry run blocked by Mobility's Google Places text-search 403 PERMISSION_DENIED, surfaced as 503. No samples were created. Restore the backend Google Places project/key permissions before retrying; do not publish unlocated substitutes or weaken access restrictions. The calendar code is deployed in root027fabc; sample publication remains blocked by provider permissions.
