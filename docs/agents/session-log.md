# Session Log

One entry per agent session, **newest first**. Every session adds an entry before it ends, including unfinished or abandoned work. Keep entries factual and short; current state goes in [handoff.md](handoff.md).

## Template

```markdown
## YYYY-MM-DD — <agent> — <short title>

**Goal:** what the user asked for.
**Done:**
- change (repo, branch, commit SHA)
**Verified:** tests/checks run and their result; say what was not verified.
**Not done / left uncommitted:** anything half-finished, with file paths.
**Follow-ups:** decisions pending from the user, known risks.
```

---

## 2026-09-14 — Claude — Finish structured trip location, fix failed release, add agent context

**Goal:** continue Codex's structured trip location work, commit, and deploy.

**Done:**

- mobility-and-ev-service `f4e5493`: place details expose structured city/region/country (`GooglePlaceLocationMapper`).
- trip-planning-service `0e11894`: trips resolve `destinationId` through mobility and store city/region/country code; optional display name with derived `title`; V10 migration; opt-in backfill runner.
- client `19e7bf1`: server-resolved titles and locations; premade plan copy resolves a place id by name; only trip-location files committed (partial commit of `planner-detail.tsx`).
- First release (root `363145a`) failed: trip-planning crash-looped on schema validation of the `char(2)` column; deploy rolled back. Fixed in trip-planning `cb3879c` (`@JdbcTypeCode(SqlTypes.CHAR)` + mapping test); released as root `3fb68c4`, deploy succeeded.
- Added `AGENTS.md` (now committed), `docs/agents/database-changes.md`, `release.md`, `handoff.md`, this log.

**Verified:** mobility 19/19 tests; trip-planning 45/45 including full context against disposable Postgres 16 + PostGIS; reproduced the production failure without the fix. Client type-check and lint pass on the committed file set in isolation. Premade plan copy not tested in a browser.

**Not done / left uncommitted:** ~57 client files from the Codex session (see handoff). Pre-deploy database check in progress.

**Follow-ups:** user decision on uncommitted client work; run the trip location backfill in production.

## 2026-09-14 — Codex — Structured trip location (unfinished)

**Goal:** store structured destination location for trips.

**Done (uncommitted when the session ended):** backend changes in mobility-and-ev-service and trip-planning-service with tests; client migration to the new trip contract, plus unrelated dashboard, sidebar, and theme work in the same working tree.

**Verified:** not recorded.

**Not done / left uncommitted:** two client type errors (`itinerary-section.tsx`, `tests/planner/data.ts`); premade plan copy would have failed trip creation; nothing committed. Picked up by the Claude session above.
