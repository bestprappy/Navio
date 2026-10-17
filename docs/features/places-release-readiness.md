# Places sharing and release readiness — 2026-10-16

The implementation is portable. Local success does not deploy the VM, and pulling only the client is insufficient.

## Share for local development

Publish the matching client, Mobility service, Trip service and server Gateway revisions, then the server and root submodule pins. Use feature/dev branches; root main triggers production deployment.

The matching development revisions have been prepared and published child-first: client `0691f9a`, server `774ace6`, Mobility `c298ead`, Trip `6ea2b13`; root pin commit `4f2bbee`. A teammate on dev can use:

```powershell
git pull --ff-only origin dev
git submodule update --init --recursive
.\navio.cmd start trip mobility gateway -Online
cd client
npm ci
npm run dev
```

For a stopped stack, run `navio start` first to start its prerequisites. Targeted service start recompiles/restarts the changed services; an untargeted start leaves healthy services running and can therefore retain old code.

Each machine retains its own uncommitted environment files. The local frontend needs `NAVIO_API_BASE_URL=http://localhost:8080` and a browser Google Maps key. The backend needs a valid `GOOGLE_MAPS_SERVER_API_KEY` with Places API access. Authentication settings must describe the same local Keycloak stack. Do not publish private environment files or credentials.

Places is enabled by default for `npm run dev` unless `NEXT_PUBLIC_PLACES_ENABLED=false`. This Places work adds no migrations, but integrated teammate Trip dev includes V19/V20 for time sources/schedules; Flyway applies these on service startup. Local users and trips belong to the configured local database/identity service, not the VM database.

## VM/production prerequisites

- Release matching Mobility, Trip, Gateway and client revisions through dev/main, then update parent pins in child-first order. Follow `docs/agents/release.md`.
- The frontend requires `NEXT_PUBLIC_PLACES_ENABLED=true` at build time. The current Dockerfile/workflow do not pass this flag; wire it through before enabling production. Runtime environment alone cannot change the browser bundle.
- Retain the VM backend URL/auth configuration and confirm its server Google Places key and browser map key are valid for the deployment. Local environment files must not replace VM settings.
- Run full changed-service release checks and required real-Postgres checks; verify the authenticated add/save/reopen flow and first navigation/mobile map interactions. Prior focused tests and builds do not substitute for these checks.

## Verified evidence and limitations

Final staged client:39 focused tests, TypeScript, lint on all staged TypeScript files and Places-enabled production build pass. Full backend suites: Mobility154 tests/2skipped, Trip260/9skipped, Gateway15/1skipped, zero failures/errors. Environment-gated skipped tests are not claimed as verified. New teammate time-source/schedule tests retain their assertions and use the ownership-lock repository stub. Local gateway reader returned three credited photos and a description. Browser visual/focus/first-navigation QA and authenticated save/reopen remain unverified by automation. The user confirmed re-login resolves expired-session profile401.

Application source is committed and published to the corresponding feature/dev branches. Root dev carries matching child pins and documentation. No main branch was pushed and no production deployment was triggered. Private environments, local editor files, logs, reports and output artifacts remain local. A Trip pre-integration recovery stash is retained intentionally.
