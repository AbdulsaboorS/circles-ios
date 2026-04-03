# Agent handoff — Circles iOS

**Use this when switching agents.** Detailed inventory lives in `STATE.md` and `ROADMAP.md`.

## Read first

| File | Purpose |
|------|---------|
| [`STATE.md`](STATE.md) | Built features, open QA, and remaining risks |
| [`ROADMAP.md`](ROADMAP.md) | Phase order and upcoming scope |
| [`../CLAUDE.md`](../CLAUDE.md) | Repo conventions, secrets, Xcode/Supabase notes |

## Current position

- **Product:** v2.4 — Phase **11.3 (Onboarding In Depth) — Waves 1+2 COMPLETE**
- **Branch:** `main`
- **Remote:** `origin` → GitHub `AbdulsaboorS/circles-ios`
- **Next session must execute `11.3-06`** — ContentView auth-last routing + HomeView post-auth nudge.

## What shipped this session

### Plans 11.3-03 and 11.3-05 both complete

**11.3-03 — Amir coordinator rewrite (auth-last):**
- `AmiirOnboardingCoordinator`: full rewrite — 8-case Step enum (coreHabits, circleIdentity, transitionToPersonal, personalIntentions, transitionToAI, aiGeneration, foundation, activation); removed `soulGate`/`location`/`landing`
- `flushToSupabase(userId:)`: post-auth Supabase writer (profile + circle + habits + AI plans); `savePendingState()` persists to UserDefaults before auth gate
- `completeOnboarding(userId:)`: simplified to UserDefaults flag + `isComplete = true`
- `AmiirOnboardingFlowView`: root is now `AmiirLandingSanctuaryView`; all 8 steps wired including `OnboardingTransitionView` for both transitions
- `AmiirStep2HabitsView`: StepIndicator 1/7; CTA → `proceedToIdentity()`
- `AmiirStep1IdentityView`: StepIndicator 2/7; CTA → `proceedToTransitionToPersonal()`
- `AmiirStep3PersonalView`: cap 2 (not 3); StepIndicator 3/7; CTA/Skip → `proceedToTransitionToAI()`
- `AmiirStep3LocationView`: auth removed; push notification soft ask added; city tap → `proceedToActivation()`; StepIndicator 5/7

**11.3-05 — Joiner coordinator rewrite (auth-last):**
- `MemberOnboardingCoordinator`: full rewrite — 7-case Step enum (circleAlignment, transitionToPersonal, personalHabits, transitionToAI, aiGeneration, identity, authGate); removed `landing`/`location`/`habitAlignment`
- `init(inviteCode: String = "")`: default arg keeps ContentView backward compat until 11.3-06 updates it
- `flushToSupabase(userId:)`: post-auth Supabase writer (join circle + habits + AI plans); `savePendingState()` persists before auth gate
- `MemberOnboardingFlowView`: clean 7-step routing from `JoinerLandingView` root; uses `OnboardingTransitionQuote` constants
- `MemberStep1HabitsView` / `MemberStep2LocationView`: compile-only fixes (dead code in new flow)

## What is confirmed working

- Phase 11.3 Waves 1+2 compile cleanly: `BUILD SUCCEEDED`
- Both Amir and Joiner coordinator rewrites are auth-last
- Both flow views root at the correct landing screens
- `OnboardingPendingState` is saved before auth gate in both flows
- `flushToSupabase` is ready to be called from ContentView post-auth

## What is NOT yet done (for next session)

### 11.3-06 — ContentView auth-last routing + HomeView post-auth nudge

This is the final plan in Phase 11.3. It must:
1. Update `ContentView` to detect a pending Amir or Joiner state after sign-in and call `flushToSupabase(userId:)` on the correct coordinator
2. Route authenticated Amir users who have `OnboardingPendingState` (flowType = "amir") → call `amiirCoordinator.flushToSupabase(userId:)`
3. Route authenticated Joiner users who have `OnboardingPendingState` (flowType = "member") → call `memberCoordinator.flushToSupabase(userId:)`
4. Update `ContentView`'s `MemberOnboardingCoordinator(inviteCode: code)` calls to plain `MemberOnboardingCoordinator()` (since `inviteCodeInput` is now set via `submitInviteCode`)
5. Add a HomeView post-auth nudge (optional per plan spec — read 11.3-06-PLAN.md carefully)

**Run this command to execute:**
```
/gsd:execute-phase 11.3-06 --interactive
```

## Testing notes

- Deep link for Joiner testing (use Notes/Messages/Mail/Safari — not Chrome address bar):
  - `circles://join/Z5QZTNN5`
- Moment posting: re-test only during a real prayer window (deferred from 11.2)

## Backend/manual items still outstanding

- `seed-daily-moment` Edge Function deployed but **daily cron is not set up**:
  1. Enable `pg_cron`
  2. Create daily HTTP cron job → `/functions/v1/seed-daily-moment`

## Key files for 11.3-06

- `Circles/ContentView.swift` — main routing target
- `Circles/Home/HomeView.swift` — post-auth nudge target
- `Circles/Onboarding/OnboardingPendingState.swift` — `load()` / `hasPendingState()` / `clear()`
- `Circles/Onboarding/AmiirOnboardingCoordinator.swift` — `flushToSupabase(userId:)`
- `Circles/Onboarding/MemberOnboardingCoordinator.swift` — `flushToSupabase(userId:)`
