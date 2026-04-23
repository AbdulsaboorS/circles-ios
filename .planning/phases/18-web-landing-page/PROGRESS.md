# Phase 18 — Progress Log

**Status:** pending user review after Session 3 — **all seven sections shipped**. All five SPEC §7 animation targets complete. Remaining Phase 18 work: user's manual testing/polish pass, mobile responsive audit, accessibility + Lighthouse audit, and `landing/README.md` — queued for Session 4.

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

---

## Session 3 — 2026-04-23 — Your Circle + Habits that Hold

Two focused commits plus a log. Four of seven sections now live; SPEC §7 animation targets #1, #2, #3, #4 are all landed.

### Commit 1 — `feat(landing): your circle section with staggered scroll reveal` (`975998f`)

Shipped:

- `src/components/islands/ScrollReveal.tsx` — reusable React island. Fades direct children (or `[data-reveal]` descendants) +16px → 0 / opacity 0 → 1 over 600ms on viewport entry. `stagger` prop cascades siblings (default 100ms). Vanilla `IntersectionObserver` only — no GSAP here per SPEC §7 target #4 ("CSS + IntersectionObserver vanilla JS"), which keeps the island payload tiny. `replay` prop is available for future sections that want scroll-up replay. `prefers-reduced-motion` skips the observer entirely and shows the end state.
- `src/components/Circle.astro` — Section 3. Centered eyebrow + serif H2 ("Small, private, and yours."), then a responsive 3-column grid (stacks mobile, 3-col ≥768px). Each column: gold-tinted 48px icon pill → serif 22px headline → muted 15px body. Inline SVG glyphs (lock-keyhole / two-person users / moon) to match the HomeShell + MomentShell house style — not `lucide-astro`, which would add a component layer for three icons.
- Wraps the grid in `<ScrollReveal client:visible stagger={120}>` so columns cascade 120ms apart when the section crosses 80% of the viewport.
- Semantic: `<section aria-labelledby="circle-title">` with three `<article>` + `<h3>` columns, all icons `aria-hidden="true"`.
- `index.astro`: replaces the placeholder with `<Circle />`.

### Commit 2 — `feat(landing): habits section with noor bead fill animation` (`3bd39d9`)

Shipped:

