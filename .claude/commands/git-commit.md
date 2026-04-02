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

## Mandatory Rules

- ALWAYS run git pull origin dev FIRST before committing to avoid conflicts.
- Use dev branch for all testing and development until the feature is fully complete.
- Create and push your own feat/xxx branches from dev so they are easy to merge.
- Never commit directly to main.
