# Navio — Agent Context

Shared instructions for every AI coding agent (Codex, Claude, and others) and for humans working with them. This file is committed on purpose. Codex loads it automatically; Claude loads it through a local, uncommitted `CLAUDE.md` whose only line is `@AGENTS.md`.

## 1. Start of every session

1. Read [docs/agents/handoff.md](docs/agents/handoff.md): what is live, what is in progress, what is uncommitted, and what to do next.
2. Skim the newest entries in [docs/agents/session-log.md](docs/agents/session-log.md).
3. Check real state before trusting the handoff. Run `git status --short` and `git branch --show-current` in the root, `client`, `server`, and every changed `server/<service>`. Uncommitted work may belong to someone else's unfinished session; do not commit or discard it without asking.

## 2. End of every session (mandatory)

Before you stop, even when the work is unfinished:

1. Add an entry at the top of `docs/agents/session-log.md` using the template in that file.
2. Update `docs/agents/handoff.md` so the next agent can continue without this conversation.
3. Commit both as `docs(agents): log session <YYYY-MM-DD>` on a `docs/...` branch cut from `dev`, and merge it to `dev` only. **Do not push these to root `main` on their own: every push to root `main` deploys production.** They reach `main` with the next release.

If you cannot commit (no permission, or the user said not to), still write the files and say so in your final message.

## 3. Repository layout

```
Navio/ (root, deploys)          -> github.com/bestprappy/Navio
├── client/                     -> Navio-Client (Next.js App Router)
└── server/                     -> Navio-Server
    ├── user-management-service/   schema iam
    ├── trip-planning-service/     schema trip
    ├── mobility-and-ev-service/   schema ev
    └── community-service/         schemas social, notif, media
```

`server/api-gateway`, `server/discovery-server`, and `server/configuration-server` are plain directories inside Navio-Server.

## 4. Git rules (summary)

Full rules: `.claude/rules/git-commit.md`.

- Format `<type>(<scope>): <description>`; types `feat fix chore style refactor docs`. Branch prefix must match the commit type (`feat/*` holds `feat` commits).
- Branch from `dev`, merge to `dev`, then `dev` to `main`. Never commit directly to `main`.
- Commit innermost repo first: `server/<service>` -> `server` -> root, and `client` -> root. Push each child before committing its parent.
- Never commit `CLAUDE.md`, `.claude/`, `.vscode/`, `.idea/`, `.planning/`, logs, or `.env` files. `AGENTS.md` and `docs/agents/` **are** committed.

## 5. Changing the database

**Read [docs/agents/database-changes.md](docs/agents/database-changes.md) before touching any migration, entity, or column.** The short version:

- Production runs Flyway on startup and then `ddl-auto: validate`. A mismatch between an entity and its column crash-loops the service and fails the whole release.
- Never edit, rename, or delete a migration that has been merged. Add the next `V<n>__...sql` in the owning service.
- Changes must be additive and backward compatible: production has live data, and a failed release rolls back to the previous image while keeping the new schema.
- Unit tests, WebMvc slices, and the H2-backed tests prove nothing about Postgres. Run the startup check against real Postgres before releasing.

## 6. Releasing

Pushing root `main` runs `.github/workflows/deploy-backend.yml`, which builds every image and deploys the VM. Read [docs/agents/release.md](docs/agents/release.md) before merging to root `main`: the submodule pins must equal each repo's `origin/main`, and you must know how to read a failed run.

## 7. Engineering standards

Detailed rules live in `.claude/rules/` (some of those files are local-only; if one is missing, follow this summary).

Frontend (`client/`):

- Next.js App Router with TypeScript. The Next.js version has breaking changes; see `client/AGENTS.md`.
- Compound component pattern for complex UI; reusable widgets over one-off page sections.
- Jotai for client UI state; TanStack Query for API and server state.
- Strong typing only, no `any`. Mock data goes in `data.ts`.
- Accessibility and keyboard support are required. Token-driven styling; no default Tailwind palette for brand colors.

Backend (`server/`):

- Java 25, Spring Boot 4, `.yml` configuration only.
- Routes `/v1/<plural-resource>`, thin controllers, validated request DTOs, ownership enforced in the service layer, one `GlobalExceptionHandler` per service.
- Tests use the `*Tests` suffix. Every authorization rule and every mapped exception has a test.

## 8. Reference documents

- `docs/api/Navio Api Documentation.md` and `docs/api/Navio Open API.yaml` (the trip schemas there describe a planned design, not the current DTOs)
- `docs/database/Navio Database.md` (target design, not a list of applied migrations)
- `docs/summary/Navio Architecture.md`
