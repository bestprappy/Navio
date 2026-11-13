# Guide and Shared Plan reader repairs

User clarification: navbar fixed at top, Guide column alone scrolls, desktop map fills the remaining viewport and accepts wheel/pan. No document scrolling or blank footer. Match the Shared Plan selected-map-place panel for Guides, with Guide-specific context and no itinerary actions. Preserve normal planner cards and Places discovery safeguards.

1. Reproduce signed-in feedback duplicate keys; assign distinct component/identity keys, preserving account reset behavior. Capture console errors in browser regression.
2. Trace photo endpoints. Shared reader incorrectly calls discovery `/reader` while discovery is disabled. Reuse normal cached place-details queries, lazy-load inline photos, retain includePhoto opt-out when a stored photo exists, avoid gallery/discovery fanout and automatic retries on permanent failures.
3. Reproduce actual Guide viewport geometry across desktop/mobile and resize. Fix only the reader shell/containing sizing, retain resizable panels and mobile Guide/Map controls. Assert document scrollHeight fits viewport, Guide can scroll, map bounds stay fixed.
4. Extract shared selected-place panel presentation, keeping Shared Plan state adapter separate; add Guide adapter for navigation, zoom, context and saved location. Preserve photos, safe links, reviews, keyboard tabs, no itinerary-only controls in Guide.
5. Run scoped unit/SSR and browser regressions with external providers blocked, TypeScript and lint. Generic api-client failure remains pending operation/path/status from user; do not suppress or guess it. Review branch before integration, preserve teammate/local edits, record evidence and limitations.

Ruling: user's latest clarification supersedes the earlier proposal for whole-document scrolling. The existing intended split reader behavior is retained; fix its containing viewport only.
Ruling: test environment uses isolated worktree and webpack with temporary CSS-loader configuration because the installed dependencies are a junction outside Turbopack's root. These harness settings must be removed from the product diff before commit.

Completed: scoped fixes and test/review steps passed; see 2026-11-14 handoff. Generic request error pending evidence. New VM release not yet authorized.
