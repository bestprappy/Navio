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

Re-running is safe: plans whose title already exists for the seed user are skipped.
A plan with too few resolved places is not published and the run exits non-zero.

## Cost

About 330 Places Text Search calls (plus the photo lookups the mobility service
does per result) on the production Google key.

## Removing

Sign in as the seed account and use Stop sharing or delete the trips; deleting a
trip cascades its publication.
