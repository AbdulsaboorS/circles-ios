# Phase 14: Meaningful Habits — Context

**Gathered:** 2026-04-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Make habit creation emotionally anchored, narrow the generic catalog to AI-personalized suggestions, make check-off feel like a small dua, and make the streak feel alive.

Five features in scope:
1. Niyyah prompt on habit creation
2. Onboarding quiz (2 screens) → AI-generated habit suggestions (replaces catalog)
3. Quiz intercept gate for all habit creation paths
4. Check-off micro-moment ("الحمد لله")
5. Single master geometric pattern streak visual (always-on, scales with streak)

**Out of scope (parked):** arcs, end_dates, past-intentions archive, photo evidence on check-ins, per-user streak seeding, quiz v2 AI synthesis, hold-to-complete gesture.

</domain>

<decisions>
## Implementation Decisions

### 1. Niyyah Prompt on Habit Creation
- **D-01:** Optional text field added to the `AddPrivateIntentionSheet` creation flow — "What's your niyyah for this?"
- **D-02:** Appears as a new step between habit pick and familiarity (or after familiarity — Claude's discretion on exact placement within the existing 3-step coordinator)
- **D-03:** Field is optional — user can skip without filling it
- **D-04:** Niyyah text stored in `habits.niyyah TEXT` (nullable)
- **D-05:** Displayed as emotional header on `HabitDetailView` beneath the habit name
- **D-06:** Passed into Gemini prompt when generating the 28-day roadmap — makes AI plan more personally relevant
- **D-07:** Same single field serves both personal and shared (accountable) habits — no separate struggle-lens field

### 2. Catalog — Eliminated, Replaced with AI Suggestions
- **D-08:** The 30-item catalog expansion is **cancelled**. No fixed catalog to maintain.
- **D-09:** Gemini generates 5–6 personalized habit suggestions based on quiz answers (A + B screen selections)
- **D-10:** Prompt includes Islamic struggles selections + life struggles selections → returns habit name + 1-sentence "why this fits you" per habit
- **D-11:** Max 5–6 suggestions returned, displayed in the redesigned creation sheet
- **D-12:** Custom field always present alongside AI suggestions — user can type anything outside the suggestions
- **D-13:** Fallback: if Gemini API fails during quiz processing, show 5 sensible static defaults based on most common struggle combinations (e.g., Fajr prayer, Quran daily, morning dhikr, gratitude journaling, exercise)
- **D-14:** Salah-as-habit framing handled contextually by AI — if user selects "Praying 5 times consistently," AI suggests something like "Pray 5 daily salah with presence" naturally

### 3. Onboarding Quiz — 2 Screens (Content Confirmed)
- **D-15:** Full-width rows, gold left-border/fill highlight on selection — matches existing familiarity step in `AddPrivateIntentionSheet`
- **D-16:** Multi-select (multiple items selectable per screen)

**Screen A — Islamic Struggles (confirmed)**
- Headline: "What do you find hardest in your deen?"
- Subheadline: "Be honest — this shapes your journey"
- Options: Praying 5 times consistently / Connecting with the Quran daily / Waking up for Fajr / Keeping dhikr alive through the day / Voluntary fasting / Lowering my gaze / Guarding my tongue / Seeking Islamic knowledge
- CTA: "This is me"

**Screen B — Life Struggles (confirmed)**
- Headline: "What holds you back day to day?"
- Subheadline: "Your deen doesn't live in a vacuum"
- Options: Discipline and follow-through / Sleep and waking early / Physical health / Family and relationship ties / Restlessness or anxiety / Managing my time / Phone and social media / Patience
- CTA: "Next"

**Screen C — Processing Moment**
- "Building your intentions…" with IslamicGeometricPattern animation
- 1–2 seconds — this is a **real Gemini API call**, not a fake loader
- Auto-advances to Screen D when response arrives

**Screen D — Personalized Habit Selection**
- Shows 5–6 AI-generated suggestions + custom field
- User picks 1 to start → flows into niyyah prompt → familiarity → AI roadmap generation

- **D-17:** Answers stored on `profiles`: `struggles_islamic JSONB`, `struggles_life JSONB` — private, never visible to circle members
- **D-18:** Quiz is a **hard gate** — all users must complete it before adding habits. No soft fallback.
- **D-19:** Existing users get quiz intercept when they open the creation sheet (all current users are testers — no gentle rollout)
- **D-20:** Quiz is skippable post-onboarding and redoable anytime from Profile → Settings → "My Focus Areas"
- **D-21:** Quiz wired into: Amir onboarding (after Step 2 Core Habits), Joiner onboarding (after Habit Alignment), and in-app habit creation sheet intercept

### 4. Check-off Micro-Moment
- **D-22:** Tap gesture unchanged — no hold-to-complete mechanic
- **D-23:** On completion: "الحمد لله" text fades in beneath the habit row, dissolves after ~1.5s
- **D-24:** Subtle gold haptic pulse accompanies the fade
- **D-25:** Undo (tap again when completed) has no special animation — plain toggle back

### 5. Streak Visual — Noor Bead (Centered Hero)

> **Direction changed 2026-04-20** after design review. Original spec called for a full-width girih tessellation behind the header; that was replaced with a centered luminous "Noor bead" hero element that upgrades the existing `heartSection` in `HomeView.swift`. Rationale: tessellated background felt busy and didn't match the iconic sun+star language already in the app (`NoorRingView`, `StarConstellationView`, `IslamicGeometricPattern`). Reference: `.planning/phases/14-meaningful-habits/references/streak-bead-reference.png`.

- **D-26:** Single master "Noor bead" for all users — no per-user seeding in v1.
- **D-27:** Always-on from day 1, never absent.
- **D-28:** Placement: centered hero element in the existing header/heart section of `HomeView.swift`. Upgrades (does NOT replace the position of) the current `heartSection` gold medallion + star ring + streak text stack.
- **D-29:** Visual composition — a gold sphere with:
  - Radial gradient fill (#E8B84F center → #D4A240 mid → #8B6A28 edge)
  - 8-point star at its core, matching `IslamicGeometricPattern.starPath` geometry, parchment fill (#F0EAD6)
  - Soft multi-layer noor aura (reuses `NoorRingView` stroke + blur language)
  - Sparkle particles ramping up at higher tiers
- **D-30:** Scaling runs on two axes:
  - **Every check-in day** → incremental glow-up: small size bump (~1.5px), gradient saturation bump, aura opacity bump. Feels like the bead absorbs one more day of light.
  - **Named milestone tiers** (bigger visual jumps + caption text):
    - Day 0 — *Lapsed*: dark, dim, cracked surface, no aura, star grey
    - Day 1 — *First light*: faint ember, tight halo, 1 sparkle
    - Day 3 — *Three Fajrs*: warmer ember, small aura, 2 sparkles
    - Day 7 — *One week*: clearly gold, defined halo, 3 sparkles
    - Day 14 — *Two weeks*: bright gold, larger aura, 5 sparkles
    - Day 21 — *Three weeks*: very bright, outer aura bleeds, 7 sparkles
    - Day 28 — *Sanctuary*: fully radiant, multi-layer aura, 10+ drifting sparkles
    - Day 28+ — daily glow continues incrementally; no new named tier in v1 (a future "Noor" tier at 100+ is deferred)
- **D-31:** Slow animations — bead breathes scale 0.97↔1.03 over ~4s; aura opacity modulates 0.8↔1.0; sparkles drift + twinkle on loop; inner 8-point star rotates ~360°/600s (imperceptible but alive). Lapsed state is static.
- **D-32:** Beneath the bead: existing "X Day Streak" serif text stays; add a small italic milestone caption in parchment at 70% opacity (e.g. "First light", "Three Fajrs", "Sanctuary"). The existing Islamic quote line below stays unchanged.
- **D-33:** Reuses `NoorRingView` stroke + shadow language where they overlap; the breathing noor aura is an extension of that component's vocabulary.
- **D-34:** In-flight streak glow work on `main` folds into this — do not ship separately.
- **D-35:** Implemented as SwiftUI (Canvas where needed, plain shapes where cleaner). No external dependencies. New component `StreakBeadView(streakDays: Int)` (or an in-place refactor of `heartSection`). Milestone mapping lives in a small helper type `StreakMilestone`.

### Schema Deltas
- **D-36:** `habits` gains `niyyah TEXT` nullable
- **D-37:** `profiles` gains `struggles_islamic JSONB` nullable, `struggles_life JSONB` nullable

### Claude's Discretion
- Exact step placement of niyyah prompt within the creation coordinator flow
- Gemini prompt wording for habit suggestion generation
- Fallback habit list composition
- Haptic pattern type and intensity for check-off pulse
- Canvas path math for girih-style pattern geometry
- Exact layer rotation angles and drift speeds for streak animation

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Creation Flow
- `Circles/Home/AddPrivateIntentionSheet.swift` — current 3-step habit creation (pickHabit → familiarity → generating). Quiz + niyyah prompt slot into this coordinator.

### Existing Design Components (reuse these)
- `Circles/DesignSystem/IslamicGeometricPattern.swift` — base pattern component (opacity, tileSize, color params). Streak visual extends this.
- `Circles/Moment/NiyyahDissolveView.swift` — particle dissolve animation (reference for micro-moment feel)
- `Circles/Moment/NiyyahCaptureOverlay.swift` — niyyah capture UX reference
- `Circles/DesignSystem/NoorRingView.swift` — breathing glow (sits on top of streak pattern)
- `Circles/DesignSystem/DesignTokens.swift` — all MS color + font tokens

### Existing Onboarding Flows (quiz slots into these)
- `Circles/Onboarding/AmiirOnboarding/` — insert quiz after Step 2 (Core Habits)
- `Circles/Onboarding/MemberOnboarding/` — insert quiz after Habit Alignment step

### Home Screen (streak visual lives here)
- `Circles/Home/HomeView.swift` — header section is where streak pattern renders
- `Circles/Home/HomeViewModel.swift` — `computedStreak: Int` is the intensity input

### AI Service (habit suggestions + roadmap)
- `Circles/Services/GeminiService.swift` — extend with new habit suggestion method
- `Circles/Services/HabitPlanService.swift` — reference for plan generation pattern

### Planning Context
- `.planning/ROADMAP.md` — Phase 14 scope definition
- `.planning/STATE.md` — current build state
- `.planning/notes/main.md` — scope lock decisions from 2026-04-20 session
- `~/.claude/projects/-Users-abdulsaboorshaikh-Desktop-Circles/memory/onboarding_quiz_state.md` — confirmed quiz screen content (A + B locked)

### External Skill
- `~/.claude/skills/app-onboarding-questionnaire/SKILL.md` — onboarding framework reference. Use during quiz screen implementation for psychological sequencing guidance. Only Screens A, B, C, D apply (see onboarding_quiz_state.md for full mapping).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AddPrivateIntentionSheet` 3-step coordinator: extend to add quiz intercept + niyyah step — don't rebuild from scratch
- `HabitPickTile`: reuse/adapt for Screen D habit selection grid
- `IslamicGeometricPattern`: base for streak visual — extend with layering + gold gradient + rotation
- `NoorAuraOverlay`: overlay on top of streak pattern
- `NiyyahDissolveView`: reference animation feel for "الحمد لله" micro-moment fade

### Established Patterns
- `@Observable @MainActor` coordinator pattern (see `AmiirOnboardingCoordinator`) — use same pattern for quiz coordinator
- Gold fill + dark background on selection (see familiarity step rows) — use for quiz rows
- `GeminiService.generate28DayRoadmap` pattern — follow same async/error handling for new habit suggestion method
- `DesignTokens` color tokens (`msGold`, `msBackground`, `msTextPrimary`, `msCardShared`) — all new UI uses these

### Integration Points
- `HomeViewModel.computedStreak` → drives streak pattern intensity
- `HabitService.createPrivateHabit` → add `niyyah: String?` parameter
- `profiles` table → add `struggles_islamic`, `struggles_life` columns (migration required)
- `habits` table → add `niyyah` column (migration required)
- Quiz answers saved to Supabase `profiles` before advancing to habit selection

</code_context>

<specifics>
## Specific Design Direction

### Streak Visual — Noor Bead
Centered luminous gold bead hero element, upgrading the existing `heartSection` in `HomeView.swift`. 8-point star core (matches `IslamicGeometricPattern.starPath`), radial gradient sphere, multi-layer noor aura, drifting sparkles. Grows incrementally every check-in day and hits named milestones at 1 / 3 / 7 / 14 / 21 / 28. Visual reference: `.planning/phases/14-meaningful-habits/references/streak-bead-reference.png`. SuperDesign canvas: see project `Circles Streak Geometric Pattern`.

### Quiz Screens — Tone
Warm, personal, Islamic — not clinical or survey-like. Copy treats the user as a serious Muslim trying to grow, not a beginner being onboarded. "Be honest — this shapes your journey" not "Help us personalize your experience."

### Check-off Micro-Moment
"الحمد لله" in Arabic script (not transliteration). Brief, then gone — not a celebration, a quiet acknowledgment.

</specifics>

<deferred>
## Deferred Ideas

- Hold-to-complete gesture — considered and removed. Revisit post-MVP if tap feels insufficiently intentional after real user observation.
- Per-user streak pattern seeding (niyyah-based pattern variant) — parked, post-MVP
- Quiz v2 — AI-generated suggestions beyond simple Gemini call — parked
- Pattern-based nudges ("You haven't done Quran for 3 days") — parked
- Catalog of 30 items across 5 categories — eliminated entirely, replaced by AI suggestions

</deferred>

---

*Phase: 14-meaningful-habits*
*Context gathered: 2026-04-20*
