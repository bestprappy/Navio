# Places sharing and release readiness — 2026-10-16

The implementation is portable. Local success does not deploy the VM, and pulling only the client is insufficient.

## Share for local development

Publish the matching client, Mobility service, Trip service and server Gateway revisions, then the server and root submodule pins. Use feature/dev branches; root main triggers production deployment.

After those revisions have been published and the root dev pins updated, a teammate on dev can use:

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

Places is enabled by default for `npm run dev` unless `NEXT_PUBLIC_PLACES_ENABLED=false`. No new migrations are included in this Places work. Local users and trips belong to the configured local database/identity service, not the VM database.

## VM/production prerequisites

- Release matching Mobility, Trip, Gateway and client revisions through dev/main, then update parent pins in child-first order. Follow `docs/agents/release.md`.
- The frontend requires `NEXT_PUBLIC_PLACES_ENABLED=true` at build time. The current Dockerfile/workflow do not pass this flag; wire it through before enabling production. Runtime environment alone cannot change the browser bundle.
- Retain the VM backend URL/auth configuration and confirm its server Google Places key and browser map key are valid for the deployment. Local environment files must not replace VM settings.
- Run full changed-service release checks and required real-Postgres checks; verify the authenticated add/save/reopen flow and first navigation/mobile map interactions. Prior focused tests and builds do not substitute for these checks.

## Verified evidence and limitations

39 frontend and38 focused Mobility/provider/controller/search tests pass; client TypeScript, scoped lint and Places-enabled production build pass. Earlier Trip append/hydration tests passed30. Local gateway reader returned three photos with three attribution sets and a description. Local services are healthy. Browser visual/focus/first-navigation QA and the authenticated save/reopen flow remain unverified by automation. The user confirmed that re-login resolves the expired-session profile401.

Application source is still uncommitted on existing feature branches. No source has been pushed and no production deployment has been triggered by this readiness assessment.
