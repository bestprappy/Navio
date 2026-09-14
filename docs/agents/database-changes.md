# Changing the Database Safely

Read this before adding a migration, changing an entity, or renaming anything that maps to a column. A schema mistake does not fail the build — it fails production, after the images are built.

## How production treats the schema

- One PostgreSQL 16 + PostGIS instance. Each service owns its schemas and must never read or write another service's tables.
- On startup each service runs **Flyway first**, then Hibernate with **`ddl-auto: validate`**. Validation compares every mapped column's type with the real database and refuses to start on any mismatch.
- `validate-on-migrate` is on: editing a migration that already ran changes its checksum and stops the service.
- `.deploy/scripts/deploy.sh` waits for every container to be healthy. If one is not, it **rolls back to the previous image tag**. The new migration **stays applied**, so the previous release must still work against the new schema. (Flyway ignores applied migrations newer than the code by default.)
- Production has real user data. Every migration runs against existing rows.

## Who owns what

| Service | Schemas | Migrations | Latest (2026-09-14) |
| --- | --- | --- | --- |
| user-management-service | `iam` | `src/main/resources/db/migration` | V4 |
| trip-planning-service | `trip` | `src/main/resources/db/migration` | V10 |
| mobility-and-ev-service | `ev` | `src/main/resources/db/migration` | V1 |
| community-service | `social`, `notif`, `media` | `src/main/resources/db/migration` | V6 |

Always check the folder for the current highest version; this table goes stale.

## Rules

1. **Never edit, rename, or delete a merged migration.** Fix mistakes with a new `V<next>__description.sql`.
2. **One version number per service, no gaps reused.** Before picking a number, check other open branches of that service (`git log --all -- src/main/resources/db/migration`) so two branches do not both add `V11`.
3. **Additive and backward compatible.**
   - New columns are nullable or have a default.
   - Adding `NOT NULL` to an existing table needs a default or a backfill in the same migration.
   - Do not drop or rename a column in the same release as the code that stops using it. Use expand/contract: release 1 adds the new column and writes both; release 2, after it is live, removes the old one.
4. **Match entity types to column types exactly.** Validation is strict:

   | Column | Entity mapping |
   | --- | --- |
   | `varchar(n)` / `text` | `String` (plain `@Column`) |
   | `char(n)` | `@JdbcTypeCode(SqlTypes.CHAR)` **and** `@Column(length = n, columnDefinition = "char(n)")` |
   | `jsonb` | `@JdbcTypeCode(SqlTypes.JSON)` |
   | enum stored as text | `@Enumerated(EnumType.STRING)` on a `varchar` column |
   | `numeric(p,s)` | `BigDecimal` with `@Column(precision = p, scale = s)` |
   | `uuid` | `UUID` |

   Reference mappings: `User.countryCode` (user-management) and `Trip.destinationCountryCode` (trip-planning), each with a mapping test.
5. **Keep locks short.** Large tables: avoid rewriting the table (e.g. changing a column type) in a normal release. `CREATE INDEX CONCURRENTLY` cannot run inside Flyway's transaction; plan it separately.
6. **Data backfills that call other services do not belong in a migration.** Use an opt-in, rate-limited runner (see `TripLocationBackfillRunner`, disabled unless `navio.trip-location-backfill.enabled=true`).
7. **Update the docs**: `docs/database/Navio Database.md` when the model changes, and `docs/api/*` when the API contract changes.

## Tests that do NOT protect you

- Mockito unit tests and `@WebMvcTest` slices never run Flyway or schema validation.
- mobility-and-ev-service and community-service default tests use **H2 with Flyway disabled**. Green there says nothing about Postgres.
- user-management-service's full-context test is `@Disabled` (it needs Keycloak).
- `PostgresSchemaTests` is the only test that covers the real schema for every service, and it is skipped unless `NAVIO_TEST_DB_URL` is set.

## Verify against real Postgres before releasing

Every JPA service has `PostgresSchemaTests`: a `@DataJpaTest` that runs all migrations on real PostgreSQL and starts JPA with `ddl-auto=validate`, the same startup production performs. It is skipped unless `NAVIO_TEST_DB_URL` is set, so normal `./mvnw test` runs are unaffected.

**CI runs it automatically.** The `verify-database-schema` job in `.github/workflows/deploy-backend.yml` runs it for all four services before any image is built; a failure stops the release. Still run it locally before merging so the failure reaches you, not the release.

Use a disposable database. Never point it at a shared or personal database (for example a local `navio-postgres` dev container).

```powershell
# 1. Disposable Postgres matching production
docker run -d --rm --name navio-verify-pg -p 5432:5432 `
  -e POSTGRES_DB=tripplanner -e POSTGRES_USER=tripplanner -e POSTGRES_PASSWORD=tripplanner `
  postgis/postgis:16-3.5-alpine

# 2. Configuration server (needed by trip-planning-service and user-management-service)
cd server/configuration-server; ./mvnw -o spring-boot:run   # keep running, port 8888

# 3. Schema test for the service you changed (run from that service's directory)
$env:NAVIO_TEST_DB_URL = "jdbc:postgresql://localhost:5432/tripplanner"
./mvnw -o test -Dtest=PostgresSchemaTests

# 4. Clean up
docker stop navio-verify-pg
```

A real failure looks like `SchemaManagementException: Schema validation: wrong column type ...` or a Flyway error. Reuse the container for several services; each uses its own schema.

To prove a test guards your change, temporarily revert the fix and confirm `PostgresSchemaTests` fails.

## Checklist

- [ ] New migration file only; no merged migration edited.
- [ ] Version number free across all branches of the service.
- [ ] Additive: nullable/defaulted columns, no drop or rename alongside the code change.
- [ ] Entity mappings match column types (table above), with a mapping test for any special type.
- [ ] Previous release still starts against the new schema.
- [ ] Startup check passed against disposable real Postgres.
- [ ] Database/API docs updated.

## Incident: 2026-09-14

`V10__structured_trip_location.sql` added `destination_country_code char(2)`. The entity had only `columnDefinition = "char(2)"`. Postgres reports the column as `bpchar`, Hibernate expected `varchar`, and trip-planning crash-looped (`found [bpchar (Types#CHAR)], but expecting [char(2) (Types#VARCHAR)]`). The release rolled back. All unit and slice tests had passed. Fixed by adding `@JdbcTypeCode(SqlTypes.CHAR)`; confirmed by reproducing the failure against real Postgres and then passing with the fix.
