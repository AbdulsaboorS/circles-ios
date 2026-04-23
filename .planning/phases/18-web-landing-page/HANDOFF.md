# Phase 18 — Agent Handoff

**You are the landing page agent.** You are working in parallel with two other agents (Phase 14 QA on `main`, Phase 15 Social Pulse in a worktree). Your work is **independent** — different folder, different stack, no shared files.

## Start Here

1. Read `.planning/phases/18-web-landing-page/SPEC.md` in full — it is the source of truth for scope.
2. Read `.planning/PROJECT.md` (sections Vision, Core Mechanics, §J Muslim-Native Copy Guidelines) so your copy voice matches.
3. Read `Circles/DesignSystem/DesignTokens.swift` — pull the Midnight Sanctuary token values EXACT.
4. Skim these iOS files so your mockups match real screens:
   - `Circles/Home/HomeView.swift`
   - `Circles/Moment/MomentCameraView.swift`
   - `Circles/Moment/MomentPreviewView.swift`
   - `Circles/Feed/FeedView.swift`

## Boundaries

**Your files:** everything inside `/landing/`.

**Do not touch:**
- `Circles/` (iOS app source — other agents are working there)
- `supabase/` (backend)
- `.planning/phases/14-meaningful-habits/` or `.planning/phases/15-*` (other agents' phases)
- `.planning/STATE.md`, root `HANDOFF.md`, `CLAUDE.md` (owned by main orchestrator)

**You may:**
- Create / modify anything inside `/landing/`
- Add new files to `.planning/phases/18-web-landing-page/` (e.g. `NOTES.md`, `COPY.md`, `DISCUSSION-LOG.md`)

## Session 1 — Suggested Plan

1. `cd landing && npm create astro@latest .` (minimal template, TypeScript strict, Tailwind integration)
2. Add React integration (`npx astro add react`) — needed only for GSAP animation islands
3. Install: `tailwindcss`, `lucide-astro`, `gsap`, `@fontsource/fraunces`, `@fontsource/inter`
4. Create `src/styles/tokens.css` with the Midnight Sanctuary CSS custom properties (exact values from SPEC §3)
5. Wire Tailwind config to reference those custom properties (`colors: { 'ms-background': 'var(--ms-background)', ... }`)
6. Build a bare `src/pages/index.astro` that renders all 7 section placeholders (just headings)
7. Confirm `npm run dev` works, then commit: `feat(landing): scaffold Astro + Tailwind + tokens`

Stop there and report back to the user before building mockups / animations. The user will review the scaffold first.

## Session 2+ — Build Order

After scaffold approval, build in this order (commit after each):

1. Hero section + ambient gradient animation + `<HomeShell />` mockup
2. "The Moment" section + `<MomentShell />` mockup + niyyah-dissolve GSAP animation
3. "Your Circle" 3-column feature strip + scroll-reveal
4. "Habits that Hold" section + `<FeedShell />` mockup + streak-bead fill animation
5. "What It's Not" dark strip
6. FAQ accordion (6–8 questions)
7. Footer
8. Mobile responsive polish
9. Accessibility audit + `prefers-reduced-motion` verification
10. `landing/README.md` with run instructions

## Copy

You draft. User edits. For the hero only, propose **two** headline + subhead options and let the user pick. For everything else, one version is fine — user will edit in place.

See SPEC §5 for voice guidelines. Read `.planning/PROJECT.md` §J before writing any copy.

**Hard rules:**
- Never write "Islamic BeReal" publicly.
- Never use exclamation marks in headers.
- Use "Posted late" not "missed" or "failed."
- Reference "circle" not "group" or "community."

## Brand Centralization

Create `landing/src/lib/brand.ts`:

```ts
export const BRAND = {
  name: 'Circles',
  tagline: 'Your circle. Your moment. Nothing public.',
  email: 'hello@circles.app', // placeholder
  appStoreUrl: '#', // placeholder until Phase 19
};
```

Use `BRAND.name` wherever the product name appears. Phase 16 (Naming/Branding) is not done — name may change. Centralizing now saves a find-replace later.

## Commit Conventions

Match the repo style (see `git log --oneline -20`):

- `feat(landing): ...` for new features
- `fix(landing): ...` for fixes
- `docs(landing): ...` for SPEC / HANDOFF updates
- `style(landing): ...` for visual polish / token tweaks

One commit per meaningful checkpoint. Do not batch unrelated changes.

## When to Ask the User

Ask before:
- Adding any dependency not listed in SPEC §2
- Deviating from the 7-section structure in SPEC §4
- Adding a 6th+ animation (SPEC §7 scopes to 5)
- Writing copy you're unsure about (FAQ questions especially)
- Hosting / domain / deployment work (explicitly out of scope for v1)

Do not ask before:
- Picking a React component library for internal use (you're not — hand-write everything)
- Picking font weights, spacing values, micro-copy details
- Naming internal components or files

## Progress Tracking

Update `.planning/phases/18-web-landing-page/PROGRESS.md` after each session with:
- What shipped this session
- What's next
- Any blockers / open questions for the user

(Create the file when you start session 1.)

## Definition of Done

See SPEC §12. Do not mark the phase complete — that's the user's call after review. Use "pending user review" status in PROGRESS.md until they explicitly approve.
