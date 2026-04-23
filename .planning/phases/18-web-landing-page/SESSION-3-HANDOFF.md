# Phase 18 — Session 3 Handoff

**For the next agent.** Session 2 ended at the context limit. Hero + Moment are shipped. Your job is Sections 3 (Your Circle), 4 (Habits that Hold), and the Noor Bead fill animation — the last animated/mockup-heavy chunk. Sections 5/6/7 + mobile polish + README come in Session 4.

---

## Start here

Read these files in order (~5 min):

1. `.planning/phases/18-web-landing-page/SPEC.md` — full source of truth. Sections 4.3, 4.4, §6 (mockups), §7 (animation targets #3 and #4) are your focus.
2. `.planning/phases/18-web-landing-page/HANDOFF.md` — original agent brief. Still binding: boundaries, when-to-ask rules, commit conventions.
3. `.planning/phases/18-web-landing-page/PROGRESS.md` — what Session 1 and Session 2 shipped and verified.
4. `landing/src/components/Hero.astro` and `landing/src/components/Moment.astro` — study the house style. Match it.
5. `landing/src/components/mockups/HomeShell.astro` and `MomentShell.astro` — the mockup pattern (token-driven CSS, SVG glyphs instead of icon fonts, grain via `feTurbulence`).
6. `landing/src/components/islands/MomentDissolve.tsx` — the GSAP island pattern. **Copy this shape** for the Noor Bead fill island.

Then skim one iOS file per section:

- Section 3 uses no mockup — no iOS file needed
- Section 4: `Circles/Home/HomeView.swift` lines 1034–1151 (`SharedHabitCard` — the habit card you'll mock) and `Circles/DesignSystem/NoorRingView.swift` (streak fill visual reference)

---

## What's locked in (do not revisit)

- **Hero copy option A.** The toggle was removed in session 2. Headline = "Consistency, witnessed." Sub = "A sacred check-in with the few who keep you close to your deen."
- **Mockup rhythm: alternating.** Hero mockup right, Moment mockup left. Keep alternating: Section 4 mockup should be **right** (Section 3 has no mockup).
- **Stack:** Astro 6 + Tailwind 4 (`@theme` block in `global.css`) + React islands for GSAP. No new dependencies without asking.
- **Tokens:** Use only the Tailwind utilities (`bg-ms-background`, `text-ms-gold`, etc.) or the raw CSS custom properties (`var(--ms-gold)`). Do not hardcode hex colors except when reaching for `color-mix()`.

---

## Session 3 deliverables — two commits

### Commit 1 — Section 3 "Your Circle" + scroll-reveal island

Files to create:

- `src/components/Circle.astro` — SPEC §4.3. Three-column feature strip on desktop, stacked on mobile. Each column: Lucide icon in a gold-tinted circle (~48px), serif headline (~22px), 2-line sans body (~15px, `text-ms-text-muted`).
- `src/components/islands/ScrollReveal.tsx` — reusable vanilla-flavored React island that wraps children and fades them up (+16px → 0, opacity 0 → 1, 0.6s ease-out) when they enter the viewport. Use `IntersectionObserver` (SPEC §7 target #4 explicitly says "CSS + IntersectionObserver vanilla JS" — **do NOT add GSAP here**, it's bigger JS than the effect warrants). Accept a `stagger` prop (ms between children) so Section 3's three columns cascade. Honor `prefers-reduced-motion` by showing end state immediately.
- `src/pages/index.astro` — replace Section 3 placeholder with `<Circle />`.

Copy (agent drafts, single version per SPEC §5):

- Eyebrow: "Your Circle"
- Section title: "Small, private, and yours."
- Column 1 — icon: `lock-keyhole` (or `eye-off` — pick what reads cleanest)
  - Headline: "Private by default."
  - Body: "No public profiles. No discovery. Nothing you post ever leaves your circle."
- Column 2 — icon: `users` or `sparkles`
  - Headline: "Small by design."
  - Body: "A circle is five or six people who already know you. That's the point — accountability from the few, not likes from the many."
- Column 3 — icon: `moon` (matches home icon language)
  - Headline: "Gender-aware."
  - Body: "Circles are brothers-only, sisters-only, or mixed — set at creation. Modesty stays structural, not a toggle."

Accessibility: use `<section aria-labelledby="circle-title">`, each column as `<article>` with `<h3>`. Icons `aria-hidden="true"`.

Commit message:

```
feat(landing): your circle section with staggered scroll reveal
```

### Commit 2 — Section 4 "Habits that Hold" + Noor Bead fill

Files to create:

- `src/components/mockups/HabitDetailShell.astro` — static mockup of one habit card in detail: circular Noor ring progress bar (gold stroke over cream track) around a large habit icon; "7 day streak" label below; 3 small streak beads (day-by-day history) at the bottom. Pull visual cues from `Circles/DesignSystem/NoorRingView.swift` and `SharedHabitCard` (lines 1034–1151 in HomeView.swift). Beads use `data-bead-index="0|1|2|..."` so the island can fill them in sequence.
- `src/components/islands/NoorBeadFill.tsx` — React island. On scroll into view:
  1. Ring stroke-dashoffset animates from full to target (e.g. 60% fill) over 1.2s `power2.inOut`
  2. Beads fill left-to-right on a 0.12s stagger, each swapping from muted border → gold fill with a tiny scale pop (1 → 1.15 → 1, 0.3s)
  - Use GSAP (plugin `ScrollTrigger` — already the pattern in `MomentDissolve.tsx`)
  - `prefers-reduced-motion`: jump to end state (ring at final offset, all beads filled)
  - Use `client:visible`
- `src/components/Habits.astro` — SPEC §4.4. Split layout: copy left, mockup right on desktop; stacks on mobile. Full-bleed `bg-ms-background` (alternates with Moment's deep bg).
- `src/pages/index.astro` — replace Section 4 placeholder with `<Habits />`.

Copy (single version, PROJECT.md §J voice):

- Eyebrow: "Habits that Hold"
- Title: "Built around your niyyah, not your streak."
- Body (2 short paras):
  - "Set an intention. A 28-day roadmap forms around it — reviewed weekly, refined gently. No punishment for slipping."
  - "The Noor Bead fills with your presence, not your perfection. Consistency over streaks. Journey over outcome."
- Callout (gold-left-border, matching Moment style): "Your streak can break. Your intention doesn't."

Commit message:

```
feat(landing): habits section with noor bead fill animation
```

### Commit 3 — PROGRESS.md update

Append a "Session 3" entry to `.planning/phases/18-web-landing-page/PROGRESS.md` with:

- What shipped (both commits, file list)
- Animation targets from SPEC §7: now #3 and #4 are done (added to #1 ambient and #2 niyyah dissolve from session 2)
- Manual test checklist for reviewer
- What's next (Session 4 = Sections 5/6/7 + mobile polish + Lighthouse pass + README)

Commit message:

```
docs(landing): session 3 progress log — circle + habits shipped
```

---

## Ground rules — do NOT break

1. **Boundaries.** Only touch files under `/landing/` and `.planning/phases/18-web-landing-page/`. Phase 14 / 15 agents are working in parallel on `Circles/` and `supabase/` — stay out of both.
2. **No new npm packages** without asking the user. GSAP is already installed. Lucide is already installed (`lucide-astro`). If you think you need something else, stop and ask.
3. **No real screenshots.** HTML mockups only (SPEC §10).
4. **No hosting / deployment work.** v1 is local-review only.
5. **Copy.** Agent drafts. User edits. Don't propose alternatives for Section 3 or 4 unless you're unsure — SPEC §5 says single version per section after the hero.
6. **Reduced motion.** Every animation must fall back cleanly. Test with DevTools → Rendering → Emulate reduced motion before each commit.
7. **Do not touch `Hero.astro`, `Moment.astro`, or their mockups.** They're locked. If Section 3 or 4 needs a small token/utility added, put it in `global.css` `@theme`, not the existing components.
8. **Commits.** One per section per the plan. Do not batch both sections into one commit. Match the repo style (see `git log --oneline -10`).
9. **Dev server.** It's already running on `http://localhost:4321/` (started at the end of session 2). If it's gone, run `cd landing && npm run dev` in the background.

---

## Test before each commit

From `/landing/`:

```bash
npm run build 2>&1 | tail -10    # must be zero warnings
curl -s -o /dev/null -w "HTTP %{code}\n" http://localhost:4321/  # must be 200
```

Then open `http://localhost:4321/` and:

- Section 3 first: three columns render in a row on desktop, stack on mobile, stagger-fade as they scroll into view (100ms apart)
- Section 4: habit card mockup on the right, copy left. Scroll into view → Noor ring fills, then beads fill left-to-right with the pop
- DevTools → Rendering → Emulate CSS prefers-reduced-motion: reduce → both animations skip, sections render at end state
- Console → zero errors

---

## Progress checkpoint (end of your session)

After commit 3 (PROGRESS.md), leave a bullet list for Session 4 at the bottom of `PROGRESS.md` covering:

- Section 5 "What It's Not" — dark strip, three lines with gold underline reveal (reuse `ScrollReveal`)
- Section 6 FAQ — 6–8 accordion questions (hand-written `<details>/<summary>` with animated chevron — SPEC §7 target #5)
- Section 7 Footer (real, not placeholder)
- Mobile responsive polish pass
- Accessibility audit + Lighthouse run
- `landing/README.md` run instructions

---

## If you run low on context

Commit 1 (Circle) is self-contained and ships first. If context tightens after commit 1, stop, write a "Session 3 partial" entry in PROGRESS.md, and hand off Section 4 to Session 3b. That way the user always has a shippable checkpoint.

Ship quality over quantity. Do not try to cram sections 5–7 into session 3 just to finish the phase.
