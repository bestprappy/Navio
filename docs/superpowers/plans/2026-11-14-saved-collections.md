# Saved collection repair plan - 2026-11-14

Scope: full original cards in Saved; stable left-edge Saved rail under navbar; diagnose Guide retrieval; separate Saved shortcut; relocate logout under Privacy and Account Settings. Preserve filters, pagination, account isolation, trash/Undo, source links and disabled Places discovery.

1. Add regressions for Saved request routing/Guide visibility and rich-card metadata loading. Confirm the actual failing path before changing backend behavior.
2. Reuse SharedPlanCard / TravelerGuideCard / PlaceCard with Saved-specific actions and no new discovery/provider fanout. Load public database metadata; unavailable publications keep a recoverable bookmark fallback. Record opens without incrementing publication views in the collection.
3. Fixed-height Saved shell below navbar, independent desktop rail/main scroll, accessible collapsible mobile navigation. Keep URL selections and community grouping.
4. Shared logout action in account dropdown and Settings below Privacy; remove standalone sidebar action, separate Saved from primary nav.
5. Run focused/full frontend checks, browser fixture layout/Guide-save flows, final fresh review. Document limits and commit isolated work. No deployment without new approval.

Ruling: use existing isolated client worktree, based on pending verified reader-statistics, to preserve prior work and user checkout.

Ruling: user confirmed Guide saving works on recheck. Preserve existing API opt-in/forwarding; remove proposed unnecessary boundary enforcement. Add regressions and full-card save/unsave/Undo verification. No backend fix claimed.
