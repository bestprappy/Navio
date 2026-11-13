# Profile, navigation and Saved Community

**Approved requirements:** Clear card-backed Before you go editor; compass-in-search Community Explore icon; larger distinct menu labels and soft Navio border; shared profile dropdown (public Profile / existing Account Settings); public Posts, Shared plans, published Guides tabs. Saved retains default Explore Recents, two expanded collapsible Explore/Community groups, themed sort controls, separate Community search. Community: bookmarks beside Share, current active votes with All/Up/Down, thirty-day visits from actual thread opens, one compact entry per own nondeleted comment newest first. Unsave from Saved replaces that row with a slim Undo confirmation; no Community trash. Existing Explore seven-day trash unchanged.

**Implementation:** Reuse Accordion/Dropdown/Select/editor/card/author/query primitives. Community owns new bookmark+visit tables (additive V10), private /v1/social/me/library endpoints, existing votes/comments queried rather than copied, current visibility/block rules and ownership enforced. Record visit only on mounted readable thread; no prefetched-image/feed tracking or invented historical visits. Views deduplicated by user/post, newest activity retained, expire after30days. Public guide author filter in existing IAM publication query with public-only status. Saved UI separates feature components and URL state/search parameters; saved post state travels with ordinary post responses to avoid per-card status requests. No Google/provider calls or production mutations. Backend release requires separate approval after verification. Custom Cover/categories remain paused.

- [x] Backend Community tests first, additive migration, private collection queries/actions, saved state and visibility/security tests.
- [x] IAM author-filtered published Guides endpoint and tests; drafts never returned.
- [x] Editor/menu/avatar/profile UI polish with shared components and appropriate light/dark/keyboard support.
- [x] Saved navigation, sorting and private Community collection cards/search/Undo; integrate post Save and thread visit tracking.
- [x] Full appropriate suites, real PostgreSQL/startup/backward migration checks, offline browser flows and fresh review.
- [x] Integrate verified dev revisions, preserve teammate work, update API/handoff/log notes and summarize; no unapproved release.

## Verification and rulings

Client bc40495 / Community753a7a2 / IAM2851594; integrated dev only. 710 frontend tests, Community182 full plus6finalrealPG, IAM317full(2existing skips) plus15final regressions. Types/lint/cached-font offline productionbuild;13Saved/profile/thread and10editor/sidebar browserchecks pass. Freshreview bookmarkremount issue fixed and regressionverified. Test-only configuration isolates IAM from configurationserver; no product config/font change.

Ruling: current votes sort by post publication time (clearly labelled), because existing vote records have no action timestamp; no invented voting history or unnecessary migration.
Ruling: mobile Saved navigation stays in document flow, desktop sticky below measurednavbar; two fullyexpanded groups otherwise obstruct all mobilecontent.
Ruling: Communityhistory can clear its own records with confirmation; retention excludes expired rows immediately and physically prunes daily. No invented past visits.

VM release approval requested after concrete verified commits; pending. No customcover/categories/provider or productionchanges. API/storage contracts: docs/api/community-library.md.

## Approved release outcome

User approved this revision including CommunityV10. Rootmain5ebfa3a / workflow42399073886 succeeded completely; Community184tests and IAM318tests(2existing skips) passed fresh release verification. Clean committed frontend archive types pass. Ten read-only live checks plus active dev:vm proxy checks pass;31existing public plans preserved. No Google/provider requests or production account test writes. Notes updated on dev only after deployment; no additional production rollout required.
