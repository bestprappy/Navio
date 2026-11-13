# Community navigation and Before you go alignment

**Requested design:** Remove the Add note action's extra right margin, preserving the note editor and shared-plan behavior. Add a collapsed Navio menu at the top of the Community sidebar using the existing accessible accordion, with Home, Dashboard, Explore, Community and Help. Label the existing Community menu; highlight the Navio Community link across community subpages. Use UsersRound for Community Explore, distinct from Navio's Compass. Preserve community feed/group behavior and bottom Back to Navio.

**Scope:** Frontend only, isolated existing client checkout. No backend, Google/provider calls, real account/data mutations or deployment unless separately approved.

- [x] Inspect actual margin, sidebar and existing accordion; add failing navigation route/active-state tests.
- [x] Implement focused alignment, typed navigation configuration and reusable Navio menu component.
- [x] Verify existing tests, types/lint/build and browser disclosure/keyboard/link/highlight/footer/layout behavior with synthetic data; block all external traffic.
- [x] Integrate verified frontend into active dev, preserve user edits, save required notes and summarize.
