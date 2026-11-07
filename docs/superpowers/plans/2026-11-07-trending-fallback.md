# Trending discovery fallback

**Approved design:** Rolling 30 UTC dates including today. Weight daily views plus three times copies by recency (30 for today down to 1 for day 29). Do not backfill unknown historical dates. In the Trending collection, keep qualified recent activity first; fill with popular plans (lifetime copies/views), then recently shared plans. Label each tier honestly. Keep all eligibility/search/country/duration/theme constraints, stable pagination, deterministic ordering and explicit sorting within tiers. Other discovery sections remain unchanged. No migration, provider calls, production writes or unapproved release.

- [x] Add failing ranking, fallback, pagination, filter and real-PostgreSQL boundary/weight tests.
- [x] Implement 30-day score query and tiered Trending membership/ranking with additive per-token discovery labels.
- [x] Render accessible compact labels in Trending cards, update window/empty copy; reuse card and query components.
- [x] Run backend tests with disposable real PostgreSQL; client suite/types/lint/build and offline browser acceptance.
- [x] Review/integrate verified changes preserving teammate safeguards; write handoff and concise results. VM release explicitly approved after verification; monitor rollout before claiming live.
