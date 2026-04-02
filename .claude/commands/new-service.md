# Scaffold a New Navio Microservice

Scaffold a new Spring Boot service submodule following the Navio template.

## What to do

Given a service name (e.g. "EV Intelligence Service") and port (e.g. 8082):

1. Confirm the service name, port, Postgres schema(s), and GitHub repo name with the user before doing anything.
2. Create the Spring Boot project scaffold (or confirm it already exists locally).
3. Create the GitHub repository under `bestprappy/` using the GitHub API.
4. Make an initial commit and push to `main`.
5. Register it as a submodule in `server/` (Navio-Server repo).
6. Commit and push the Navio-Server submodule pointer update.
7. Commit and push the Navio umbrella submodule pointer update.
8. Generate a `README.md` for the new service covering: purpose, modules, API endpoints, database schema, events produced/consumed, and how it fits into the platform.

## Template checklist for every service

- [ ] Spring Boot 4.x + Java 25
- [ ] Lombok
- [ ] Spring Data JPA + Flyway
- [ ] Kafka producer boilerplate + Transactional Outbox table
- [ ] Resilience4j dependency
- [ ] Caffeine cache dependency
- [ ] Spring Cloud Config client
- [ ] Spring Security OAuth2 Resource Server (JWT via Keycloak JWKS)
- [ ] Actuator health endpoints
- [ ] Standard error response format
- [ ] Correlation ID propagation filter
- [ ] `X-Internal-Auth` validation on internal endpoints
