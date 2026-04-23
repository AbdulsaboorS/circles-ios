# Phase 18 — Progress Log

**Status:** pending user review after Session 2 (Hero + Moment shipped).

---

## Session 1 — 2026-04-23 — Scaffold

### Shipped

- Created `/landing/` as a top-level Astro 6 project (minimal template, TypeScript strict)
- Added integrations: `@astrojs/react` (for GSAP islands), `@tailwindcss/vite` (Tailwind 4)
- Installed: `gsap`, `lucide-astro`, `@fontsource/fraunces` (400/500/600), `@fontsource/inter` (400/500/600)
- `src/styles/tokens.css` — Midnight Sanctuary CSS custom properties, pulled exact from `Circles/DesignSystem/DesignTokens.swift` (lines 101–129)
- `src/styles/global.css` — Tailwind 4 `@theme` block exposing tokens as utilities (`bg-ms-background`, `text-ms-gold`, `font-serif`, etc.); base element defaults; global `prefers-reduced-motion` reset; gold focus ring (SPEC §9)
- `src/lib/brand.ts` — `BRAND` constant (name, tagline, email, appStoreUrl) so Phase 16 rename is a one-line change
- `src/layouts/Layout.astro` — HTML shell with proper `<meta>` (description, theme-color, Open Graph, Twitter card) and `<slot />`
- `src/pages/index.astro` — sticky header with logo + disabled "Coming to the App Store" CTA; all 7 section placeholders rendered (Hero, Moment, Circle, Habits, What It's Not, FAQ, Footer) with semantic landmarks + `aria-labelledby`

### Verified

- `npm run build` completes clean (1.12s, zero warnings)
- `npm run dev` serves on `http://localhost:4321/` with HTTP 200
- Tokens resolve as Tailwind utilities (hero + footer already use `bg-ms-background-deep`, `text-ms-text-muted`, `border-ms-gold/10`)
- No console errors, no failed requests

### What's next (Session 2)

Per HANDOFF.md build order:

1. Hero section with real copy (two headline/subhead options for user to pick) + ambient gradient drift
2. `<HomeShell />` mockup in the hero phone frame
3. `landing/README.md` run instructions — deferred until after mockups so the README can screenshot the finished shell

### Open questions for the user

- None from scaffold. Next session I'll ping on hero copy options before building mockups.

### Stack confirmation

| Piece | Version |
|-------|---------|
| Astro | 6.1.9 |
| Tailwind | v4 (`@tailwindcss/vite`) |
| React | via `@astrojs/react` |
| GSAP | latest |
| Fraunces | `@fontsource/fraunces` |
| Inter | `@fontsource/inter` |
| Lucide | `lucide-astro` |

Reviewer: run `cd landing && npm install && npm run dev` and open `http://localhost:4321/`. You should see a dark-green page with seven numbered section placeholders and a sticky header.

---

## Session 2 — 2026-04-23 — Hero + The Moment

Two focused commits, full-quality pass over the two signature sections.

### Commit 1 — `feat(landing): hero section with ambient gradient and HomeShell mockup` (`2875156`)

Shipped:

- `src/components/AmbientGradient.astro` — two stacked radial gradients drifting over 22s / 26s via `background-position`, reduced-motion safe (SPEC §7 target #1)
- `src/components/PhoneFrame.astro` — reusable iPhone shell (notch, bezel, 9:41 status bar, signal/wifi/battery glyphs, `<slot />` for screen content); scales to 78% under 640px per SPEC §8
- `src/components/mockups/HomeShell.astro` — static replica of `HomeView`. "Daily Intentions" top nav with Noor ring; `HeroHabitCard` with gold `moon.stars` icon, serif habit name ("Read Qur'an · 10 minutes"), breathing border on a 6s ease-in-out loop matching `HeroHabitCard.borderGlow` (0.45 → 0.88); 2×2 `SharedHabitCard` grid with completed/uncompleted states; grain via SVG `feTurbulence` mirroring `HomeView.GrainTexture` Canvas noise; tab bar with gold active dot
- `src/components/Hero.astro` — two-column layout (copy left, phone-shell right on desktop; stacks on mobile). Exposes two copy options via a single `COPY_OPTION` const so the user can toggle without touching markup:
  - **A** (aspirational / spiritual, current default): "Consistency, witnessed." + "A sacred check-in with the few who keep you close to your deen."
  - **B** (mechanic-forward): "Your circle. Your moment. Nothing public." + "One photo a day, anchored to a prayer time. Only the people in your circle ever see it."
- CTA is the required disabled pill "Coming to the App Store" with `aria-disabled="true"` and `tabindex="-1"` per SPEC §4.1
- Phone shell has an ultra-subtle 9s vertical float to pair with the ambient drift
- All animations wrapped in `prefers-reduced-motion: no-preference` and fall back to the end state under reduced motion

### Commit 2 — `feat(landing): moment section with niyyah dissolve and MomentShell mockup` (`9959081`)

Shipped:

- `src/components/mockups/MomentShell.astro` — three stacked layers inside the phone shell, hook points via `data-moment-layer` attributes:
  1. **Viewfinder** — top bar with Fajr window countdown pill (gold + pulsing dot), close/flip buttons, captured photo stand-in (abstract gold/forest gradient), picture-in-picture selfie overlay (mirrors BeReal front/back), bottom shutter
  2. **Niyyah overlay** — frosted glass card with serif "What's on your heart today?" prompt (verbatim from `NiyyahCaptureOverlay.swift`), sub-copy, dummy reflection text ("Seeking patience today."), gold "Set Niyyah" capsule, chevron-down skip hint
  3. **Feed card** — author row with gold-tinted avatar, photo + PiP, italic niyyah quote, face-pile of three avatars with `+2` count, gold reaction chip (heart + count)
- `src/components/islands/MomentDissolve.tsx` — React island using GSAP + ScrollTrigger, hydrated via `client:visible` so the animation JS only loads when the section approaches viewport. Three phases mirror `MomentPreviewView.NiyyahPhase`:
  1. Hold niyyah 1.2s after entering viewport
  2. Overlay fades + scales to 0.98 over 0.8s (`photoReveal → dissolving`)
  3. Feed card fades up from +14px over 0.6s (`settled`), overlapped by 0.2s so it feels like a real dissolve
- `prefers-reduced-motion` short-circuits the timeline and jumps to the end state (overlay hidden, feed visible)
- `onLeaveBack` resets to initial state so scrolling up and back down replays the ritual
- `src/components/Moment.astro` — section wrapper, copy **right** / mockup **left** on desktop (alternates hero's left/right rhythm), full-bleed `ms-background-deep`, subtle radial tints in `::before`
- Copy (single version per SPEC §5):
  - Eyebrow: "The Moment"
  - H2: "One window. Once a day."
  - Body: "When the window opens, you have a few minutes. Step away from the screen, set your niyyah, take the photo. Front and back, just like the world knows it — but grounded in intention." / "Your circle sees it. Nobody else. Ever."
  - Italic pull: "Your circle sees it. Nobody else. Ever."
  - Callout (gold-left-border): "Posted late? That's still posted. Consistency is the journey, not the streak." — `Posted late` language from PROJECT.md §J

### Verified

- `npm run build` — clean, 1.40s, zero warnings
- `npm run dev` — HTTP 200; 10 marker matches (`moment-shell`, `One window. Once a day`, `What's on your heart today`, `moment-dissolve-root`, `Seeking patience`)
- `<astro-island client="visible">` hydration marker present → island will load GSAP only on scroll into view

### What's next (Session 3)

Suggested: Sections 3 "Your Circle" (3-column feature strip + stagger-fade scroll reveal — SPEC §7 target #4) and 4 "Habits that Hold" (split layout with `FeedShell`-ish habit card and Noor Bead fill — SPEC §7 target #3). Then Sections 5 + 6 + 7 + mobile polish + README in one more session.

### Decisions locked in (end of session 2)

1. **Hero copy = option A** ("Consistency, witnessed." / "A sacred check-in with the few who keep you close to your deen."). A/B toggle removed from `Hero.astro`.
2. **Mockup rhythm = alternating** (hero right, moment left). Keep this pattern — section 4 mockup goes right.

### Handoff

Session 3 will happen in a fresh chat. See `SESSION-3-HANDOFF.md` for the next agent's brief (sections 3 + 4 + Noor Bead fill animation).

### Manual test checklist (reviewer)

Run `cd landing && npm run dev`, open `http://localhost:4321/`:

- Hero: ambient gradient drifts slowly, hero card gold border breathes, phone floats ~10px
- Scroll to Moment (section 2): niyyah overlay holds, dissolves, feed card fades up into view
- Scroll up past the moment section then back down: animation replays
- DevTools → Rendering → "Emulate CSS prefers-reduced-motion: reduce" → both animations skip; hero static, moment shows end-state (feed card) immediately
- DevTools console → zero errors, zero failed requests
- Mobile viewport (375px) → hero + moment both stack, phone shells shrink, copy stays readable

