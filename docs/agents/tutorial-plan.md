# Navio first-time highlight tours: implementation plan

Date: 2026-11-13 (supersedes the 2026-11-02 `/learn` landing-page plan)
Status: **Implemented 2026-11-13** in client commit `17993b2` (`feat/onboarding-tours`, merged to client `dev`; root `dev` pin bumped). Feature tours and two fixes followed in client `017327d` (see §13). Not on `main` or production yet. The user asked to build it now, superseding the earlier "build last" decision. See §12 for what shipped and where it differs from this plan.

## 1. Objective

Show first-time users short tips and tricks inside the real app by highlighting actual controls with spotlight tours: one tour each for the **Dashboard**, the **Trip planner**, and **Community**.

User decisions, 2026-11-13:

| Decision | Choice |
| --- | --- |
| Scope | Highlight tours only. The public `/learn` landing page, Motion walkthrough, tutorial cards and FAQ are **dropped**. |
| Trigger | Each tour **auto-starts once**, the first time a user opens that area. A **Help button** replays it any time. |
| Areas | Dashboard, Trip planner, Community. (Explore and a separate EV/Garage tour are out of scope; the planner tour includes a Garage stop when that section is shown.) |
| "Seen" memory | **Browser only** (`localStorage`). No backend, migration or release risk. A new device or browser shows each tour once more, which is accepted. |

Out of scope: backend endpoints, migrations, account-level progress, Motion, MDX, recordings, Explore tour, deferred Places editorial content, and any change to Navio Team sample plans.

## 2. Technology

| Need | Choice | Notes |
| --- | --- | --- |
| Spotlight and popover | **Driver.js** (MIT, small, no dependencies) | Not installed yet. Check the current version and API at build time. **Load it with dynamic `import()` only when a tour starts**, so pages don't pay for it otherwise. |
| Theming | Navio tokens from `client/app/globals.css` | Style the popover through `popoverClass` with existing semantic tokens (card, foreground, muted-foreground, primary, border, focus ring). Must work in light and dark themes. No default Tailwind palette. |
| Shared state | Jotai | One `activeTourAtom` so only one tour runs at a time and the Help button knows the current state. |
| Content | Typed `data.ts` per feature | Step text lives apart from rendering. Strong types, no `any`. |
| Element targets | `data-tour="<tour>.<step>"` attributes | Never CSS classes or visible text, which change with styling and copy edits. |

## 3. The three tours

Rules for every tour: at most 7 steps, one short title plus one or two sentences each, ending with a "Replay this from Help any time" step. The control names below were read from `origin/dev` on 2026-11-13. **Check them again at build time**, since the UI will have changed by then.

### 3.1 Dashboard: `/dashboard` (`app/feature/planner/planner-home.tsx`, `_components/dashboard/*`)

Starts only for a signed-in user, after the trip query has settled (not on the skeleton or the error state).

| # | Target (`data-tour`) | Real control | Tip |
| --- | --- | --- | --- |
| 1 | `dashboard.overview` | "Your travel dashboard" region | Your upcoming and past trips live here. |
| 2 | `dashboard.new-trip` | **Start planning** / sidebar **New trip** | Start a trip with a destination and dates. |
| 3 | `dashboard.trips` | "Upcoming trips" list (skip when empty) | Open a trip to keep planning; its menu has options. |
| 4 | `dashboard.preparation` | "Before you head out" planning companion | A checklist of what to prepare: dates, places, charging stops, packing. |
| 5 | `dashboard.explore` | **Explore plans** / **Browse guides** | Borrow ideas from shared plans and guides. |
| 6 | `dashboard.notifications` | Notifications bell | Replies, reactions and plan activity show up here. |
| 7 | `dashboard.help` | Help button | Replay this tour any time. |

A brand-new user usually has no trips, so the tour must look right on the empty dashboard. Step 3 is skipped when its target isn't there.

