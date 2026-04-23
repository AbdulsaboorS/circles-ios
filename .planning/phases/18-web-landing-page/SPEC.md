# Phase 18 — Web Landing Page

**Status:** 🔄 Active (parallel to Phase 14 QA on `main` and Phase 15 Social Pulse in worktree)
**Scope:** Pre-launch marketing landing page, local-only for v1
**Last updated:** 2026-04-23

---

## 1. Goal

Build a single-page marketing site for Circles that:

- Communicates the product clearly to a Muslim audience ages 15–35
- Looks and feels like the iOS app (Midnight Sanctuary palette, serif/sans pairing)
- Runs locally for review (`npm run dev`)
- Is structured so it can later be hosted, wired to a waitlist backend, or extended with Privacy/Terms pages

**Not goals for v1:** domain, hosting, analytics, waitlist backend, blog, multi-language, SEO tuning beyond basics, real App Store links.

---

## 2. Tech Stack

| Layer | Choice | Why |
|-------|--------|-----|
| Framework | **Astro** | Static HTML output, zero JS by default, component model, MDX-ready for later Privacy/Terms pages |
| Styling | **Tailwind CSS** | Matches token-driven workflow; fast iteration |
| Components | Hand-written, shadcn-style (CVA + Tailwind). **No shadcn install.** | Marketing site doesn't need Radix primitives; would add bloat |
| Animation | **CSS-only** for most. **GSAP via React island** for 2–3 signature moments | Respects `prefers-reduced-motion`. Minimal JS footprint |
| Icons | **Lucide** (`lucide-astro` or inline SVG) | Clean, consistent, free |
| Fonts | **Fraunces** (serif, matches iOS `.serif` design) + **Inter** (sans, matches SF Pro fallback) | Google Fonts, subset to Latin |
| Package manager | Whatever the agent prefers (npm works; project already has npm) | |

### Folder placement

New top-level folder: `/landing` (sibling of `Circles/`, `supabase/`, `design-system/`). It is its own Astro project with its own `package.json` and `node_modules`. Do not nest inside `Circles/`.

```
Circles/                    ← existing iOS app
design-system/              ← existing iOS design doc
supabase/                   ← existing edge functions / migrations
landing/                    ← NEW — Astro project lives here
  ├── astro.config.mjs
  ├── package.json
  ├── tailwind.config.mjs
  ├── src/
  │   ├── pages/index.astro
  │   ├── components/
  │   ├── styles/tokens.css
  │   ├── layouts/
  │   └── lib/
  └── public/
```

---

## 3. Design Tokens (pull EXACT values)

Source of truth: `Circles/DesignSystem/DesignTokens.swift`. Mirror these into `landing/src/styles/tokens.css` as CSS custom properties.

### Midnight Sanctuary (primary palette for landing)

```css
--ms-background:      #1A2E1E;  /* primary app background — deep forest */
--ms-background-deep: #131C14;  /* layered background */
--ms-card-shared:     #243828;  /* accountable habit card */
--ms-card-deep:       #1E3122;  /* personal habit card */
--ms-card-done:       #2A4A30;
--ms-card-warm:       #201C14;
--ms-card-warm-done:  #2E2410;
--ms-gold:            #D4A240;  /* CTAs, icons, highlights */
--ms-text-primary:    #F0EAD6;  /* cream */
--ms-text-muted:      #8FAF94;  /* sage */
--ms-border:          rgba(212,162,64,0.18);
```

### Typography

```css
--font-serif: 'Fraunces', ui-serif, Georgia, serif;
--font-sans:  'Inter', -apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif;
```

Scale (mirror iOS tokens, scaled for web):
- Hero title: 64–80px serif, regular weight, tight tracking
- Section title: 44–52px serif
- Headline: 28px serif semibold
- Body: 17–19px sans regular
- Small/caption: 13–14px sans

### Spacing + radii

