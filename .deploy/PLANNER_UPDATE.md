# Planner UI and settings release

Prepared: 2026-09-09. No VM changes have been made by this task.

Updated: 2026-09-10. The client can now save ordinary itinerary edits against the older service while keeping unsupported destination changes and charge targets on the same device. The service update is still required for cross-device settings sync and optimization with those settings.

This release includes the client, `server/trip-planning-service`, and `server/mobility-and-ev-service`. The database migration is bundled in the trip service as `V8__day_destinations_and_charge_targets.sql`.

## Prepare the release

1. Review the `feat/planner-ui-refinement` branches in the affected repositories. Integrate child commits before their server/root pointers, and use the final integrated root revision as the release identifier. Preserve environment files and local logs.
2. Build and publish the matching images using the project's existing image pipeline. Production Compose uses one `NAVIO_IMAGE_TAG`, and `scripts/deploy.sh` requires a full 40-character release commit SHA.
3. Take the team's normal PostgreSQL backup and retain the previous image tag. Test V8 on a database copy before production; database migration execution remains pending.

## Deployment order

Deploy the new mobility service first, then the trip service, and then `navio-web`. This ensures that once the trip service advertises charge-target support, mobility already honors those targets. Confirm service health at each step. Use the existing deployment tooling and the reviewed release tag; preserve `/opt/navio/.env` and TLS files. This feature requires no new credentials or environment variables.

If deploying selected services manually, the Compose service names are `mobility-and-ev-service`, `trip-planning-service`, and `navio-web`. The existing full-stack deploy script also changes platform configuration; review that wider scope before using it for a selective release.

The trip service applies V8 through Flyway on startup. Confirm migration success and Hibernate schema validation before opening the updated planner to users.

## Authenticated smoke test

1. Sign in through the university network/VPN as required. Open an existing trip and verify its old stops and expenses remain intact.
2. Rename the trip and reload. Set a new destination halfway through its dates; later suggestions should follow it while existing stops remain.
3. Change the first day's destination. Verify the trip destination changes, but the later explicit destination still applies from its date onward.
4. Add a charging station: its target starts at 100%. Set it to 80%, reload, and confirm the target on another device. Add/select an EV to verify route-dependent charging estimates.
5. Run optimization and confirm it retains a station with an explicit target and honors that target.
6. Verify the snapshot response advertises both capabilities. Check that the planner reaches its saved state without conflicts after renaming and editing stops.
7. Check desktop community center scrolling, planner drawer dragging, phone/tablet layout, and both themes. Drag the charging slider and confirm the card stays still; then drag the card using its handle.
8. Create a multi-day trip and confirm every date appears automatically. Rename it from the trip list, verify multiple destination labels, and confirm planner Explore groups match the selected destinations.

## Rollback

V8 adds nullable columns and can remain installed during a code rollback. Do not drop the new columns as a routine rollback. Older services can ignore and potentially erase new settings when rewriting snapshots; pause planner edits during a rollback, retain the backup, and restore the matching client/service release before resuming edits that depend on these fields.

See [API contract](../docs/api/Planner%20destination%20and%20charging%20settings.md) for field semantics and local test coverage.
