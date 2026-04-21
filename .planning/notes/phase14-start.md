# Phase 14 — Session Re-entry

## Status
Discuss-phase complete. CONTEXT.md locked. Ready to build.

## First Task — SuperDesign: Streak Pattern
Run `/superdesign` and prompt it with:

> Design the master geometric streak visual for Circles iOS (Midnight Sanctuary dark theme, SwiftUI Canvas).
> 
> This is a full-width background behind the Home tab header. It uses girih-style interlocking Islamic geometry (Ottoman/Andalusian polygon tessellations — NOT simple 8-pointed star tiling).
> 
> Design 4 states showing progression:
> - Day 1: one faint layer, barely visible, ember light feel
> - Day 7: second slightly rotated layer added, more presence  
> - Day 30: third layer, gold gradient on lines, more saturated
> - Day 100+: fully awakened — all layers rich, NoorAura glow on top
>
> Colors: dark background #1B261B, gold #D4A240, deep forest #243828
> Each layer drifts at a different slow imperceptible rotation speed (feels alive, not static).
> Gold gradient fills the pattern lines (not white strokes).
> SwiftUI Canvas-based component, no external dependencies.

Get user sign-off on the visual direction, then move to build.

## Build Order (chat-mode, no executor agent)
Work through these in order — each is a self-contained commit:

1. **SQL migration** — `habits.niyyah TEXT` nullable + `profiles.struggles_islamic JSONB` + `profiles.struggles_life JSONB`. Run via Supabase Dashboard → SQL Editor. Confirm with user before running.

2. **Quiz screens A+B + coordinator** — New `OnboardingQuizCoordinator` with 4 steps (Islamic struggles → Life struggles → Processing/Gemini call → Habit selection). Wire into `AmiirOnboardingCoordinator` (after Step 2) and `MemberOnboardingCoordinator` (after Habit Alignment). Add intercept gate to `AddPrivateIntentionSheet`. See `onboarding_quiz_state.md` for confirmed screen content.

3. **GeminiService — habit suggestions** — New method `generateHabitSuggestions(islamicStruggles: [String], lifeStruggles: [String]) async throws -> [HabitSuggestion]`. Returns max 6 items (name + "why this fits you"). Static fallback if API fails.

4. **Niyyah field** — Add optional `niyyah: String?` step to `AddPrivateIntentionSheet` between pick and familiarity. Pass to `HabitService.createPrivateHabit`. Display as emotional header on `HabitDetailView`. Feed into Gemini roadmap prompt.

5. **Check-off micro-moment** — On habit completion in `HomeView` habit rows: "الحمد لله" text fades in, dissolves after 1.5s. Subtle gold haptic pulse. No gesture change.

6. **Streak Canvas component** — New `StreakGeometricPatternView(streakDays: Int)` using girih geometry. Full-width behind header in `HomeView`. Intensity driven by `viewModel.computedStreak`. Layer count: 1 (day 1), 2 (day 7+), 3 (day 30+). Slow rotation per layer.

## Key Files to Read First
- `.planning/phases/14-meaningful-habits/14-CONTEXT.md` — all decisions
- `~/.claude/projects/-Users-abdulsaboorshaikh-Desktop-Circles/memory/onboarding_quiz_state.md` — quiz screen content
- `Circles/Home/AddPrivateIntentionSheet.swift` — creation flow to extend
- `Circles/Home/HomeView.swift` — streak visual placement
- `Circles/DesignSystem/IslamicGeometricPattern.swift` — base pattern to upgrade
- `Circles/Onboarding/` — existing coordinator patterns to follow

## Do Not
- Run GSD plan-phase or execute-phase (user prefers chat-mode for this phase)
- Reopen scope (no arcs, end_dates, hold-to-complete, photo evidence, per-user seeding)
- Touch PROJECT.md (deferred intentionally)