- Radii: 12px (cards), 20px (large cards), 999px (pills)
- Section vertical rhythm: 120–160px on desktop, 80px on mobile
- Max content width: 1200px

---

## 4. Page Structure (single page)

Navigation is a thin pinned header with logo-left + CTA-right. No burger menu needed for v1.

### Section 1 — Hero
- **Left:** serif headline, sub-headline, primary CTA, secondary text
- **Right:** phone frame with animated UI shell (see §6 mockups)
- Ambient: subtle amber-to-forest gradient drift behind hero (CSS `@keyframes`, 20s loop)
- CTA: disabled button labeled **"Coming to the App Store"** (no form, no link)

### Section 2 — The Moment
- Explains the daily capture mechanic (BeReal-parity, circle-private)
- Full-bleed dark background (`--ms-background-deep`)
- Animated UI shell: niyyah dissolve → feed reveal (GSAP island)
- Copy anchor: "One moment. One window. Your circle only."

### Section 3 — Your Circle
- 3-column feature strip: **Private**, **Small**, **Gender-aware** — icon + headline + 2-line body per column
- Background: `--ms-background`
- Animation: stagger-fade on scroll (CSS `@keyframes` + `IntersectionObserver`)

### Section 4 — Habits that Hold
- Split layout: left = copy, right = habit card mockup with streak bead filling
- Talks about niyyah + AI 28-day roadmap + Noor Bead streak
- Animation: bead fill on scroll-enter (GSAP island)

### Section 5 — What It's Not
- Dark strip with three lines:
  - "No public feed."
  - "No followers."
  - "No leaderboards."
- Gold accent underline per line, reveal-on-scroll
- Tight, opinionated — matches PROJECT.md anti-patterns

### Section 6 — FAQ
- Accordion, 6–8 questions
- Examples: "Is it free?", "What's a circle?", "Do I need Muslim friends on the app?", "How is this different from BeReal?", "Who sees my photos?", "When does it launch?"
- Shadcn-style accordion component, hand-written (details/summary base + animated chevron)

### Section 7 — Footer
- Logo + tagline left
- Columns: Product (features, privacy, terms — links to `#` for v1), Support (email placeholder), Social (empty for v1)
- Fine print: "Made for the ummah. © 2026."

---

## 5. Copy Direction

**Voice:** Muslim-native, warm, spare. Matches `PROJECT.md` §J (Muslim-Native Copy Guidelines).

**Do not write:** "Islamic BeReal", "#1 app for Muslims", generic hype, emoji in body copy, exclamation marks in headers.

**Do write:**
- "A sacred check-in with the few who keep you consistent."
- "Your circle. Your moment. Nothing public."
- "Consistency, witnessed."
- "Posted late" (never "failed" or "missed")

**The agent drafts all copy.** User will edit. Propose 2 options for hero headline + subhead so user can pick. Single version is fine for other sections.

---

## 6. UI Mockups (phone shells)

The agent **does not** use real app screenshots for v1. Instead, build HTML/CSS "phone shell" components that visually replicate the real app screens using the exact Midnight Sanctuary tokens.

Phone frame: rounded rectangle with realistic notch, bezel, and status bar. Approximately `375 × 812` viewport on desktop (scaled down on mobile).

**Screens to mock (minimum 3):**

1. **Home / Daily Intentions** — shared habits list with streak beads
2. **Circle Moment capture** — niyyah overlay + camera viewfinder
3. **Feed card** — photo moment with face-pile reactions

These are self-contained Astro components (`<HomeShell />`, `<MomentShell />`, `<FeedShell />`) that live in `src/components/mockups/`. Reference real screens by reading:

- `Circles/Home/HomeView.swift`
- `Circles/Moment/MomentCameraView.swift` + `MomentPreviewView.swift`
- `Circles/Feed/FeedView.swift`

Goal: close enough that a user who opens the real app will recognize them. Not pixel-perfect.

**Later:** user may supply real screenshots. Components should be swappable.

---

