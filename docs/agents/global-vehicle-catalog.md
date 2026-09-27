# Global vehicle catalog

Implementation contract, 2026-09-26. Administrators maintain vehicle specifications; members and guests select published entries. Existing personal garage and trip snapshots never follow catalog edits.

## UI brief

Use the existing Navio Paper/navy palette and Plus Jakarta Sans from `DESIGN.md`/`globals.css`: Paper #FAFBFE, navy approximately #080B23, white #FFFFFF, blue action approximately #2389EF, muted blue-gray approximately #555B67. Tokens and dark equivalents are authoritative. Page titles 24px/600, sections 18px/600, controls/body 14px, metadata 12px. Left-align all fields. Reuse shadcn buttons, inputs, selects, fields, badges and confirmation dialogs.

```text
Sidebar | Vehicle catalog                        Add vehicle
        | Search [make/model/trim]  All / Draft / Published / Archived
        | Vehicle & market | Battery / official range | Status | Edit
        | Previous                                           Next

Editor  | Back to catalog                     Save draft / Save changes
        | Identity                 | Picker preview
        | Battery and range        | Publication status
        | Charging                 | Publish / Archive
        | Image and sources        | Existing saved vehicles stay unchanged
```

The catalog is a working table, not a product-card gallery. The editor's one preview reflects what drivers choose; it must not infer missing specs. Mobile uses stacked fields and moves the preview beneath them. Drafts need make/model/market but may omit specs; publishing requires battery, range, standard, connectors and dated HTTPS provenance. Empty image uses the existing vehicle placeholder. Remote URLs are displayed directly, never downloaded by the server.

## Contract

- IAM owns new additive V5 `iam.vehicle_models`; existing JSON IDs/specifications seed as published.
- Admin-only `/v1/admin/vehicle-models`: GET paginated search/detail, POST create draft, PUT full specification replacement with `expectedVersion`, POST `/{id}/publish` or `/archive` with `expectedVersion`.
- Public GET `/v1/vehicle-models` and `/{id}` expose published entries only. Collection accepts `term`, `market`, `page`, `size` (maximum 100), stable make/model/id ordering. No public writes or status filter.
- Published edits remain published and must pass publication checks. Archived records can be edited and republished. No destructive deletion.
- Optimistic version checks reject stale edits/transitions with 409. Case-insensitive make/model/trim/year/market identity is unique. Every write records before/after audit data in the same transaction.
- Authenticated legacy catalog array stays compatible (bounded to 1000). New picker uses public pagination and refetches on opening. Signed-in additions resolve current published specs server-side; guests recheck the public detail before saving a local snapshot.
- The previous application image can run against the additive schema but continues reading its bundled JSON, so newly published/archived entries take effect only on the newer image.

## Verification target

Create draft → absent publicly → publish → select in member garage and guest trip → edit/archive → stored snapshots unchanged; archived entries cannot be added from stale pickers. Also verify role matrix, validation, audit records, stale versions, duplicate identities, real PostgreSQL schema upgrade and old-image compatibility, browser mobile/desktop light/dark, and failure recovery.
