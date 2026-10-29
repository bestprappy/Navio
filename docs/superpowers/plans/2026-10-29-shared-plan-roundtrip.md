# Complete Shared Plan Round Trip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans task-by-task.

**Goal:** Persist and publish selected starting document, lists, EV setup and rich itinerary, then copy them back into an editable private planner.
**Architecture:** Starting document is a reserved existing list/note block; trip vehicles extend validated energy state as frozen trip-scoped descriptors. Add optional public sections and durable publication selection. Copy remaps public identities and prompts dates. No anonymous private reads.
**Tech Stack:** Next.js/TypeScript/Jotai/TanStack, existing Tiptap Markdown editor; Java25/Spring4/Flyway/Postgres.
**Spec:** docs/superpowers/specs/2026-10-29-shared-plan-roundtrip-design.md (approved by user: Ok).

## Global constraints

No image uploads in Starting Part. Copy asks retain/change dates. Section order Starting Part -> My List -> Garage -> Trip -> Budget. Catalogue cars default included, custom explicit confirmation. Old links compatible; no additive sanitizer bump. Private anchors/account identities never published. PLACES_EDITORIAL stays disabled/excluded. No release or source push this task.

## Review focus

- Omitted/empty selection must not expose private lists or custom vehicles.
- Older clients preserve new optional persisted data; unsupported backends must not silently accept lost changes.
- Imported Garage must render/edit/select/remove without account-library writes.
- Duplicate places, item/budget references and sparse dates must survive ID remapping.
- Old publications remain readable and copyable; no invented author fields or dates.

## Tasks

- [x] 1. Backend round-trip contract and tests: extend publication DTOs/options; reserved starting-part block; retain list order, day titles/colors, schedules; safe public refs and budget associations. New publication/copy tests fail then pass.
- [x] 2. Trip vehicle persistence: V22 additive nullable trip vehicle JSON, validated energy-state round trip and capability; durable publication selections. Postgres schema/upgrade tests updated, no old migration edited.
- [x] 3. Atomic copy/date request: validated retain/change choice, compatible legacy endpoint, ID remapping, selected document/lists/vehicles/budget restore; no copy event/partial trip on error.
- [x] 4. Planner Starting Part editor: existing block/note atoms and editor, pinned below saved Places; exclude from ordinary list management; save/reload/undo via existing persistence.
- [x] 5. Frontend trip Garage descriptors: merge account-selected and imported trip data, scoped commands, capability guards; publish selection UI and real preview; copy-date dialog.
- [x] 6. Reader consumes actual snapshot sections in approved order, rich notes/checklists/schedules and selected vehicle specs. Preview remains supplementary.
- [ ] 7. Maintained examples: locate/create repeatable complete sample sources without mutating real travelers; exercise actual publication/copy persistence. All maintained review examples cover selected sections with varied authored text.
- [ ] 8. Full verification, real Postgres migrations/upgrade, fresh read-only final review, scoped docs/handoff.

Ruling: Continue in the shared runtime checkout, preserving the existing icon edit and local artifacts; no extra worktree needed for this connected feature. No source commit/push unless requested. Mandatory docs use docs branch/dev.
Ruling: Store Starting Part as a reserved list block containing the existing rich note format; reuse autosave/draft/undo rather than a duplicate trip-document persistence system. A nullable new trip vehicle column plus publication selection column is required; old schemas cannot carry these and client must capability-check.


## Verified implementation and recovery, 2026-10-29

Tasks 1-6 implemented. Task 7 has three varied complete editable sources, a development preview and an explicit authenticated setup action targeting the configured gateway (including dev:vm). All three were exercised through real HTTP, PostgreSQL persistence, publication, anonymous reads, retain/change copying and reload. VM example creation is pending the backend release and an authenticated setup action; existing published samples have not been overwritten. Task 8 automated checks/review complete; browser visual acceptance and VM smoke remain pending.

Ruling: The user overrides the earlier local review preference: use npm run dev:vm, never require a local app backend for their review. Disposable local Postgres is solely test infrastructure. The connected example setup is explicit, development-only, same-origin, authenticated and confirmation-gated. It creates owned review trips, reuses existing matching trips without overwriting and cleans up only its own failed new trip. Existing travelers and the old example collection remain unchanged.

Sleep recovery: working-tree edits intact; no source reset/reinstall required. User-approved Docker Desktop restart recovered stalled containers/Postgres. Existing services/data preserved. Disposable navio-roundtrip-pg-20261029 on loopback55433 used for checks. No application backend was started for user review.

Final checks: frontend519 tests pass, full TypeScript/scoped ESLint/production build pass. Backend290 tests run, zero failures/errors,3 optional skips; real PostgreSQL fresh/upgrade/schema/application startup and full HTTP round trip included. Preview HTTP200 contains complete-example controls. Final read-only review found no further important issues.

Reviewed regressions fixed with red/green checks: inactive imported EV editing must not select it; copied duration retains declared endDate; expanded readonly notes allow safe links; example source adapter retains authored day title rather than replacing it with Day1. Public energy fields never include private anchor-derived SoC/charge projections. Checklist checked/visited progress is intentionally reset, authored labels/order preserved.

Sample limitation: demonstration charger is clearly synthetic/unverified; these examples prove content transport, not real charger search or charging feasibility. Ordinary sample places resolve real provider IDs before VM publication. Full visual/keyboard acceptance is not claimed. No source commit/push/deploy yet; release approval requested only after concrete implementation/verification because root main deploys production.