- `src/components/mockups/HabitDetailShell.astro` — new phone-shell screen. Top nav (back chevron + serif habit title) → large circular Noor ring (cream track + gold progress arc, `r=78`, dasharray ≈ `490.088`, rotated -90° so fill starts at 12 o'clock, target offset = `CIRC * 0.4` = 60% fill) wrapping a centered gold `moon.stars` icon → "7 day streak" label + "10 minutes · after Fajr" meta → row of seven beads (`data-bead-index="0..6"`, muted-border default, gold+glow when `data-filled="true"`) → italic serif reflection line. Grain overlay via SVG `feTurbulence` mirrors the HomeShell pattern. Pulls visual cues from `Circles/DesignSystem/NoorRingView.swift` and `SharedHabitCard` (HomeView.swift 1034–1151).
- `src/components/islands/NoorBeadFill.tsx` — React island using GSAP + ScrollTrigger (same shape as `MomentDissolve.tsx`). Timeline:
  1. Ring `stroke-dashoffset` animates from starting value → CSS `--noor-target` custom property over 1.2s `power2.inOut`
  2. Beads fill left-to-right on a 0.12s offset, each with a `scale: 1 → 1.15 → 1` pop over 0.3s as it flips muted → gold (via `data-filled` attribute swap)
- Reduced-motion fallback: island short-circuits to end state (ring at target, all beads filled); mockup CSS also enforces end state independently as a belt-and-braces guard.
- `onLeaveBack` resets state so scrolling up and re-entering replays the full ritual (same UX as the Moment dissolve).
- `src/components/Habits.astro` — Section 4. Split layout (copy left, mockup right ≥1024px; stacks below). Full-bleed `--ms-background` with a subtle reversed radial tint (warm top-right, forest bottom-left). Copy:
  - Eyebrow: "Habits that Hold"
  - H2: "Built around your niyyah, not your streak."
  - Two-paragraph body about the 28-day roadmap + "presence, not perfection"
  - Gold-left-border callout (matches Moment's style): "Your streak can break. Your intention doesn't."
- `index.astro`: replaces the placeholder with `<Habits />`.
- Mockup rhythm continues the alternating pattern: hero right → moment left → habits right.

### Verified

- `npm run build` — clean, 1.33s, zero warnings, 1 page
- `npm run dev` — HTTP 200
- Markers present in rendered HTML: `circle-title`, `Small, private, and yours.`, `Private by default`, `Small by design`, `Gender-aware`, `scroll-reveal-root`, `habit-shell`, `habits-title`, `Built around your niyyah`, `7 day streak`, `data-bead-index`, `data-noor-ring`, `noor-bead-fill-root`, `component-url="/src/components/islands/NoorBeadFill.tsx"`
- Both islands hydrate `client:visible` → GSAP (bead fill) and the IntersectionObserver (reveal) only load when the sections approach the viewport

### Animation targets status

Per SPEC §7:

- [x] #1 Hero ambient gradient drift — shipped session 2
- [x] #2 Moment niyyah dissolve → feed reveal — shipped session 2
- [x] #3 Noor Bead streak fill — shipped this session
- [x] #4 Scroll-reveal stagger (Your Circle columns) — shipped this session; `ScrollReveal` is reusable for Section 5's "What it's not" lines
- [ ] #5 FAQ accordion chevron rotation — Session 4

### Manual test checklist (reviewer)

Run `cd landing && npm run dev`, open `http://localhost:4321/`:

1. Hero + Moment still behave as session 2 described (ambient drift, breathing hero card, niyyah dissolve, feed fade-up, replay on scroll back).
2. **Section 3 (Your Circle):** on desktop the three columns sit in a row; on mobile they stack. Scroll them into view — each column cascades up with a 120ms delay after its neighbour (first left, then middle, then right). Scroll past and back → with default settings they stay revealed (no replay); that's intentional.
3. **Section 4 (Habits):** on desktop the habit-shell mockup is on the right, copy left; mobile stacks. Scroll into view → the gold ring fills over ~1.2s, then the seven beads pop-fill one after another left-to-right (~0.12s apart). Scroll up above the section and back down → the ritual replays.
4. DevTools → Rendering → "Emulate CSS prefers-reduced-motion: reduce":
   - Your Circle: columns render in their end state, no fade-up
   - Habits: ring arrives at its target offset immediately; all seven beads render filled; no pop
5. Console → zero errors, zero failed requests.
6. Mobile viewport (375px): all four sections stack cleanly, no horizontal overflow, phone shells shrink, copy stays readable.

---

## Session 3 extension — 2026-04-23 — Closing sections (What It's Not + FAQ + Footer)

Same chat as Session 3 above. User asked to push on and close sections 5–7 since they were light-lift (no new mockups, no GSAP). One consolidated commit because the three components share the same `index.astro` diff and ship as a single "close the page" slice.

### Commit — `feat(landing): closing sections — what it's not, faq, real footer` (`cab595f`)

**Section 5 — `src/components/Not.astro`** (SPEC §4.5)

- Dark strip (`--ms-background-deep`) with centered serif H2 "What this app is not." (italic gold `<em>` on "not").
- Three opinionated one-liners: "No public feed.", "No followers.", "No leaderboards."
- Each line fades up (+14px → 0, 600ms ease-out) then a gold 2px underline draws left-to-right (700ms cubic-bezier 0.22/1/0.36/1) with a soft gold glow. Staggered 140ms per line via a `--not-index` custom property on each `<li>`.
- Revealed via a tiny inline `<script>` IntersectionObserver that adds `.is-in` on entry (threshold 0.1, rootMargin `-15%` bottom so the reveal triggers before the line fully scrolls on-screen). Zero React here — pure CSS transitions don't warrant an island.
- `prefers-reduced-motion`: short-circuits the observer (all lines get `.is-in` immediately) plus a CSS `@media` rule that disables transitions so nothing jumps.
- Matches the PROJECT.md §J anti-patterns list ("no public feed", "no leaderboards").

**Section 6 — `src/components/Faq.astro`** (SPEC §4.6, §7 target #5)

- Eight hand-written `<details>/<summary>` accordions. Native disclosure → works with JS disabled.
- Chevron is inline SVG inside a 32px gold-tinted pill; `transform: rotate(180deg)` on `.faq__item[open] .faq__chev` via a 260ms `cubic-bezier(0.22, 1, 0.36, 1)` transition. Pure CSS, no JS.
- Answer fades in on open via a 280ms keyframe (`faq-reveal`: opacity 0→1, translateY -4px → 0). `prefers-reduced-motion` disables both.
- Questions shipped (single version, PROJECT.md §J voice):
  1. Is it free?
  2. What is a circle?
  3. Do I need Muslim friends on the app?
  4. How is this different from BeReal?
  5. Who sees my photos?
  6. What happens if I miss a day?
  7. Does it work across time zones and prayer methods?
  8. When does it launch?
- Mailto footer under the list links to `BRAND.email` ("Still have a question? Email hello@circles.app.") with a gold underline that brightens on hover.

**Section 7 — `src/components/Footer.astro`** (SPEC §4.7)

- Replaces the session-1 stub. Rendered **outside** `<main>` in `index.astro` so the `<footer>` is a page-level landmark (implicit `contentinfo` role), not a section inside main.
- Split layout: brand block left (serif 28px `BRAND.name` + 14px tagline), three-column nav right (Product / Support / Social). Brand stacks above cols under 1024px, cols drop to 2-up under 640px.
- Link behaviour:
  - **Product** — anchors to `#hero`, `#moment`, `#habits`, `#faq` (in-page nav).
  - **Support** — Privacy + Terms rendered as disabled `<span>`s with `aria-disabled="true"` (pages are out of scope for v1 per SPEC §10); Contact is a real `mailto:` to `BRAND.email`.
  - **Social** — Instagram + X as disabled `<span>`s (no accounts yet).
- Bottom bar (stacks under 768px): "Made for the ummah. © 2026." left, "Invite-only launch · no waitlist yet." right.
- All links inherit the global gold focus ring (SPEC §9); hover lifts muted text to primary.

### Verified

- `npm run build` — clean, 2.64s, zero warnings, 1 page
- `npm run dev` — HTTP 200; markers present in rendered HTML: `not-title`, `What this app is`, `No public feed`, `No followers`, `No leaderboards`, `faq-title`, `Before you ask`, `Is it free`, `Who sees my photos`, `footer-title`, `Made for the ummah`, `Invite-only launch`
- Full commit chain from this session: `975998f` → `3bd39d9` → `b046d10` → `cab595f`

### Animation targets status

Per SPEC §7:

- [x] #1 Hero ambient gradient drift — session 2
- [x] #2 Moment niyyah dissolve → feed reveal — session 2
- [x] #3 Noor Bead streak fill — session 3
- [x] #4 Scroll-reveal stagger (Your Circle columns; Not-section underlines use the same pattern inline) — session 3
- [x] #5 FAQ accordion chevron rotation — session 3 extension

All five shipped.

### Manual test checklist (additions for sections 5–7)

7. **Section 5 (What It's Not):** dark strip below Habits. Scroll in → each of the three lines fades up and the gold underline draws left-to-right ~260ms after the text settles. 140ms cascade between lines. Reduced-motion: all three appear instantly with underlines drawn.
8. **Section 6 (FAQ):** eight questions, chevron rotates 180° on open with a 260ms ease. Answer fades down into place. Click multiple open at once — they all stay open (not radio-grouped — intentional). Mailto link focus-rings gold.
9. **Section 7 (Footer):** product links scroll you back up to the right anchors. Privacy / Terms / Instagram / X render dimmed but still accessible via tab (aria-disabled). Bottom bar aligns right on desktop, stacks on mobile. At 640px the cols go 2-up (Product | Support on top row, Social alone on bottom).

### What's next (Session 4 — user-driven polish)

User flagged this session will be their testing + polish pass. Suggested focus areas (kept unchanged from last entry):

- **Mobile responsive pass.** Audit every section at 375 / 414 / 768. Confirm phone-shell scaling per SPEC §8. Watch for: hero ambient vs. phone-float conflict on small screens, callout box widths on 375px, FAQ summary wrapping, footer col gaps when they drop to 2-up.
- **Accessibility audit.** Heading order (`h1` in hero, `h2` per section, `h3` only inside Circle columns), keyboard tab order through header CTA → sections → FAQ summaries → footer links, focus ring visibility on `--ms-background-deep`, color contrast on `--ms-text-muted` against both backgrounds, `prefers-reduced-motion` sweep across all five animation targets.
- **Lighthouse pass.** `npm run build && npm run preview`, target ≥ 95 Performance + Accessibility per SPEC §12. Probable wins: preload the two woff2 files, add explicit `width/height` to decorative SVGs that don't already have them, check that GSAP chunks aren't loading on first paint (they should only be pulled when the Moment / Habits sections approach the viewport).
- **`landing/README.md`.** Prerequisites (Node ≥22.12), `npm install`, `npm run dev`, where components live, how to swap mockups for real screenshots later (HomeShell / MomentShell / HabitDetailShell), note that hero copy is locked to option A (edit `src/components/Hero.astro`).
- **Phase 16 rename preflight.** Confirm every user-visible "Circles" string routes through `BRAND` in `src/lib/brand.ts`. If anything was hardcoded in the new sections, fix it before Phase 16 lands.

No new mockups or GSAP islands expected in Session 4.

