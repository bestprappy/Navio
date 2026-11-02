# Navio tutorial landing page implementation plan

Date: 2026-11-02  
Status: Proposed implementation; no tutorial feature implemented by this document.

## 1. Objective

Build a beautiful, practical learning experience that shows travelers how to use Navio. A new visitor should understand the planning workflow, try a small demonstration, find help for a specific task, and continue into the real app.

Use **Motion for React** as the animation library. Motion for React is the current name of the library previously called Framer Motion. New implementation should use the `motion` package and `motion/react` imports.

The visual centerpiece is one sample trip that develops from an idea into an itinerary as visitors choose tutorial steps. Beauty should come from the actual product, clear typography, cohesive colors, meaningful movement, and generous spacing.

## 2. Scope and defaults

### First release

- Public `/learn` landing page, accessible without signing in.
- A prominent Learn Navio link from the existing public navigation, plus a discoverable help entry inside the app using the existing navigation pattern.
- Five-step interactive product walkthrough.
- Task-based tutorials and tips for Planner, Explore, Budget, EV, and Sharing.
- Small local practice interaction with reset and a clear transition into real trip creation.
- Responsive desktop and mobile layouts, light/dark themes, keyboard operation, and reduced motion.
- Existing `/` homepage remains the entry page; add a contextual link to `/learn` instead of replacing the homepage as part of this scope.

### Later, independent enhancements

- Optional Driver.js tours inside the real planner, only after the landing experience is complete.
- Separate tutorial detail routes or MDX when the amount of content warrants them.
- Short captioned recordings for actions that are difficult to teach with the interactive preview.
- Cross-device learning progress only if a product need justifies backend work.

This work does not require backend endpoints, migrations, a CMS, a new mapping provider, or changes to production sample plans. Public sample records must not be modified to create the tutorial. Do not introduce deferred Places editorial functionality into this experience.

## 3. Repository baseline and implementation preflight

Observed in the working tree on 2026-11-02:

- `client/app/page.tsx` contains an existing public landing page and a Bangkok-to-Khao-Yai planner mockup. Its displayed figures are not evidence of live functionality or current routing/charging data.
- Existing routes include `/planner`, `/planner/new`, `/planner/[planId]`, `/explore`, `/explore/shared/[token]`, and `/share/plans/[token]`.
- The client already has shadcn, Tailwind, Lucide, Jotai, TanStack Query, and Embla installed. Motion was absent from the inspected dependency manifest.
- `client/app/globals.css` defines semantic theme tokens and Plus Jakarta Sans as the sans-serif family.
- The root and child repositories contain unrelated unfinished work. Preserve it and inspect current state before implementation.

Before writing code:

1. Read `AGENTS.md`, the current handoff/session log, and `client/AGENTS.md`.
2. Read relevant Next.js guides under `client/node_modules/next/dist/docs/`; do not assume older App Router behavior.
3. Apply the repository frontend-design skill and review the actual existing components, theme tokens, navigation, and authentication boundary.
4. Check each proposed teaching action against the current app. Record the real control label, actual interaction, route, signed-in requirement, and any limitations.
5. Distinguish shipped behavior from local unfinished features. Exclude demonstrations that depend on unverified functionality.
6. Confirm `/learn` can be served publicly through existing auth/proxy rules and that real-app CTAs preserve the intended destination through sign-in.

## 4. Technology decisions

| Need | Choice | Implementation guidance |
| --- | --- | --- |
| Layout and controls | Existing Tailwind + shadcn components | Reuse semantic tokens and accessible primitives; customize composition to Navio |
| React animation | Motion for React | Add `motion` in the client during implementation; keep animated code in small client components |
| Icons | Existing Lucide | Use consistent size/stroke; pair unfamiliar icons with text |
| Content | Typed local data in `data.ts` | Keep tutorial text, steps, tips, and illustrative records separate from rendering |
| State | Local React state initially | Use Jotai only if state genuinely needs to cross independent app areas |
| Server data | Existing TanStack Query if needed later | The initial tutorial should not require authenticated API calls |
| In-app spotlight tours | Driver.js, optional later phase | Load on request, theme locally, and verify focus behavior and route cleanup |
| Long-form tutorial authoring | MDX, optional later phase | Adopt when several maintained guides justify a content pipeline |
| Recordings | Native video | Poster image, explicit playback controls, captions/transcript, no autoplay audio |