### 3.2 Trip planner: `/planner/[planId]` (`app/feature/planner/planId/planner-detail.tsx`)

Starts only for the **trip owner** on an editable trip, after trip metadata has loaded. It **never** starts on read-only or shared views (`/share/plans/[token]`, `/explore/shared/[token]`, `/preview/shared-plan`, `readOnly` planner rendering).

| # | Target | Real control | Tip |
| --- | --- | --- | --- |
| 1 | `planner.trip-info` | Trip info card: name editor and dates | Rename the trip and change dates here. |
| 2 | `planner.my-list` | **My List** section, including **Add to** day menu | Collect places first, then add them to a day. |
| 3 | `planner.itinerary` | Itinerary days, expand/collapse, **Day to show** | Each day holds its stops in order. |
| 4 | `planner.auto-plan` | **Auto plan** entry | Let Navio suggest a day order. Nothing changes until you choose **Apply plan**. |
| 5 | `planner.garage` | **My garage** (only when shown) | Pick your EV so routes and charging estimates fit your car. |
| 6 | `planner.budget` | **Budgeting**, then **Add expense** | Track estimated costs per trip. |
| 7 | `planner.trip-options` | **Trip options** menu (contains **Publish plan as a link**) | Share or manage your trip from here. |
| (end) | `planner.help` | Help button | Replay any time. |

Planner-specific handling:

- **Mobile view switch.** `plannerMobileViewAtom` stores `"itinerary" | "map"`. If the map view is showing, either switch to itinerary for the length of the tour and restore it afterwards, or skip steps whose targets aren't visible. Pick one approach in Phase 1 and test it.
- **Nested scrolling.** The itinerary sits in a scrollable drawer. Check that scrolling to each step reaches the target inside that container.
- **The tour only highlights, it never acts.** It must not open the publish dialog, run Auto plan, add places or change privacy.
- If "Plan inspiration" ships in its current form, it can replace step 5 when no Garage is shown. Keep the total at 7 or fewer.

### 3.3 Community: `/community` (`app/feature/community/community-page.tsx`, `_components/community-navbar.tsx`)

Starts once the feed and sidebar have finished loading. Guests may see it too, but any step whose target needs sign-in is skipped.

| # | Target | Real control | Tip |
| --- | --- | --- | --- |
| 1 | `community.sections` | **Home** / **Popular** | Home is your communities; Popular is everyone. |
| 2 | `community.search` | "Search Navio community" | Find posts and communities. |
| 3 | `community.create-post` | **Create post** | Ask a question or share a plan. You can attach a trip. |
| 4 | `community.create-group` | **Create a community** | Start a group around a route or interest. |
| 5 | `community.my-groups` | "Your communities" sidebar | Jump back into groups you joined. |
| 6 | `community.popular` | "Popular communities" | Good places to start. |
| (end) | `community.help` | Help button | Replay any time. |

## 4. Auto-start and Help behavior

**Auto-start a tour only when every one of these is true:**

1. The user is on that tour's route, and for the planner and dashboard, is signed in. The planner also requires the owner on an editable trip.
2. The page has finished loading: the query has settled, no skeleton is showing, no error boundary has tripped.
3. No dialog, menu, sheet or other tour is open.
4. Storage shows no `completed` or `dismissed` record for this tour at its current version.
5. At least 3 of the tour's targets exist and are visible.

Wait one frame after the page is ready before starting, so layout has settled. Never start a tour on a delay timer and never queue one up. If a condition fails, just don't start; when it fails, **don't** mark the tour as seen.

**Recording "seen":** finishing the tour stores `completed`. Skip, Close or Escape stores `dismissed`. Either one stops auto-start for that tour version. A tour cut off because the user navigated away stores nothing, so it is offered again on the next visit.

**Help button:** a reusable icon button with the visible tooltip and accessible name "Show tips for this page". It appears only on routes that have a tour.

