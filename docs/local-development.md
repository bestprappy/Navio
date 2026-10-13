# Local Development

How to run the whole Navio stack on your own machine: Docker infrastructure, the Spring services, and the Next.js client.

## Quick start

```powershell
# 1. Backend (from the repo root): Docker infra + every Spring service, in order
.\navio start

# 2. Client (in client/)
npm run dev
```

Open http://localhost:3000 and **sign up**. Local Keycloak keeps accounts in memory, so production accounts do not exist here and local ones disappear when the Keycloak container restarts.

Requirements: Docker Desktop running, Java 25, Node.js. No IntelliJ needed.

## Backend commands

Run from the repo root. `navio.cmd` calls `scripts/local/navio.ps1`.

| Command | What it does |
| --- | --- |
| `.\navio start` | Start Docker infra and every service. Services already healthy are left alone. |
| `.\navio start trip` | Restart one service, recompiling it. Use this after changing its code. |
| `.\navio start user trip` | Restart several services. |
| `.\navio restart` | Stop and start every service. |
| `.\navio stop` | Stop every service. Docker containers keep running. |
| `.\navio stop trip` | Stop one service. |
| `.\navio stop infra` | Stop every service **and** the Docker containers (wipes local Keycloak accounts). |
| `.\navio infra` | Start only the Docker containers. |
| `.\navio status` | Health of every service and container. |
| `.\navio logs trip` | Last 80 log lines of a service. |
| `.\navio logs trip -Follow` | Stream a service's log. Ctrl+C to stop watching. |
| `.\navio help` | Show the command list. |

Add `-Online` to `start` or `restart` after a `pom.xml` change, so Maven can download new dependencies. By default it builds offline, which is faster.

### Service names

| Short name | Service | Port |
| --- | --- | --- |
| `config` | configuration-server | 8888 |
| `discovery` (`eureka`) | discovery-server | 8761 |
| `user` (`users`, `iam`) | user-management-service | 8081 |
| `trip` (`trips`) | trip-planning-service | 8082 |
| `mobility` (`ev`) | mobility-and-ev-service | 8083 |
| `community` (`social`) | community-service | 8084 |
| `gateway` | api-gateway | 8080 |

Full names such as `trip-planning-service` also work.

### How it behaves

- **Start order:** config server → Eureka → the four domain services in parallel → gateway. Each one must pass its health check before the next stage starts; if one fails, the script prints its last log lines and stops.
- **Services run detached.** They keep running after you close the terminal. Stop them with `.\navio stop`.
- **Logs** go to `logs/local/<service>.log` (git-ignored).
- **After restarting a single service**, the gateway takes about 30 seconds to route to the new instance. A brief `503` from `status` right after a restart is normal while the service registers with Eureka.
- **Local settings are built in.** The script sets each service's environment variables (Keycloak, database, Kafka, MinIO). The Google Maps server key comes from `GOOGLE_MAPS_SERVER_API_KEY` if set, otherwise from `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` in `client/.env.local`.

## Client commands

Run in `client/`.

| Command | Backend it talks to | Env file |
| --- | --- | --- |
| `npm run dev` | Local stack (`localhost:8080`, Keycloak `localhost:8180`) | `.env.local` |
| `npm run dev:vm` | Deployed VM (`navio.sit.kmutt.ac.th`) | `.env.local.prod`, loaded over `.env.local` |

Both run on http://localhost:3000. Restart the dev server after editing an env file.

`dev:vm` uses **production data and accounts**. Anything you create or delete there is real.

### Local `.env.local` values

```env
AUTH_URL=http://localhost:3000
AUTH_KEYCLOAK_ID=navio-web
AUTH_KEYCLOAK_SECRET=local-dev-web-secret
AUTH_KEYCLOAK_ISSUER=http://localhost:8180/realms/navio
AUTH_KEYCLOAK_INTERNAL_ISSUER=http://localhost:8180/realms/navio
NAVIO_API_BASE_URL=http://localhost:8080
```

Set `NEXT_PUBLIC_PLACE_DATA_SOURCE=mock` to use local fixtures for places and chargers instead of the live APIs.

## Useful local URLs

| URL | What |
| --- | --- |
| http://localhost:3000 | Web client |
| http://localhost:8080 | API gateway (`/v1/...`) |
| http://localhost:8761 | Eureka dashboard: which services are registered |
| http://localhost:8180/admin | Keycloak admin console (admin / admin) |
| http://localhost:9001 | MinIO console (navio-local / navio-local-storage) |
| http://localhost:9411 | Zipkin tracing |
| `localhost:5432` | Postgres: database, user and password are all `tripplanner` |

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| A service fails with `Migration checksum mismatch` or `non-empty schema ... no schema history table` | The local database came from an older schema. Reset it (deletes all local data): `.\navio stop`, then `docker compose rm -sf postgres`, `docker volume rm navio_pg-data`, `.\navio start`. |
| Profile or garage shows "service temporarily unavailable" | The gateway cannot reach user-management. Run `.\navio status`. If it is UP, wait 30 seconds and retry. Otherwise check `.\navio logs user`. |
| `A dependency is missing from the local Maven cache` | Re-run with `-Online`. |
| Sign-in fails right after the stack starts | Keycloak can take a minute to import the realm. `.\navio start` waits for it, but a manual `docker compose up` does not. |
| Keycloak or MinIO shows `unhealthy` in `status` | Their container health checks are broken. If the services start, they are fine. |
| Port 3000 is taken | Grafana also uses 3000. Start only what you need (`.\navio infra` does), not a bare `docker compose up`. |
| Media uploads fail | The `navio-community` bucket is missing. `.\navio infra` recreates it. |

## Do not point the local backend at production

Running local services against the production database would apply unreleased Flyway migrations to production, which can crash-loop the deployed services. The user-management outbox relay would also take production's events. To work with production data from the frontend, use `npm run dev:vm` instead.