Do not add GSAP in the first release. Reconsider GSAP with ScrollTrigger only if a specific approved scene requires complex pinned and scrubbed animation timelines. Basic scroll progress, reveals, and step transitions are within Motion's scope. Avoid having two libraries control the same element.

## 5. Information architecture and page design

### Page order

1. Existing Navio navigation with a clear Learn entry.
2. Hero: **Your first trip, from idea to itinerary.** A short explanation, **Try the walkthrough**, and **Create a trip**.
3. Interactive five-step walkthrough with a large product preview.
4. Quick tutorials grouped by user task.
5. Practical tips with concise examples and contextual links.
6. Short FAQ for verified common questions and a final **Create a trip** action.
7. Existing footer.

### Desktop composition

```text
Navio navigation                                       Learn / Sign in

Your first trip, from idea to itinerary.   [Large sample planner preview]
One clear explanatory sentence.           [Same trip throughout the page]
[Try the walkthrough] [Create a trip]

[Step selector + explanation]              [Preview of selected action]
[Previous] [Next]                          [Try it / Reset demo]

Quick tutorials: Planner / Explore / Budget / EV / Sharing
[Task and outcome] [Task and outcome] [Task and outcome]

Useful tips + focused screenshot examples
FAQ                                      [Create a trip]
```

Use a sticky preview only where viewport height allows it. Explicit step selection is the primary navigation. Scrolling must remain native and must never trap visitors in an animation.

### Mobile composition

- Place the active step explanation directly above its preview.
- Use a compact step selector with accessible labels and Previous/Next controls.
- Adapt the preview to a readable narrow composition; do not shrink a desktop screenshot until labels become illegible.
- Avoid long pinned scenes, horizontal page overflow, and controls that overlap the preview.
- Tutorial topics wrap or use a properly labeled scrollable control; content remains reachable without dragging.

### Visual contract

- Preserve the existing type family and semantic background, surface, foreground, primary, muted, border, and focus tokens. Resolve exact current values in the implementation design pass; do not invent a separate brand palette.
- Use a clear headline/body/caption hierarchy and readable text lines, normally below 80 characters.
- Give the product preview the strongest visual emphasis. Avoid turning every paragraph into an identical bordered card.
- Use destination imagery sparingly and keep one consistent sample-trip identity throughout.
- Every decorative animation must have a purpose; there should be no continual floating, flashing, or looping emphasis around tutorial text.
- Demonstration figures and synthetic maps must be labeled as illustrative where they could otherwise look live.

## 6. Walkthrough content

Use a local illustrative Bangkok-to-Khao-Yai weekend trip as the starting content direction, subject to verification of recognizable places and app terminology. It is a tutorial fixture, not a new published Navio Team plan.

| Step | User outcome | Demonstration | Teaching note |
| --- | --- | --- | --- |
| Start your trip | Understand the starting details | Choose destination and dates in a simplified preview | Match the real creation flow and labels |
| Collect places | Understand My List | Add a place to the sample list | Explain how the list relates to the itinerary without implying unsupported automation |
| Build your days | Understand itinerary organization | Place a saved stop into a day and change its order | Provide click/keyboard controls even if drag is supported |
| Plan the details | Understand budget and EV options | Show an editable example budget; an optional EV view explains Garage and charging stops | EV guidance is optional; never present sample charge times or availability as live |
| Share your plan | Understand sharing choices | Show a demonstration of the verified sharing controls | Explain private draft, share link, and Explore listing only as supported by current behavior |

Each step contains a short title, one goal, one action, a visible result, and one useful tip. Visitors can jump directly to a step and return to earlier steps without losing navigation control.

The demo should use deterministic state: selecting a later step produces a complete valid preview even if earlier steps were skipped. Reset restores the initial local fixture. No demo action calls a real create, update, publish, or share API.

## 7. Tutorials and tips

Initial topics should be short enough to read inline, with stable section anchors. Add separate detail pages only when they improve readability.