- Placement: the app sidebar (dashboard and planner) and `community-navbar`. Final spots are decided in Phase 1 against the real layout.
- Clicking it always replays the tour, whatever storage says. It is disabled while a tour is running.
- **Known issue:** the public `components/navbar.tsx` has a **Help** link to `/help`, and no `/help` route exists on `origin/dev`. Decide in Phase 1: remove the link, point it at the in-app tours, or build a small help page. Don't leave a link that goes nowhere.

## 5. Storage contract

- Key: `navio:tours:v1:<userId>`, or `navio:tours:v1:guest` when signed out. Keying by user stops one account's progress from hiding tours from another account on a shared browser.
- Value: `Record<TourId, { status: "completed" | "dismissed"; version: number; at: string }>`.
- Every tour definition has a `version`. Bump it **only** when the tour changes in a way that matters, so users see it again. Wording fixes don't count.
- Wrap every read and write in `try/catch`. If storage is unavailable or holds corrupt JSON, treat it as "not seen" and continue without errors. Validate the parsed shape with Zod.
- Store no trip content, names or tokens. Only tour IDs, statuses and timestamps.

## 6. Accessibility

- **Keyboard:** Next / Back / Skip buttons, arrow keys, and Escape to close. Check what Driver.js does out of the box (`allowKeyboardControl`) and fill any gaps.
- **Focus:** move focus into the popover when a step opens. When the tour ends, return focus to the Help button if it started the tour, otherwise to the page's main heading or landmark.
- **Popover semantics:** add `role="dialog"`, `aria-labelledby` (title) and `aria-describedby` (description) in `onPopoverRender` if Driver.js doesn't set them. Show a step counter as text ("2 of 6"), not only as dots.
- **Visuals:** visible focus rings on every popover button, contrast at WCAG AA in both themes, and the highlighted state shown by more than color alone (the overlay cut-out plus the popover arrow is enough).
- **Reduced motion:** when `prefers-reduced-motion: reduce` is set, use `animate: false` and instant (non-smooth) scrolling.
- **Small screens:** popovers stay inside a 375px viewport and a short-height viewport, and buttons never sit under the overlay.

## 7. Proposed client structure

```text
client/components/tour/                        global, reusable
  tour.types.ts             TourId, TourStep, TourDefinition, TourRecord
  tour-storage.ts           versioned, user-keyed, try/catch + Zod
  tour.atoms.ts             activeTourAtom
  use-tour.ts               start/stop, dynamic import("driver.js"), visible-step filter, focus restore
  tour-auto-start.tsx       "use client"; props: tourId, ready, eligible
  tour-help-button.tsx      "use client"; replays the current route's tour
  tour.css                  popover theme using globals.css tokens

client/app/feature/planner/_components/dashboard/tour/data.ts   dashboard tour steps
client/app/feature/planner/planId/_components/tour/data.ts      planner tour steps
client/app/feature/community/_components/tour/data.ts           community tour steps
```

Each feature drops one `<TourAutoStart tourId=… ready={…} eligible={…} />` into its page and adds `data-tour` attributes to existing elements. The feature already knows its own `ready` (query settled) and `eligible` (owner, signed in) flags. The tour module never reaches into feature internals.

## 8. Delivery phases

1. **Audit (when building starts).** Fetch `origin/dev`. Re-check every target and label in §3 against the current UI. Choose the planner mobile-view approach, the Help button placements, and what to do with the `/help` link. Read the Next.js docs under `client/node_modules/next/dist/docs/` and the current Driver.js docs.
   Exit: every step maps to a control that exists.
2. **Tour core.** Add `driver.js` and build `components/tour/*` with storage, the atom, dynamic loading, the themed popover, focus handling and reduced motion.
   Exit: a sample definition runs, replays, persists, and survives broken storage.
3. **The three tours.** Add the `data-tour` attributes, the step data and the auto-start wiring for the Dashboard, Planner and Community, plus the Help buttons.
   Exit: each tour auto-starts once, can be replayed, and skips missing targets.
