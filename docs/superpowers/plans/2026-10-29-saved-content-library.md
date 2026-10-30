# Saved content library implementation plan

> Use superpowers:executing-plans. Approved by user on 2026-10-29, including Community navbar placement.

Goal: private persistent Saved library, shared Place/Plan bookmark controls, full collection search and seven-day recovery.

Spec: ../specs/2026-10-29-saved-content-library-design.md

Architecture: IAM owns bookmarks, lifecycle and search. Existing personal anchors remain bounded and retain default/Home/Work semantics; their existing locations are imported into the same canonical library and subsequent favorite edits synchronize membership. General travel saves never create personal anchors. Trip owns public-plan availability/metadata through a side-effect-free reference endpoint. Next proxies authenticate every library operation.

Constraints: preserve six earlier dirty frontend files; no guide saving/comments/ratings/custom collections; no editorial; no deployment without release approval. Work in existing running dev checkout so dev:vm review sees changes; do not transplant or discard existing edits. Source commits wait for review; mandatory session docs commit separately.

- [x] Task 1: Add IAM library contract/repository/service/migration and tests. Canonical location identity, atomic save/restore/quota, own-account lookup, source merging, page limits, normalized fuzzy search, expiry/purge, legacy favorites integration. Verify unit/controller and real PostgreSQL tests.
- [x] Task 2: Add side-effect-free published-plan reference lookup; use it for plan saves/open and source navigation. Verify missing/revoked/old-redaction links, no view increments, unlisted token access only for known token.
- [x] Task 3: Add validated frontend API and account-scoped bookmark hooks/buttons, Places actions and Shared reader wiring. Verify deduplication/state failures/auth isolation and render tests.
- [x] Task 4: Build Saved page: Recents (saved then opened), All/Plans/Places/Trash, reserved Guides; server search, progressive filters, sort/pagination, open/add-to-plan/copy/source/undo/restore/delete controls. Add navigation main/community left of theme and sidebar under profile, mobile accessible.
- [x] Task 5: Full checks, real database compatibility/startup, fresh read-only final review, fix important issues with regression tests, document deployment boundary and update handoff/log.

Review focus: anchor privacy/default preservation; expired/revoked sources; concurrent quota/dedupe; account switch/cache isolation; large collections and search pagination.

Execution ledger

- Start: root/client/server/IAM on dev. Six earlier client changes preserved. No saved-feature code exists yet.
- Ruling: use a library membership table with canonical identity, not unlimited personal anchor rows. Existing anchors are bridged into library without changing trip defaults or legacy picker response size. The distinction is personal-anchor role versus bookmark, not a second user-facing collection.
- Ruling: preserve running checkout rather than create another worktree, consistent with user's dev:vm review requirement and existing unfinished edits. No source commits containing earlier work without approval.

- Task1 complete: IAM canonical library repository/service/controller, additive V10 and legacy import/bridge; state batching, owner-scoped bounded search, Plan quota50 under user lock, unlimited paged Places,7day trash/restore/expiry. Existing personal anchor tables/default semantics unchanged.
- Task2 complete: side-effect-free internal active/sanitized known-token reference, published start date, source membership/availability checks. No public gateway route or view increment added.
- Task3 complete: common account-scoped Save icon controls, Explore card/reader actions and provenance, Shared reader real Save Plan/Place, main/community left-of-theme shortcut and sidebar under profile, mobile link.
- Task4 complete: Saved Recents/All/Plans/Places/Trash, Guides/custom-category explicit Later, URL-preserved search, collection suggestions, progressive grouped filters, sort/page, Open/Add/Copy/source/Undo/restore/permanent remove. Recently opened also records saved readers opened elsewhere. Existing copy dialog optionally resolves current published dates before offering retain/change.
- Final review: one fresh read-only agent found4P2; all fixed in one pass. Coordinate-backed saved locations now reuse atomic My List append with validated optional SAVED_LOCATION contract; pagination clamps after deletion; favorite bridge updates coordinates; both imported/bridged favorites use SQL accent normalization. Regression red results recorded in output/library-*-red.log; full client524, final IAM261(2skip) including real upgrade, trip293(3skip), tsc/lint/production build pass. Latest full IAM run includes upgrade test (see session note for count).
- Ruling: non-Google library locations reuse the existing atomic append endpoint with validated coordinates rather than rewriting the full planner snapshot; preserves owner/version/list/idempotence safeguards and old GOOGLE requests.
- Ruling: known unlisted plan bookmarks open /share/plans/{token}; /explore/shared remains listed-only. No unlisted enumeration is exposed.
- Deployment boundary: code is local/uncommitted for review. dev:vm needs a coordinated IAM+Trip release; user approval required by docs/agents/release.md before root main. No source push, VM migration, traveler data edits or production deploy performed. No claim of interactive saved-flow visual acceptance before VM release.
