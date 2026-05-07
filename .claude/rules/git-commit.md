# Git Commit and Branch Rules for Claude

## Commit Message Format

Use this exact format:

<type>(<scope>): <short description>

## Allowed Types

- feat - new feature
- fix - bug fix
- chore - setup, config, dependencies
- style - CSS/styling only
- refactor - code restructure, no behavior change
- docs - documentation

## Examples

- chore(setup): init Next.js project with shadcn and tailwind
- chore(deps): install react-hook-form zod tanstack-query
- feat(layout): add root layout with IBM Plex Sans Thai and Bungee Outline fonts
- feat(form): add multi-step project registration form
- fix(form): fix step 2 validation not triggering on next
- style(sidebar): update sidebar active color to match MODACT orange

## Branch Strategy

- main - production only, never commit directly
- dev - integration branch, all features merge here first
- feat/xxx - feature branches, branch off dev
- fix/xxx - bug fix branches, branch off dev
- refactor/xxx - code restructure branches, branch off dev
- chore/xxx - config, setup, dependency branches, branch off dev
- style/xxx - styling-only branches, branch off dev
- docs/xxx - documentation branches, branch off dev

## Branch Naming Rule

The branch prefix must always match the commit type used inside it:

- feat/\* → commits of type `feat`
- fix/\* → commits of type `fix`
- refactor/\* → commits of type `refactor`
- chore/\* → commits of type `chore`
- style/\* → commits of type `style`
- docs/\* → commits of type `docs`

## Workflow

Start a new feature:

1. git checkout dev
2. git pull origin dev
3. git checkout -b feat/registration-form

Done, merge back to dev:

1. git checkout dev
2. git merge feat/registration-form
3. git push origin dev

When dev is stable and tested, merge to main:

1. git checkout main
2. git merge dev

## Nested Repository Commit Order

If the project contains nested repositories, submodules, or child apps with their own `.git` directory:

1. Commit and push changes in the innermost child repository first.
2. Return to the parent repository and verify it sees the updated child state.
3. Commit the parent repository after the child commit is complete.
4. Repeat outward until the outermost repository is synced.

Do not commit an outer repository before its changed child repository is committed, because the outer repository may record an outdated child reference or incomplete state.

## Mandatory Rules

- ALWAYS run git pull origin dev FIRST before committing to avoid conflicts.
- Use dev branch for all testing and development until the feature is fully complete.
- Create and push your own feat/xxx branches from dev so they are easy to merge.
- Never commit directly to main.
- NEVER commit `CLAUDE.md`.
- NEVER commit any file inside `.claude/`.
- NEVER commit any file inside `.idea/`.
- NEVER commit any file inside `.vscode/`.

## Commit Safety Prompt (Run Before Commit)

Before every commit, verify staged files do not include `CLAUDE.md`, `.claude/`, `.idea/`, or `.vscode/`:

1. git status --short
2. git restore --staged CLAUDE.md .claude/ .idea/ .vscode/
3. git status --short
