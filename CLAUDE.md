# Claude Instructions

Please read the .claude rules folder before making changes.

## Documentation Links

- docs/api/Navio Api Documentation.md
- docs/api/Navio Open API.yaml
- docs/database/Navio Database.md
- docs/summary/Navio Architecture.md


## Frontend Standards

Follow `.claude/rules/client/code-style.md` and `.claude/rules/client/styling-guide.md.`

Key requirements:

- Next.js App Router with TypeScript.
- Compound component pattern for complex UI.
- Reusable widgets over one-off page sections.
- Jotai for client UI state.
- TanStack Query for API and server state.
- Strong typing only. Avoid any.
- Place mock data in data.ts.
- Enforce accessibility and keyboard support.
- Use token-driven styling. Avoid default Tailwind palette for brand colors.

## Backend Standards

Follow `.claude/rules/server/code-style.md`, `.claude/rules/server/api-conventions.md`, and `.claude/rules/server/testing.md.`