## 7. Animation Targets

Scope deliberately small. Two or three memorable moments beats twenty small ones.

| # | Moment | Tech | Respect `prefers-reduced-motion`? |
|---|--------|------|-----------------------------------|
| 1 | Hero ambient gradient drift | CSS `@keyframes`, 20s loop | Yes — hold static on reduced |
| 2 | Moment niyyah dissolve → feed reveal (phone shell in §4.2) | GSAP in React island | Yes — skip animation, show end state |
| 3 | Noor Bead streak fill (phone shell in §4.4) | GSAP in React island | Yes — skip animation |
| 4 | Scroll-reveal stagger (feature columns, "What it's not") | CSS `@keyframes` + `IntersectionObserver` vanilla JS | Yes — show in place |
| 5 | FAQ accordion chevron rotation | CSS transition | Yes — instant |

GSAP is loaded **only** on the islands that use it. Rest of the page is zero-JS.

Use `client:visible` directive on React islands so animation JS doesn't load until the section scrolls into view.

---

## 8. Responsive Breakpoints

- **Mobile:** < 640px — stack everything, phone shells shrink to 60%
- **Tablet:** 640–1024px — single column but larger type
- **Desktop:** ≥ 1024px — full layout
- **Max content width:** 1200px

Use Tailwind's default breakpoint prefixes (`sm:`, `md:`, `lg:`).

---

## 9. Accessibility

- Semantic HTML (`<section>`, `<h1>`–`<h3>`, proper landmark roles)
- Color contrast ≥ WCAG AA for all text on Midnight Sanctuary
- Respect `prefers-reduced-motion` on all animations
- FAQ uses `<details>` / `<summary>` fallback if JS is disabled
- All CTAs keyboard-focusable with visible focus ring (gold, 2px)
- Alt text on all images / decorative SVGs use `aria-hidden`

---

## 10. Out of Scope (v1)

- Hosting / domain configuration
- Waitlist email capture (CTA is disabled-label only)
- Privacy Policy / Terms / Support pages (stub routes only if agent wants; optional)
- Real App Store link
- Analytics (no GA, no Plausible, no scripts)
- Blog / news / changelog
- Localization
- Forms of any kind
- Real screenshots (HTML mockups only)
- OG images / social share cards (basic `<meta>` tags are fine)

---

## 11. Dependencies / Assumptions

- Node 20+ installed (check: `node --version`)
- User will run `npm run dev` locally to review
- User edits copy after agent drafts
- No live preview / screenshot tooling required — local browser is enough

---

## 12. Definition of Done (v1)

- [ ] `/landing` folder exists with a working Astro project
- [ ] `npm install && npm run dev` works from a clean checkout
- [ ] All 7 sections render on desktop + mobile
- [ ] Midnight Sanctuary tokens pulled exact from `DesignTokens.swift`
- [ ] 3 phone-shell mockups render (Home, Moment, Feed)
- [ ] 5 animation targets implemented, all reduced-motion safe
- [ ] Copy drafted for all sections (2 hero options, 1 version everywhere else)
- [ ] `README.md` in `/landing` with run instructions
- [ ] No console errors, no failed requests
- [ ] Lighthouse score ≥ 95 on Performance + Accessibility (local)

---

## 13. Risks + Open Questions

- **Naming risk** — Phase 16 (Naming/Branding) is not done. Landing page ships under "Circles" for now. If name changes in Phase 16, landing page needs a token swap (name used in ~5 places). Agent should centralize brand name as a single constant (`src/lib/brand.ts` → `export const BRAND = { name: 'Circles', tagline: '...' }`).
- **Copy voice drift** — "Islamic BeReal" is the internal pitch but must not appear publicly. Enforced in §5.
- **Animation scope creep** — tempting to animate everything. Resist. Stick to §7 targets.
- **Mockup realism** — HTML shells will look slightly different from the real app. Acceptable for v1. User will supply real screenshots later if desired.
