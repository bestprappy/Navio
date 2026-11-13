# EV planner real run - 2026-11-04

Step 4 of the EV plan: real trips, not mocks. A real browser signed in through Keycloak and went through the Next proxy, gateway, trip and mobility services to live Google Places and Routes, saving to a disposable PostGIS database. Code ran from clean worktrees of `dev`. Community and MinIO were not running, so notification requests returned 503; those are excluded below.

Test vehicle: 60 kWh usable, 18 kWh/100 km, CCS2, 150 kW DC, user-observed consumption, 12% reserve. Thai routes. Calls were counted by a local forwarding proxy, which never stored the API key.

## Results

| # | Scenario | Result | Evidence |
| 1 | Two connected days, both need charging (EV-15) | **Pass** after three fixes below | Bangkok to Chumphon: one stop to 95%, warns that a later day needs charging. Chumphon to Phuket then plans two stops. Both saved and reloaded. |
| 2 | Disconnected Day 2 (Phuket), no start | **Pass** | Day 1 plans. Preview and planner both show "Day 2 doesn't start where the day before it ends, so its charge wasn't checked." Day 2 is refused until it has a reading at its first stop, then plans from it. |
| 3 | Return trip, two visits to one station (EV-20) | **Pass** | Both visits survive apply and reload with their own targets, 95% and 80%. Postgres shows both rows. |
| 4 | Kept stop with saved charge (EV-18) | **Pass** | Locked stop with a saved 95% target: no added charger, and re-preview twice says "already efficient". |
| 5 | Trip saved in the old format | **Pass, simulated** | Old-format stops planned and opened with no errors. This was a saved old shape, not a real pre-fix database dump. |
| 6 | Route over about 960 km | **Pass** after one fix | Hat Yai to Chiang Rai, about 1,500 km: plans seven stops and now warns that coverage was reduced. It used all 48 search points. |
| 7 | Clicking Plan and Apply in the browser (added) | **Pass** | Panel reads "Add EA Anywhere Charging Station (17 min)" with the warnings. Apply saves it and it survives a reload. |

## What the run found that mocks could not

All were fixed test-first and merged to `dev`, except the last row.

| Finding | Cause | Effect before the fix |
| --- | --- | --- |
| Search limit on any real corridor | Labels with different visited stations could not prune each other | Bangkok to Chumphon had no plan at all. The same code is on `main`. |
| Crash on stations with no `openNow` | `Map.copyOf` rejects the null values Google omits fields as | Plans choosing such a station failed as "temporarily unavailable". Code from 2026-08-29, also on `main`. |
| Day ended at reserve, next day stuck | Cheapest plan finished at 12.1% against a 12% reserve | Day 2 could reach no charger, so the deadlock was only half fixed. |
| First fix added a pointless stop | "Most battery" picked a second stop just before the destination | Charging rose from 17 to 42 minutes. Now it keeps the same stops and charges longer. |
| Re-preview flipped 95% back to 85% | Pruning dropped "same stop, charged longer" | Saved plan changed for no reason. |
| Long route thinned silently | 48-point cap with no message | Coverage dropped with no warning. |
| `/help` returns 404 (not EV, not fixed) | Sidebar links to a page that does not exist | Seen on every page as a failed prefetch. |

## Preview versus apply (step 5)

Every applied stop matched its preview on station, target and minutes in all scenarios. The one `match: False` in the raw output was the comparison script matching two visits by station; the saved rows are correct.

**Not tested:** Google data or traffic changing between preview and apply. Apply recomputes the plan, so this could still differ, and each run here read from the same cache. No guard was added, as the plan says; it needs the user's decision.

## Calculate times versus "Takes" (EV-30 evidence)

A manual stop saved with a 50-minute rough estimate and a 100% target had a real charge time of 23.9 minutes once the optimizer recalculated it. Calculate times uses the saved 50.

## Cost and latency

- Total for the whole run including repeats after restarts: 425 Places and 83 Routes calls.
- A first preview of a 466 km day: 25 Places and 9 to 11 Routes calls, about 3.5 to 4 seconds.
- A first preview at the 48-point cap: 48 Places and 9 Routes calls, about 5 seconds.
- Apply and a second preview of the same day: 0 Places calls. Mobility's cache is in memory, so restarts lose it.
- Opening the manual station list on a 466 km day: 17 to 18 Places calls.
- Sampling every 20 km rather than 30 km, and trying up to 8 plans, are acceptable on this evidence, but only the user can set a budget.

## Limits

- One machine, one account, one vehicle profile, Thailand only, one day of Google data.
- All three seeded catalogue cars are rated-range only, so automatic apply is preview-only for them. This run used a user-observed consumption profile.
- Regression tests for these findings use synthetic data shaped like the real responses, not recorded payloads. No live calls run in tests.
- Restarting a service leaves the gateway returning 503 "No servers available" for up to a minute. That caused 503s during this run and is a local artifact; rechecks passed after it settled.
- Memory: the full stack cannot run alongside a Maven test run on this 16 GB machine; JVMs crashed with `insufficient memory` until the stack was stopped.