| Topic | Initial tutorial candidates | Tip direction |
| --- | --- | --- |
| Planner | Create a trip; add a stop; arrange a day | Leave room between stops; put useful context in notes |
| Explore | Find a place; inspect a shared plan | Explain which actions save, open, or reuse content after verifying their actual semantics |
| Budget | Add and edit an example cost | Clearly distinguish an illustrative estimate from an actual booking price |
| EV | Choose a vehicle in trip Garage; inspect charging stops | Explain the information the app actually provides and its freshness |
| Sharing | Open sharing settings; understand visibility | Show the difference between an accessible link and a public listing where supported |

For every tutorial, keep typed metadata for stable ID, topic, title, summary, steps, relevant app destination, media if any, and last review date. Use strong types with no `any`.

Initially, topic filtering and anchor navigation are sufficient. Add search only when the content inventory makes it useful. Filtered empty states must explain how to see all topics again.

## 8. Motion and interaction specification

- Use Motion for state-driven preview transitions, active-step emphasis, and continuity when a sample item changes position.
- Prefer opacity and transform for ordinary movement. Use layout animation selectively where it helps explain an itinerary change.
- Use shared layout identifiers only inside the isolated demo so unrelated app elements cannot animate together.
- Starting timing direction: approximately 150-220 ms for small feedback and 250-400 ms for preview transitions, refined through visual review.
- Keep visible controls responsive during transitions. Rapid step changes must resolve to the last selected step without stale content or queued animations.
- Do not autoplay through the tutorial. Do not animate entire paragraphs one letter at a time.
- Use CSS sticky positioning for the desktop preview when appropriate; a complex scroll timeline is unnecessary.
- Respect system reduced-motion preference through Motion's configuration/hooks and CSS. Substitute immediate state changes or restrained fades for spatial movement, while preserving all information.
- Use concise polite announcements for user-triggered demo outcomes when needed; avoid announcing every animated frame.

## 9. Proposed client structure

Adapt names to established repository conventions during implementation:

```text
client/app/learn/page.tsx                 Public server-rendered page and metadata
client/app/feature/learn/data.ts          Typed tutorial content and local sample fixture
client/app/feature/learn/types.ts         Content and demo-state contracts
client/app/feature/learn/learn-page.tsx    Page composition
client/app/feature/learn/walkthrough/     Compound walkthrough components and local state
client/app/feature/learn/tutorials/       Topic controls and tutorial content
client/app/feature/learn/tips/            Reusable tip presentation
client/public/tutorials/                 Optimized media used by this experience
```

Suggested compound API: `Walkthrough.Root`, `Walkthrough.Steps`, `Walkthrough.Preview`, and `Walkthrough.Controls`. Separate presentational preview components from authenticated planner hooks. Reuse safe existing UI pieces where practical, but do not mount the full live planner just to render a demonstration.

Keep page headings, explanatory text, tutorial links, and a usable initial preview in server-rendered output. Load interaction code only for the walkthrough and filters. A JavaScript failure must not leave a blank learning page.

## 10. Optional in-app tour phase

After the landing page is delivered, evaluate a small user-started tour from Help or a **Show me in the planner** action.

- Use stable `data-tour` targets rather than CSS classes or translated text selectors.
- Only start when the correct route, authorized trip, and required controls exist.
- Wait for real loading states to resolve. If a target is unavailable, provide an explanation or exit cleanly rather than highlighting an unrelated element.
- Offer Skip, Back, Next, Close, and Replay; support Escape and restore focus to the initiating control.
- Handle dialogs, scrolling containers, viewport changes, and route transitions explicitly.
- Tours explain actions; they must not silently modify a trip, create a public listing, or change privacy settings.
- Persist dismissal locally only if useful. Any storage failure must be harmless. Keep storage versioned and free of private trip content.
- Do not automatically show tours every time users enter the app.

## 11. Accessibility, assets, and performance

- All interactive controls work by keyboard with visible focus and clear accessible names.
- Use correct tab semantics only if the step selector behaves as a tab interface; otherwise use ordinary buttons with an announced current state.
- Text contrast should meet WCAG AA; status is never communicated by color alone.
- Provide useful image descriptions, captions/transcripts for instructional recordings, and controls to pause media.
- Respect reduced motion from initial render, and ensure text remains available when animation is disabled.
- Use approved assets or captures with synthetic/example data. Do not expose real travelers' names, private itineraries, tokens, or account details.
- Reserve media dimensions to avoid layout shifts; optimize images and lazy-load below-fold recordings.
- Avoid loading live map SDKs, tour code, or authenticated service requests on the initial learning page. Use a clearly illustrative lightweight map graphic where needed.
- Use browser measurements to catch animation jank and layout shifts; library choice alone does not guarantee smooth performance.