4. **Verification.** Check light and dark themes at about 375px, tablet and desktop widths, plus a short viewport and 200% zoom. Check keyboard-only use, reduced motion, an empty dashboard, a planner that is in map view on mobile, a read-only shared plan (no tour should start), sign-out and sign-in as a different user, and navigating away mid-tour.
   Exit: the checklist in §9 passes.

## 9. Acceptance checklist

- [ ] Each tour auto-starts exactly once per user per browser, only once its page has loaded, and never on read-only or shared plan views.
- [ ] Skip, Close, Escape and finishing all stop future auto-starts. Leaving mid-tour does not.
- [ ] The Help button replays the current page's tour and is hidden on routes without a tour.
- [ ] Missing or hidden targets are skipped. A tour with fewer than 3 usable targets doesn't start.
- [ ] No tour step changes data, opens a publish or share dialog, or changes privacy.
- [ ] Driver.js is loaded only when a tour runs. No layout shift or console or hydration errors.
- [ ] Keyboard, focus restore, dialog semantics, contrast and reduced motion pass in both themes.
- [ ] Popovers fit at 375px and in short viewports. No horizontal overflow.
- [ ] Blocked or corrupt `localStorage` causes no errors.
- [ ] The `/help` navbar link is fixed, either removed or pointed somewhere that works.
- [ ] `npx tsc --noEmit`, lint on changed files, and `next build` pass.

**Tests:** the client has no test runner yet (`package.json` has only `build` and `lint`). Either add a minimal Vitest setup to unit-test `tour-storage.ts` (corrupt JSON, storage that throws, version bump, per-user keys) and the auto-start eligibility and visible-step filter logic, or keep that logic as pure functions and record the manual verification. Decide at the start of Phase 2. Don't write tests that only repeat copy or styling.

## 10. Git and release

Build on `feat/onboarding-tours` in `client`, cut from an up-to-date `dev`, with unrelated work left out. Push `client` before updating the root pin. Root `main` pushes deploy production; read `docs/agents/release.md` first.

## 11. References

