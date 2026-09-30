# Admin account workspace

Continuation brief, 2026-09-26. Scope: finish the existing account dashboard and moderation workflow. Catalog publishing and global activity remain separate backend work.

## Design

Reuse `client/DESIGN.md` and `globals.css`: Paper background, white panels, navy text, blue actions, cool gray secondary text, destructive red only for bans/errors. Approximate light palette for reference: Paper #FAFBFE, navy #080B23, surface #FFFFFF, action blue #2389EF, muted blue-gray #555B67. Semantic CSS tokens remain authoritative, including dark equivalents. No new global theme.

Plus Jakarta Sans throughout: page heading 24px/600, section heading 18px/600, body/control 14px, metadata 12px, counts 30px with tabular numerals. Left-align content. Shared shadcn Button/Input/Sheet/Dialog/Field controls; no second component system.

```text
Sidebar  | Admin overview                         Refresh overview
         | Account counts: total / active / banned / joined 30d
         | Find an account [name or email_______________] [Search]
         | Newest accounts                Banned accounts
         | name / email / joined           name / email / status

Users    | Search + status filters
         | Account / Role / Status / Joined
         | Previous                 Next
         |                           Account sheet
         |                           Status + details + ban/unban
         |                           History + newer/older changes
```

At mobile widths, counts become two columns, account lists stack, and the sheet fills the width. One summary strip reflects one population; the search is the primary task. Avoid decorative charts and unavailable catalog/activity destinations. The initial count strip looked actionable even where the API cannot provide a matching filter: render total and joined counts as noninteractive summaries with explicit definitions, and retain links for active/banned counts. Newest accounts includes deleted profiles because the existing search API does.

## Interaction and verification

- Refresh updates all three visible dashboard queries. Each failed section remains retryable.
- Search submits a shareable Users URL. Search/filter/page/account detail remain URL-driven.
- Sheet uses the shared shadcn primitive, restores keyboard focus, and resets account-specific state when the target changes.
- History exposes older pages through the existing paginated endpoint. Errors retain navigation back to newer history.
- A timeout cannot prove a moderation write failed: request feedback tells staff to check the account before retrying.
- Verify administrator/moderator/member/guest page gates, keyboard interaction, ban failure/success, history paging, responsive light/dark screens, and no zero fallback for unavailable statistics. Browser fixture tests are not live Keycloak/Postgres acceptance.
