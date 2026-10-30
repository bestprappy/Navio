# Shared reader notes: full content by default

User request: replace Read note with full expanded content and Hide / Show Note. Trip note is the only variant that retains the existing faded beginning when collapsed. All authored rich text/checklists and attached visit timetable must be fully visible initially; standalone shared checklists use the same expansion behavior. Scope shared reader only, no normal planner, content/persistence/API/data or map behavior changes.

1. Add render regressions for expanded full rich text, safe links/checklists and accessible Hide control; observe failure.
2. Reuse a shared disclosure with default-open state and aria-controls/aria-expanded. Keep controls outside rich text. ReaderNotes supports a collapsed preview only when explicitly requested by Trip note. Other notes/checklists hide completely, keeping their Show Note button. Group attached stop schedule with note content.
3. Run focused/full frontend tests, types/lint/build and exercise Hide/Show in the running shared page. Preserve existing source/settings; no deploy unless requested. Update mandatory handoff/docs on dev only.


Implemented and verified:17 focused/521 full tests, TypeScript/scoped lint/build pass. Live ordinary note Hide and keyboard Show verified on localhost actual shared plan. Browser automation stopped on URL-confidence policy before collapsed Trip-note fade interaction verification. No normal planner/backend/sample data changes or deployment. Source3client files remain uncommitted for review; mandatory docs logged on dev only.
