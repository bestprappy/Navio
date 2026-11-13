# Discovery quality repairs implementation plan

> Execute inline with superpowers:executing-plans; one fresh-context review at the end.

**Goal:** Repair dropdown presentation, reliable distinct sample covers, richer maintained Guides and total Guide reads, signed-in lifetime-unique viewers and Guide feedback.

**Decisions:** User revised views: count every visible opening (including guests) as total; count only signed-in accounts once per Guide as lifetime unique. Put both directly below the cover, total on cards. Add rating and comments using Shared Plan components. Existing sample IDs, shared links, engagement and unrelated travelers must be preserved. Existing generated files/user edits remain untouched. Places search behavior is outside scope. No automatic release: obtain approval for the new backend/migration once verified.

## Tasks

- [x] Client dropdowns: opt-in contained Select list scroll/padding, no competing arrows; rounded filter shell with an inset scroll area and fixed footer. Test keyboard navigation, short/narrow viewports, both Plans and Guides, light/dark; unrelated selects keep defaults.
- [x] Views: source/guide/read-request ledger for idempotent per-opening totals, separate account-hash lifetime ledger; preserve old totals and explicitly mark unique tracking as starting at this release. Anonymous reads carry no persistent guest ID. Exact gateway public POST route, authenticated mutations remain protected. Real PostgreSQL verification.
- [x] Reader: visible page opening records once, acknowledged response invalidates discovery and feedback. Reuse Shared Plan rating/comment/reply/edit/delete/report controls; preserve existing Plan routes and behavior. Show total/unique/rating beneath cover; Guide cards show total/rating.
- [x] Ratings: one editable/removable score per account, no publisher self-rating. Published-only comments, one reply level, optimistic edit version, author/publisher/moderator deletion, report review permissions. Ratings/Most ratings discovery sorts use real aggregates.
- [x] Discovery: verify 30-day ranking, total popularity, recent fallback labels, authored month/season/theme and combined filters through existing service tests plus focused cases. No fabricated engagement.
- [x] Covers: audit every maintained plan destination; add locally hosted appropriately licensed/credited photos for uncovered destinations, season-specific Kyoto variants; preserve user covers as priority. Verify actual assets, references, licenses and fallback mapping; avoid provider calls during cover checks.
- [x] Content: expand the20 recently added Team Guides from4-6 to9-20 unique real mapped places each, with varied counts and tailored prose/sections; review older Team Guides for fewer than9 places too. Reuse verified existing records, bounded cached new lookup only where needed. Keep manifest and actual live documents consistent. Safe in-place update runner with backup, exact ownership/expected-content guards, dry-run and canary; no unrelated traveler writes.
- [x] Final: relevant frontend checks/browser checks, full changed backend suites and real Postgres, content validators and live post-publication checks; fresh review. Commit child repositories first, integrate to dev preserving teammate tours. Request VM release approval only after implementation is concrete and verified. Mandatory session notes on dev only.

## Risks to verify

- Old view dedup expires after two days: true historic lifetime uniqueness cannot be reconstructed. Preserve totals; do not backfill mixed anonymous/account hashes. New unique behavior is accurate going forward.
- Provider photos can fail independently; locally hosted cover fallbacks must stand alone and contain correct place-specific attributions.
- No invented IDs/coordinates, no duplicate places to inflate Guide counts, no distant unrelated stops to reach a target.
- Same-city spring/autumn can share a landmark but should differ in seasonal rationale, main stops and visual identity.
- Popovers must open downward, keep selected first item inset, expose only one scrollbar and keep actions reachable in short viewports.

## Progress 2026-11-13

Complete: user executed the pinned maintenance command; private backup verified, full20 dry run/canary/batch passed. Fresh independent public verification matches all20 expanded documents(219 places/77 sections,9-19 each) and all20 discovery-card counts, with three other published curated documents unchanged. No provider calls or view writes for verification. Artifact output/guide-expansion-live-after.json. Older published originals were reviewed(Shanghai20,Tokyo7,Bangkok24); they are outside this20-Guide batch and remain unchanged rather than trimming or overwriting the original library. No further cover deployment is needed despite the late approval: already included in root643cf26. Completion notes on dev only.

Latest: engagement/dropdowns deployed successfully in rootb4abdd3. Teammate consolidation root643cf26/clientdc6028c also deployed successfully and includes cover00b948a; do not repeat that release. Content3d7f562 prepares all20 maintained Guides with219 places/77 populated sections, varied9-19 each, preserving originals. Nine offline safety tests, eight real disposable PostgreSQL checks, all20 reader schemas/editor round trips and three desktop/mobile browser cases pass; twenty existing maintenance regressions pass. Fresh review's CRLF checksum issue corrected by hashing staged Git bytes, with committed/raw-download verification. The actual VM content update remains pending execution of the pinned backed-up maintenance command in the user's existing authenticated SSH terminal. SSH is connected; the separate command runner cannot reuse its password authentication. No new root main push. See current agent handoff for command and exact state.

The following paragraph records the earlier checkpoint and is superseded by the latest status above.

Guide engagement code implemented in isolated client/IAM/gateway worktrees. First full IAM regression:438 tests,0 failures,2 skipped; real PostgreSQL V15/V16 migration/JPA validation and feedback/counter tests passed. Gateway19 tests,0 failures,1 skipped. Frontend TypeScript/lint clean,15 Guide tests pass. Browser fixture checks12 pass: guest/account/mobile-dark, hidden/visible read, retry UUID stability, under-cover stats, rating/comment contribution and guest restrictions. No Google calls or live DB mutations for these checks. Additional final permission/sort tests pending rerun; original cover/content expansion work remains unfinished. No release or deployment of these changes yet.