- [Driver.js configuration](https://driverjs.com/docs/configuration)
- [Driver.js API](https://driverjs.com/docs/api)
- [Driver.js theming](https://driverjs.com/docs/theming)

## 12. Implementation notes (2026-11-13, client 17993b2)

**Shipped (client only, no backend):**

- `components/tour/`: types, Zod-validated per-user storage (`navio:tours:v1:<userId|guest>`), pure policy (`resolveTourSteps`, `canAutoStartTour`, `statusForEndReason`), DOM helpers, a Driver.js controller (dynamic `import("driver.js")`), `PageTour` (registers the page's tour and auto-starts it once), `TourHelpButton` (row and icon variants), and `tour.css` (Navio tokens, route-line progress, a one-time target pulse, popover entrance, reduced-motion overrides).
- Tour content in `data.ts` beside each feature: dashboard (7 steps), planner (8), community (7). Driver.js is pinned to **1.10.2** (1.11 and 1.12 were under two weeks old).
- Targets are `data-tour` attributes. `SidebarItem`, `SidebarMenu` and `TripActionsMenu` gained an optional `tourTarget` prop.
- **Show tips** sits in the app sidebar's account actions (dashboard and planner) and as an icon in the community navbar. It renders only when the page has a tour.
- The planner tour starts only for a signed-in user with metadata loaded, blocks hydrated, not read-only, not in table view, and with the itinerary on screen (split view, or phone itinerary tab). On replay, `prepare()` switches a phone back to the itinerary and closes the table view.

**Differences from the plan:**

- The dashboard's "Before you head out" (`TripPreparation`) is not rendered on `origin/dev`, so the dashboard tour uses New trip, Upcoming trips, Explore plans, the sidebar Trips list, Notifications and Help instead.
- **The `/help` links were left untouched.** The sidebar Discover "Help" link was user-approved in an earlier session, and the navbar and footer link there too. `/help` still has no page.
- Driver.js skips `onDestroyed` when a tour is closed during its first transition. The controller captures the reason in `onDestroyStarted` and ends the tour through one idempotent `finish()`.
- Focus moves to **Next** on each step (Driver.js would focus the close button), and returns to the opener or the page `h1` afterwards.

**Verified:** `tests/tour/tour-policy.test.mjs` and `tour-data.test.mjs` 14/14. Full client suite 726/727; the one failure is the known `canonical.test.mjs` golden-fixture check that reads `server/...` beside the main checkout. `tsc`, changed-file ESLint and `next build` pass. `tests/tour/tour-browser-check.mjs` passed 10/10 against an isolated `next dev` (port 3121, test `AUTH_SECRET`, placeholder Keycloak env, all APIs mocked, system Chrome): auto-start once, completion recorded, Show tips replay, Escape mid-animation dismisses, focus restore, navigation away records nothing, planner every target, no auto-start in table view or phone map view, phone replay switches to itinerary, community guest at 375px with no overflow, dark theme, reduced motion. **Not verified:** a real signed-in account against live services, and Safari/Firefox.

## 13. Planner feature tours and fixes (2026-11-13, client 017327d)

**Why:** The user wanted every planner feature taught. One tour would have run past 30 steps, so the planner tutorial is split.

**What shipped:**

- The automatic 8-step planner overview is unchanged except for its last step, which now points to the other tips.
- **Seven feature tours run only on request:** Days and timing, Auto plan, Notes and checklists, Your EV, Charging stops, Budget, and Share and export. Content is in `planId/_components/tour/data.ts`.
- **Ways in:**
  - **Show tips** (sidebar) is a shadcn `DropdownMenu` listing the page's tours, with a tick on finished ones. Pages with one tour still start it directly.
  - A **?** beside the Itinerary heading offers Days, Auto plan, Notes and Share.
  - A **?** beside My garage offers Your EV and Charging stops.
  - A **?** beside Budgeting starts Budget.
  - A **?** in the EV charging panel header starts Charging stops.
  - These buttons are hidden on read-only plans. A green dot appears once every tour in a section is finished.
- **Step model** (`components/tour/tour.types.ts`):
  - `opens`: press this trigger first, because the target sits inside its menu. The tour closes it again afterwards.
  - `unless`: skip this step while that control is on screen. This pairs a "set it up" step with the steps for the feature once it is set up.
  - `fallback`: centred text shown when the control is missing.
- **Rule:** tours may open and close menus, but never press anything that changes a trip. Modal dialogs are never opened, because their focus trap would conflict with Driver.js.
- **Navigation:** buttons and arrow keys both go through one `go()` in the controller. It prepares each step: opens or closes the menu, then waits up to 700 ms for the target. A step that is still missing is skipped, unless it has a fallback.

**Fixes in the same release:**

- **Spotlight drifting:** the spotlight now follows its control when content above grows (late garage charts) or a nested panel scrolls (`tour-layout-tracker.ts`). Driver.js only listens to window scroll and resize.
- **Close button:** the × works again. `all: unset` had dropped its z-index, so the title covered it.

**Verified:**

- **Unit tests:** 23 tour tests. They include a check that every target and every `opens` trigger exists in app code, and that check excludes the tour data files.
- **Full suite:** 748/749 after rebasing onto `fa1fea5`. The one failure is the known `canonical.test.mjs` worktree path.
- **Build and lint:** `tsc`, ESLint and `next build` pass.
- **Browser:** `tests/tour/tour-browser-check.mjs` 16/16 against a mocked isolated dev server, covering the tips menu and ticks, the day menu opened and closed by a tour, the Itinerary and garage menus, real add-button targets, Escape closing the day menu, and spotlight drift.
- **Not run:** a real login with live data. The charger panel steps are checked by the target test and code reading, not walked in a browser.
