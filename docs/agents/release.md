# Releasing Navio

## What triggers a deploy

Every push to root `main` runs `.github/workflows/deploy-backend.yml`. There is no path filter: a docs-only push to root `main` also rebuilds and redeploys everything. Merge documentation-only changes to `dev` and let them ride along with the next release.

The workflow has three stages:

1. **Verify backend revisions are current.** `client`, `server`, and every `server/<service>` pin must equal that repository's `origin/main`. A pin that points at `dev` or a feature branch fails here.
2. **Build.** Nine images are built and pushed to `ghcr.io/bestprappy/navio-*` tagged with the root commit SHA.
3. **Deploy to Navio VM.** A self-hosted runner executes `.deploy/scripts/deploy.sh`.

## Release order

1. Merge each changed service: feature branch -> `dev` -> `main`, push both.
2. In `server`: commit the new service pins on a `chore/` branch, merge to `dev` and `main`, push.
3. In `client`: merge to `dev` and `main`, push.
4. In root: commit the `client` and `server` pins on a `chore/` branch, merge to `dev` and `main`, push. This push deploys.

Before step 4:

- [ ] Every changed service's full `./mvnw -o test` passes.
- [ ] Database changes passed the real-Postgres check in [database-changes.md](database-changes.md).
- [ ] Client type-check (`node node_modules/typescript/bin/tsc --noEmit`) and lint pass on the committed files. If you commit only part of the client working tree, type-check a copy of the staged files alone (`git checkout-index -a --prefix=<dir>/`), because unstaged files can hide missing imports.
- [ ] No unrelated uncommitted work was swept into a commit.

## What deploy.sh does

- Pulls images, ensures Postgres is healthy, runs community storage checks.
- `docker compose up --wait` with a 420 s timeout. A container that exits or is unhealthy fails the deploy.
- Configures Keycloak, reloads NGINX, and smoke-tests authentication, public and protected routes.
- **On any failure it prints diagnostics and rolls back to the previous image tag.** Production keeps serving the old release, but migrations that already ran stay applied.

## Watching a run

`gh` is not installed on the main dev machine. The public API works without auth:

```powershell
$h = @{ "User-Agent" = "navio-deploy-check" }
(Invoke-RestMethod "https://api.github.com/repos/bestprappy/Navio/actions/runs?head_sha=<root-sha>" -Headers $h).workflow_runs |
  Select-Object id, status, conclusion, html_url
(Invoke-RestMethod "https://api.github.com/repos/bestprappy/Navio/actions/runs/<run-id>/jobs" -Headers $h).jobs |
  Select-Object name, status, conclusion
```

Step logs require a signed-in GitHub account. If the deploy job fails, ask the user to open the run and paste the tail of **Deploy to Navio VM -> Deploy release**, especially the `Deployment diagnostics` section.

## Reading a failure

| Symptom in the log | Likely cause | First move |
| --- | --- | --- |
| `<service> is stale: pinned=..., main=...` | A pin is not on that repo's `main` | Merge that repo to `main`, re-pin the parent |
| `container navio-<service>-1 is unhealthy` and `Restarting (1)` | Service crashes on startup | Reproduce locally: real Postgres + config server + `*ApplicationTests`. Schema validation and Flyway errors are the usual cause |
| `Expected ... to return 401; got ...` | Gateway routing or security change | Check `api-gateway` routes and `IdentityPropagationFilter` |
| Keycloak / Google OAuth smoke checks | Realm or theme config | Check `.deploy/keycloak` |

Never re-run a failed deploy without identifying the cause. Confirm production is healthy after a rollback:

```bash
curl -k -s -o /dev/null -w '%{http_code}\n' https://navio.sit.kmutt.ac.th/health   # expect 200
curl -k -s -o /dev/null -w '%{http_code}\n' https://navio.sit.kmutt.ac.th/v1/trips # expect 401
```
