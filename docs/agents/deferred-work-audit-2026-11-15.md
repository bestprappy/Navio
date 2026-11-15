# Deferred work and follow-up audit ? 2026-11-15

Engineering backlog requested by the user. Cross-checked supplied conversation, current client source, Trip origin/main, latest release handoff and historical plans. This is not an academic feature report. Older implementation-pending notes are superseded by later releases. No application fix is authorized or performed by this audit.

## Priority refresh after daily-reader deployment

Verified2026-11-15 against root main e393a0e/client a6642ef and live read-only APIs. No application fixes performed. Prioritize actual defects and acceptance checks ahead of new feature scope.

1. Current Favorites integration: live /api/saved-content/favorites with valid-format nonexistent plan identity still returns upstream404. Current source has gateway security allowance AND configuration-server route; exact runtime/config/handler cause not established. Diagnose before changing code; do not assume missing implementation.
2. Seasonal words in Plans search: live Kyoto Spring still returns blocked=true, matchingTotal0/relatedTotal0. Explicit spring/summer/autumn/winter block remains in released SearchIntentParser; separate from working seasonal collection filters.
3. Live signed-in catalogue round-trip QA: Saved reopen, My List add, duplicate prevention, planner reload, publish and copy. Fixture/read-only release checks are complete; actual-account full journey remains unverified.
4. Billing closure and residual API cost audit: ticket outcome/credit unknown; inspect actual SKU usage and verify concurrency/failure behavior of existing quota counters with backend owner. Catalogue discovery zero-call verification does not mean maps/routes/legacy EV costs are zero.
5. Requested substantial Auto Add / Plan Charging Stops redesign: not completed by teammate incremental fixes. Rebaseline ownership and existing optimizer before changing algorithm/UX.
6. Final reader/sample-content acceptance: request fresh concrete feedback on remaining Shared Plan/Guide visual/content issues. Do not treat broad earlier dissatisfaction as permission for an unrelated redesign.
7. Generic request rejection remains awaiting operation/path/status; no actionable reproduction. Separate from resolved expired-session error and repeated duplicate-key warnings.
8. Repository/tooling cleanup: reconcile root working changes/remote divergence with owners; preserve user notes/config/logs/stashes; standardize documented test loader and stale generated type cleanup. Not a blanket commit/reset.

Defined but held scopes: further Places catalogue destinations/content ownership; Release2 paid lookup requiring explicit separate approval; Saved custom categories; durable public Shared Plan cover override (private cover upload already exists); Starting Part uploaded images; preserved Places editorial experiment (engineering-only register, report exclusion unchanged).

Less-defined/owner-dependent ideas: self-hosted transit expansion and operational readiness; optional public Garage profile consent and substantial-plan-update notifications; current rebaseline of old Phase4C.1 acceptance; Vercel hosting integration decision; direct gateway view-receipt abuse hardening; archived Admin/hybrid-energy branch disposition. These are not approved implementation tasks. DMs, closed-app Web Push/email and live collaboration were excluded scope, not outstanding promises.

Completed/superseded: daily browser/UTC-day Total Views and lifetime signed-in Unique Visitors, both Shared Plan reader Navbar routes (root e393a0e workflow43693217039 ALL SUCCESS); catalogue-only Places Release1 already on main and VM (root1b31aa0/client076b47c); no extra push needed for teammates to see API reduction. Earlier per-opening repeat-count and pending anonymous-unique-policy descriptions below are historical; anonymous lifetime unique visitors are not required under the latest confirmed policy. Existing ratings/comments, search/discovery/filter interfaces, Saved/community features, publication/copy features, sample batches/Guide expansion and cover fixes remain implemented. Their existence does not substitute for outstanding real-account acceptance checks.

## Confirmed held / later work

