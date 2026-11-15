# Daily reader views and Shared Plan navigation

Approved scope: Total Views once per browser per publication per UTC calendar day, signed in or out; keep lifetime unique signed-in accounts. Replace only Shared Plan reader app sidebar with normal top Navbar, retaining independent left scrolling and right map.

Implementation uses the existing first-party visitor cookie and backend atomic UUID receipt ledger. Server canonicalizes receipt by browser, source-qualified resource and UTC date; client IDs cannot bypass daily dedup. Always forward authenticated replays to attach unique accounts. Preserve historical totals. Returning visible reader resets next day. No migrations/provider calls. Clear cookies or a different browser establish another browser identity; no fingerprinting.

Completed: validation regressions (including midnight/overnight, retries, malformed/cross-origin requests and distinct sources);840 frontend tests; TypeScript/scoped lint; exact production Turbopack build; desktop/mobile browser checks using local backend fixture. Main release separately gated. Feature client a6642ef.
