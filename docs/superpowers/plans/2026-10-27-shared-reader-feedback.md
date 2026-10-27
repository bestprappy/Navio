# Shared reader feedback implementation

Approved scope: fix hero seam/attribution; restore authored multi-mode route details in shared drawer and geometry on both maps; improve stop cards and day distinction, using Wanderlog for reference while retaining Navio. Owner mode is In plan; reader comparisons are local and never persisted/copied. Do not change normal planner visuals or deferred social/publication controls. User is asleep: halt on any important unresolved product decision.

- [x] Cover: one active attribution strip, footer layout separates credits from image/overlay. Preserve existing card layout. Regression red then green.
- [x] Routes: reuse route-query/travel-options engine and shared map drawing. Only adjacent located public itinerary stops; never private anchors, lists, cross-day or gaps. Current estimates labeled. Preserve mode/validated transit choice in new public snapshot and copying through additive nullable DTO fields, no schema migration. Old frozen snapshots show mode-not-shared and computed local suggestions; no fabricated author choice or deployment.
- [x] Visuals: image-led stop composition and readable owner tip; color-coded numbered day header, summary and route continuity. Scoped shared-reader components only.
- [x] Verify frontend/backend tests, TypeScript/lint/build, read-only API/provider checks and visual UI if available. Fresh review, fixes, docs-only session notes commit.

Ruling: Transport publication metadata is needed to correct the missing existing capability, so add it now without new publishing/social controls. Fields are bounded and optional; legacy snapshots remain readable. Do not bump sanitizer version for an additive disclosure of public-stop leg choices; existing private-anchor redaction remains enforced and tested. No dates are inferred for hidden schedules; routes are current public-stop estimates.

Verification limits: preview HTTP200; live feed HTTP502; interactive browser acceptance and real provider geometry remain pending. Backend infrastructure startup tests require config/dependencies; unit/controller suite passed with an isolated test config. User review remains next.
