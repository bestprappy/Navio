# Places editorial articles implementation plan

> Use superpowers:executing-plans inline; preserve all existing unfinished work.

Goal: One original, worthwhile article for a documented place or no article. Popularity is irrelevant.
Spec: ../specs/2026-10-22-place-article-editorial-proposal.md, approved with later amendments: 350-450 words is a target, useful ~250-word articles permitted; eligibility depends on official records and enough evidence, not fame.
Architecture: typed prepared catalog + pure publication checks + existing reader component. No generation, crawling, database, provider payload persistence, Admin or planner changes.

- [x] Task 1: Write failing article tests for catalog precedence regardless of Google description, missing article omission, publication guards, reading budget and duplicate attribution. Add model checks for identity, two independent publishers including authority, source references on every passage, >=2 evidenced experiences, reviewed published state, future/expired review dates and <=500 words. Run red.
- [x] Task 2: Research existing three places using independent official/institution sources. Original prose, source references per passage, no Maps-derived prose/review consensus. Remove conflicting Wat Pho inscription count. Store source-checked dates, version, locale and review due date. Build pure model; test missing evidence/status/expiry/word cap; no fake confidence probabilities.
- [x] Task 3: Replace Google/ours branching with preview + accessible Read the story/Show less disclosure, 1-2 credited live photos, article sources/review date. Omit unknown/ineligible article. One lower provider attribution after grouped photos before source footer; preserve map/provider practical attribution. Gate article on no-live-provider closure contradiction. Run green, typecheck/scoped lint/full suite/build.
- [x] Task 4: Independent whole-change review; fix material issues. Record coverage/manual verification limits, update required session notes and commit docs only locally. No application commit/push requested.

Review focus: no unverified popularity threshold; no padded/copyright-derived prose; no stale claims silently published; photos/provider credits distinguish original text; expired or unknown place has no empty panel; planner/sidebar/Admin untouched.
Ruling: work in current checkout because the approved article files are uncommitted here and must remain available for user review. No worktree creation or source commit needed.

Completion ledger: focused red tests failed for old summary override/empty state/duplicate logo and missing publication model, then passed after implementation. Prepared catalog is roughly360-410 words per entry; precise counts recorded in session notes. Runtime gates are completeness/maintenance checks, not proof of truth. Passage references deliberately internal, source list reader-facing. Reviewer identified midnight expiry; added timer plus visibility/focus recheck and boundary regression. Browser inventory returned no available browsers, so no live visual/keyboard acceptance claimed. Planner/sidebar/Admin untouched this turn. Source remains uncommitted; only required documentation committed locally.