1. **Saved custom categories/collections:** explicitly paused by user. Proposed mixed plans/guides/places collections, multi-membership and deleting a collection without deleting its items remain a proposal, not an implemented promise.
2. **Shared Plan custom publication cover:** explicitly held. Private trip cover upload/crop/remove now exists (teammate implementation, owner-only TripCoverService/V30). Durable owner cover selection in a public Shared Plan and its public/copy lifecycle must not be inferred from that private feature or reader-preview override. Reconfirm desired scope before resuming.
3. **Major Plan Charging Stops / Auto Add review:** user wanted substantial algorithm/UX rework after Shared Plan work. Existing optimization and later teammate charger fixes are not evidence that this requested broader redesign was completed. Re-audit current code with backend owner before planning it; do not overwrite teammate EV work.
4. **Places Release 2 paid lookup:** separate approval required. Catalogue-only Release 1 is live; explicit limited external lookup, signed-in admission, per-user/global caps, bounded photos/retries/pages, protected planner capacity, concurrency/accounting-failure/admin-override verification and provider-result retention policy remain gated work.
5. **Places coverage beyond exhibition snapshot:** ten Bangkok places only. Additional destinations, fuller categories/food selections and post-event content ownership/refresh need a separate scope. No daily maintenance is required for the fixed D-Day snapshot; worldwide/live coverage is not implemented.
6. **Places editorial:** preserved disabled experiment and long-form research/qualification pipeline remain on hold. See docs/deferred/places-editorial.md. PLACES_EDITORIAL remains EXCLUDE_FROM_REPORT, including academic future-work sections, unless the user explicitly changes reporting scope. Listing its engineering deferral here does not restore it or change that rule.
7. **Starting Part uploaded images:** user selected formatted text, links and lists first. Images/storage/publication/copy support were excluded from that version. Optional later scope, not an approved implementation task.
8. **Further Shared Plan reader polish:** user accepted preview as usable but said more UI fixes would follow. Many subsequent targeted improvements shipped. General final visual acceptance remains open; unspecified remaining fixes need fresh feedback rather than assumptions.
9. **Anonymous unique-visitor policy:** earlier signed-in-only view decision was superseded. Superseded by deployed daily-browser Total Views on2026-11-15; Unique Visitors remains lifetime distinct signed-in accounts. Anonymous lifetime unique visitors are not required by the current user decision.

## Unfinished checks / investigations (not intentionally postponed features)

- **Live catalogue round trip:** actual signed-in Save/reopen, Add to Plan/My List, itinerary reload, publication and copy verification against VM. Payload/atoms/serialization/public-reader and browser fixtures pass; 28 live read-only catalogue/photo checks pass. Computer Use halted because browser URL could not be identified reliably; no real account writes were tested.
- **Google billing case:** support/refund outcome unknown. Need actual charged-period project/API/SKU/day breakdown and credits; no verified attribution or measured whole-project savings percentage. New key is not a budget guarantee. Catalogue eliminates tested discovery provider calls; legacy places, maps/routes and EV remain separate costs.
- **Current Favorites routing:** read-only live GET /api/saved-content/favorites?identity=plan:audit-no-such-publication returned upstream404 at /v1/saved-content/favorites. Valid-format nonexistent identity is used, not a private publication. Current source contains both the gateway security allowance and configuration-server route; runtime routing/configuration or service handling still needs diagnosis. Counts are implemented; audit made no fix.
- **Season-word Plans search:** live /api/shared-plans/search?term=Kyoto%20Spring&country=&page=0&size=6&sort=relevance returned matchingTotal0/relatedTotal0/searchAssist.blocked=true and evidence notice. Trip origin/main parser blocks winter/summer/autumn/spring. Collection/seasonal landing behavior is separate. Revisit without reintroducing the rejected Google-like suggestion design.
- **Generic request rejection:** user will provide operation/path/status if recurring; empty console object is insufficient. Do not claim the unidentified api-client request was fixed. Older expired-session profile issue was resolved by sign-in and is distinct.
- **Production signed-in QA:** private trip uploaded cover, denser EV search, favorites after routing repair and publication/copy round trip need real-account acceptance, not just unit/fixture claims.
- **Vercel red check:** previous Navio-Client deployment integration failure was separate from successful university VM release. Whether to repair/use/remove that hosting integration needs owner decision; do not change it automatically.

