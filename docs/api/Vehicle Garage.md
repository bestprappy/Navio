# Saved EV garage

The planner garage persists to `iam.user_vehicles` through the authenticated Next.js proxy and user-management service. TanStack Query owns API state; Jotai exposes a read-only projection to the existing route and charging calculations. The selected vehicle is the account's default vehicle, shared across trips. Starting battery, nickname and driver consumption are saved per vehicle. This does not introduce per-trip vehicle snapshots.

The initial catalogue contains three Thailand specifications: BYD ATTO 3 Extended (MY2026), DOLPHIN Extended Range (60.48 kWh), and SEAL Premium RWD (82.56 kWh). The latter two source pages do not establish a model year, so their years are null. All ranges use NEDC. SEAL's AC limit remains null because the cited Thai source does not state its power. Battery values are manufacturer declared; they are not claimed to be usable capacity.

Catalogue records live in `server/user-management-service/src/main/resources/vehicles/thailand.json`. Each has a trim, market, official source URL and verification date. New entries should be checked against their own market and model-year source. Never replace an existing identity with a different trim or battery revision. Do not infer real-world consumption by dividing battery capacity by laboratory range.

The driver enters average consumption to enable route estimates. These are estimates based on that consumption and declared capacity; the current calculator does not model battery degradation, temperature or charge taper. Generated car images are illustrations and are labelled in the UI.

API routes:

- `GET /v1/users/me/vehicles/catalog`: bounded curated catalogue.
- `POST /v1/users/me/vehicles/catalog/{catalogId}`: resolve specifications on the server, save their source snapshot, and select the vehicle. Repeated requests reuse the owned catalogue entry.
- `GET/POST /v1/users/me/vehicles`: list saved cars / create a custom car (25 maximum).
- `GET/PATCH/DELETE /v1/users/me/vehicles/{vehicleId}`: owner-scoped retrieval, changes and soft deletion. Deleting the selected car selects the next remaining car.

Deploy the user-management service with Flyway migration `V2__persist_vehicle_charging_settings.sql` before deploying the matching frontend. Existing records keep their data and receive 80% starting battery; unknown power limits remain null. No external EV API key is required. Authentication and gateway settings are unchanged.

Verification: run the user-management service's `mvnw.cmd -o test`, then `npx tsc --noEmit`, focused ESLint, and `node --experimental-transform-types --test tests/garage/api.test.mjs` from `client`. Browser verification uses mocked HTTP responses; a live PostgreSQL migration check requires the local backend stack.
