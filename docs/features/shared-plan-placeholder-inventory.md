# Shared Plan placeholder inventory — 2026-11-05

User requested an inventory before implementation. Finish agreed placeholders first, then return to the new default collections and filters. No application changes are authorized by this inventory alone.

**Update 2026-11-05:** User subsequently approved implementation, explicitly put Custom Cover on hold and requested component reuse. Ratings/comments/reader sharing are implemented and LIVE in root0e341ac, including corrected gateway routing. See `docs/reports/2026-11-05-shared-plan-feedback.md`. Items below preserve the original audit, not the current implementation status.

## Confirmed active Shared Plan gaps

1. ReaderFeedback stars are React state only; no persisted plan rating, average, count, update or removal workflow. PlanEngagement always says Not rated yet. Real averages/counts must reach cards and details before rating sorting is meaningful.
2. ReaderFeedback comments are local unposted previews only. No persisted comment listing/posting/edit/delete or conversation lifecycle in this reader. Replies, pagination, reporting/moderation and ownership rules need explicit design; do not describe these as existing controls.
3. SharedReader Share plan uses PreviewAction: it opens a design-preview dialog. Explore card sharing already has a real URL/copy dialog and should be reused.
4. Owner cover override in ReaderPresentation is browser-local preview data. Verify and design durable owner-selected cover storage/publication if included in this phase; automatic provider/destination covers already work. Do not confuse preview image override with the functioning provider cover pipeline.

## Adjacent deferred UI, not automatically approved scope

- Saved Guides is marked Later and displays a deferred empty state.
- Saved custom categories is marked Later.
- Search Interests contains disabled keyword-filter previews. Keep with the later filter/default-page phase.
- Legacy explore share-dialog.tsx includes inert invite/social/Copy ID controls, but no current app import was found in the audit. Do not expose or implement obsolete collaboration UI merely because the file exists.

## Already connected / not placeholders

Plan and place bookmarks (including source-plan links), Saved plans/places lifecycle, public share URL on Explore cards, successful copy and unique traveler counts, view counts, actual related-plan API cards, search, and publication/copy structure are existing implementations. No new end-to-end validation was run during this read-only inventory.

Map Reviews intentionally links to Google Maps visitor reviews and shows provider rating/count. It is distinct from Navio trip ratings/comments. Planner Reviews not available yet is the missing-rating fallback, not proof of an unimplemented reviews backend.

## Later default page

Requested Trending, Recent, All-time popular, Seasonal, Events and real sort/filter controls remain pending. Current trending is lifetime view ordering, not a time-window activity measure. Rating/review sorting must wait for real persisted feedback. No arbitrary keyword group should be activated without eligible evidence.

Recommended implementation order for user review: persisted ratings plus aggregates; comments and agreed moderation/conversation behavior; reader sharing reuse; cover persistence if desired; then default sections and filtering. Saved Guides/categories remain separately scoped.