## Older engineering proposals ? revalidate before resuming

- Phase4C.1 post-incident planner/EV integration acceptance was explicitly held in October. Old migration numbers/local branch issues are historical and must not be replayed. Rebaseline all-days/save/reopen/Garage/SoC/optimization apply/reopen checks on current released code.
- Self-hosted transit expansion: earlier local Tokyo OTP proof is not global production coverage. Additional valid feeds/operators/cities, graph dates/refresh, coverage-aware routing, departure-time UI and production readiness were separate follow-ups. Current deployment has newer transit work, so determine what remains with its owner before scheduling it.
- Profile/notifications plan optional phases: explicit substantial-public-plan-update announcements and opt-in public Garage make/model display. Public Garage profile consent is distinct from Garage included in a Shared Plan, which exists. Email/closed-app Web Push, DMs and live collaboration were excluded scope, not promised missing placeholders.
- Archived feat/admin-console and September feat/hybrid-energy-model branches need owner disposition; never merge merely because they exist. Core admin/EV features already exist.
- Repository housekeeping: ordinary root local dev diverges from current remote; user Nov09 notes and local configs/logs/stashes remain intentionally preserved. Reconcile safely later, no force/reset or blanket commit. Generated stale route-type/test-runner differences are tooling follow-ups, not product features.

## Resolved / superseded ? do not reimplement

- Guides discovery and separate catalogue-grounded Plans/Guides search; five Shared Plan collections, Guide collections, sorting and filters.
- Ratings/comments/reader sharing, Saved Guides, Saved Community history/votes/comments, full visual Saved cards and navigation.
- Shared reader Starting Part, selected My List/Garage/itinerary/budget and editable copy flow; insertion shortcuts and full-note default disclosure.
- Sample batches: earlier15 seasonal/event plans, requested30 extra plans,20 added Guides; twenty maintained Guides expanded in place to219 places/77 sections (9?19 each). Cover repairs for76 sample plans and distinct Kyoto seasonal cover photos shipped.
- Guide empty-section/dropdown/photo/duplicate-key repairs and reader statistics shipped. New favorites404 is a routing exception, not proof none of those features exist.
- Catalogue Release1 deployed root1b31aa0/client076b47c, workflow43685663127 success. No pending release approval for this revision.
- Poster/sticker/profile outputs were delivered; no new redesign requested. Advisor/print/physical QR acceptance was not independently confirmed.
- Browser-extension hydration warning was explicitly set aside by user, not a required repair. Help links were deliberately removed in later Home work because no Help route existed; do not revive automatically. Desert Escapes was explicitly cut, not postponed. AI assistant from rejected poster was not an approved product feature.

Suggested priority for next discussion: live catalogue round-trip QA and favorites gateway; billing/limits; focused seasonal search repair; then the requested Auto Add redesign. Held features remain held until user chooses them.

##2026-11-15 follow-up: Favorites fix ready; seasonal diagnosis only

Favorites root cause is now established: the actual production-mounted root .deploy/config/api-gateway.yml lacked the exact public aggregate path, unlike the server source's development configuration. Root dev514ea15 adds that one route and read-only deployment response verification;7 smoke regressions, YAML and shell syntax checks pass. Main/VM unchanged pending release approval. Do not list the repair as live until that release succeeds.

Seasonal query diagnosis:14 read-only cases,8 season-word queries rejected by SearchIntentParser;6 controls not blocked. Kyoto control returns the existing Spring/Autumn publications, demonstrating rejection before matching rather than missing records. No seasonal implementation changes authorized or made; proposed targeted handling needs user review. Full evidence in output/seasonal-search-diagnosis.json and latest handoff.
