# Shared Handoff

Repo-wide coordination only. Session detail lives in `.planning/notes/`.

---

## On Main (2026-04-22)

- Phases 1–14 complete
- Amir Onboarding Overhaul tasks 1-4 shipped (`e982259`): flow reorder, personalization screen, dead code removed, routing bug fixed
- Phase 14 QA tests 1-2 still pending (deferred until tasks 5-6 done)

## Active Branches

- `phase-15-social-pulse` — worktree at `.claude/worktrees/phase-15-social-pulse`
  - 15.1 + 15.2 built, pending user verification
  - Remaining: 15.3 circle check-in notifications, 15.4 habit reminders, hardening
  - **Do not merge until Amir overhaul tasks 5-6 ship and QA passes on `main`**

## Next on Main

**Amir Onboarding Overhaul — Tasks 5-6** (continuation of previous session).

### Task 5 — Catalog Ranking

Reorder `AmiirOnboardingCoordinator.curatedHabits` in `AmiirStep2HabitsView` based on the three personalization answers collected in `AmiirSharedPersonalizationView`.

**Key files:**
- `Circles/Onboarding/AmiirStep2HabitsView.swift` — `ForEach(AmiirOnboardingCoordinator.curatedHabits, ...)` at line 42; replace static array with a ranked computed result
- `Circles/Onboarding/AmiirOnboardingCoordinator.swift` — coordinator holds `spiritualityLevel`, `timeCommitment`, `heartOfCircle` (all `String?`)

**Ranking logic to implement (suggested — iterate with user):**

Personalization answers → priority boost for matching habits:

| Answer | Habits to surface first |
|--------|------------------------|
| `spiritualityLevel` = "Just starting out" | Fajr, Dhuhr, Asr, Maghrib, Isha (consistency, not depth) |
| `spiritualityLevel` = "Building a foundation" | Fajr, Quran, Dhikr |
| `spiritualityLevel` = "Steady and growing" | Tahajjud, Quran, Sadaqah |
| `spiritualityLevel` = "Deeply rooted" | Tahajjud, Sadaqah, Fasting |
| `heartOfCircle` = "Salah, together" | All 5 prayers first |
| `heartOfCircle` = "Quran in our lives" | Quran first |
| `heartOfCircle` = "Remembrance of Allah" | Dhikr first |
| `heartOfCircle` = "Brotherhood through hardship" | Sadaqah, Fasting first |
| `timeCommitment` = "5–10 minutes" | de-prioritize Tahajjud, Fasting |
| `timeCommitment` = "More than an hour" | Tahajjud, Quran, Fasting at top |

Ranking approach: score each curated habit with a point for each matching rule, then sort descending. Custom habit tile always stays last.

### Task 6 — QA

Full fresh-install pass after task 5 ships:

1. **Fresh Amir onboarding** (clear `onboardingComplete_<uid>` from UserDefaults + sign out):
   - Landing → Shape Your Circle screen appears (NOT circleIdentity)
   - Pick all 3 questions → Continue enables → habits screen shows reordered catalog
   - Habits → "Build the Foundation" → circleIdentity
   - circleIdentity → "Some growth is private" transition screen
   - Tap through transition → onboarding quiz (Phase 14)
   - Complete quiz → AI generation screen (personal catalog must NOT appear)
   - Through AI gen → location → auth
   - Confirm StepIndicator advances: 1 (personalization) → 2 (habits) → 3 (identity) → 4 (AI gen) → 5 (location) → 6 (auth)

2. **Phase 14 test 2 — Fresh Member onboarding**: verify `OnboardingTransitionQuote.amirSharedToPrivate` still renders (used in Member flow).

3. **Phase 14 tests 3-6** already verified — no re-test needed.

After QA passes → mark Phase 14 QA complete in STATE.md → merge `phase-15-social-pulse`.

## Integration Hotspots

- `Circles/CirclesApp.swift`
- `Circles/ContentView.swift`
- `Circles/Services/`
- `Circles/Home/`
- `Circles/Onboarding/`