## 12. Delivery phases

### Phase 1: Content and visual contract

Audit supported actions and navigation. Create the typed content inventory, one consistent sample trip, and desktop/mobile compositions. Review light/dark theme choices and reduced-motion behavior. Deliver a design specification grounded in the current Navio UI before implementation.

Exit: Each teaching claim maps to a verified app action; the layout and preview content are defined.

### Phase 2: Public learning page

Add `/learn`, static tutorial content, topic navigation, FAQ, metadata, and working app links. Integrate existing navigation/footer. Establish accessible responsive behavior before adding motion.

Exit: Signed-out visitors can read and navigate the complete page; real-app links follow the existing sign-in flow.

### Phase 3: Interactive walkthrough and Motion

Add the `motion` dependency, isolated deterministic demo state, five-step navigation, practice controls, reset, and focused animation. Add the reduced-motion alternative and keyboard announcements where required.

Exit: All steps work in any order, and no practice action mutates real data.

### Phase 4: Verification and visual refinement

Review screenshots in desktop/mobile and light/dark themes; inspect readability, clipping, layout shifts, loading behavior, rapid interactions, and reduced motion. Refine spacing, copy, assets, and transitions based on the rendered result.

Exit: Acceptance checklist passes and any limitations are documented.

### Phase 5: Optional expansion

Implement in-app tours, longer tutorials, MDX, or recordings only where the completed experience demonstrates a specific need. These are not prerequisites for releasing the learning page.

## 13. Acceptance checklist and verification

- [ ] `/learn` is publicly accessible and linked from appropriate public/app navigation.
- [ ] Existing homepage and unrelated navigation flows still work.
- [ ] Tutorial actions and labels match the current app; illustrative values are clearly presented.
- [ ] Five steps are reachable directly and sequentially, including when visited out of order.
- [ ] The practice interaction and reset work without network writes or access to private trips.
- [ ] Real-app CTAs reach valid routes and preserve the intended destination through authentication.
- [ ] Topic controls, anchors, FAQ, and help links work with keyboard and pointer input.
- [ ] Mobile preview text is readable, controls are reachable, and no horizontal page overflow occurs.
- [ ] Light and dark themes use Navio tokens consistently.
- [ ] Reduced motion preserves content and functionality; no forced autoplay or scroll trapping occurs.
- [ ] A failed/delayed media load does not hide tutorial instructions or shift controls unexpectedly.
- [ ] No live map SDK, optional tour bundle, or authenticated API call is required for the initial page.
- [ ] No browser hydration errors or console errors occur during the walkthrough.

Run repository-standard type checking, changed-file lint, and a production build. Add focused behavior tests for demo transitions, jumping between steps, reset, and any destination/auth logic introduced. Do not add tests that only mirror static copy or styling. If the optional tour phase is implemented, test missing targets, cancellation, route cleanup, and focus restoration.

Use browser verification around 375 px, tablet, and desktop widths, plus a short-height viewport and 200% zoom. Check keyboard operation and reduced motion explicitly. Verify actual CTA/auth behavior in an appropriate environment; do not treat a screenshot as proof of integration.

## 14. Git and release boundaries

Implementation belongs on an appropriate client feature branch from `dev`, with unrelated work excluded. Follow nested repository commit order and push the child before updating its parent pin. Root `main` pushes deploy production; read `docs/agents/release.md` before any release. Documentation-only session work goes to a docs branch and local `dev`, never to root `main` on its own.

## 15. Reference documentation

- [Motion for React](https://motion.dev/docs/react)
- [Motion scroll animations](https://motion.dev/docs/react-scroll-animations)
- [Motion accessibility](https://motion.dev/docs/react-accessibility)
- [GSAP ScrollTrigger](https://gsap.com/docs/v3/Plugins/ScrollTrigger/) — alternative only if the interaction requirements change
- [Driver.js configuration](https://driverjs.com/docs/configuration) — optional tour phase
- [Next.js MDX guide](https://nextjs.org/docs/app/guides/mdx) — optional content expansion

Recheck current documentation and installed package APIs during implementation.
