# Onboarding Polish — Re-entry

## Status
Onboarding-polish items #1–#5 + 2026-04-25 session work are code-complete, build-clean, and pushed to `origin/main` (commit `485c0c2`). Awaiting hands-on QA.

The implementation history (which session shipped what, file:line receipts, decision rationale) lives in `git log` and the code itself. This file only carries what the next agent needs to **test** the work or **decide** what's deferred. For full design context, the Session 1 + Session 2 plans live at `~/.claude/plans/` (search for "anchor" and "newell").

## 2026-04-25 session additions (push to QA matrix)

- **Active shared Meaningful Habits bug:** guided habit suggestions in post-auth habit creation are still returning the same 5 fallback habits regardless of selected struggles after the dashboard/habit-detail pass QA. Treat onboarding as affected too because both flows use `OnboardingQuizCoordinator.loadSuggestions()` + `GeminiService.generateHabitSuggestions(...)`. Re-test both post-auth guided add and onboarding quiz after any fix here.

- **Joiner flow reorder:** "Some growth is shared..." transition now fires BEFORE the quiz (after circle alignment), not after personal habits. Subtitle "Next, let's talk through a habit you can personally work on." matches amir.
- **New joiner intro quote:** building hadith — *"A believer to another believer is like a building — each part supporting the other."* (replaces the "one body" hadith)
- **Transition screen visuals (both flows):** pulsing moon icon (`.symbolEffect(.pulse, options: .repeating)`), breathing golden glow (3s ease-in-out repeatForever), staggered fade-in via `withAnimation` delays, drifting starfield via `TimelineView` + `Canvas` (14 stars).
- **Progress bar:** `StepIndicator` rewritten — capsule dots → continuous gradient bar with spring fill animation. Numbering corrected: amir = 7 steps (Personalization, CoreHabits, Identity, Quiz, AIGen, Location, Activation), joiner = 5 steps (CircleAlignment, Quiz, AIGen, Identity, AuthGate). Quiz screens now have the bar via `safeAreaInset(.top)`.

### QA additions for the matrix below
- Joiner: tap "I'm In" on circle alignment → see new building-hadith transition (with subtitle) BEFORE quiz starts; quiz finish goes straight to AI gen, no second transition.
- Both flows: transition screens animate in (icon → quote → subtitle → "tap" hint), starfield drifts in background, glow breathes.
- Both flows: progress bar fills smoothly between steps; amir bar reaches 7/7 at activation, joiner reaches 5/5 at auth gate; quiz screens show 4/7 (amir) and 2/5 (joiner).

## Onboarding gaps A + B — code-complete, pending QA (2026-04-25 session 2)

Path 1 locked in for Gap D (pre-auth synchronous plan generation). C and D still deferred. This session shipped A + B.

**Shipped:**
- `Circles/Onboarding/OnboardingMomentPrimerView.swift` (new) — three cascading beats (clock.badge.fill / camera.rotate.fill / eye.slash.fill), keyframe entry mirroring `OnboardingTransitionView.swift:80-111`. Primary CTA "Allow Camera" → `CameraManager.requestVideoAccess()` → `onContinue()`. Secondary "Maybe later" → `onContinue()` directly.
- Amir wiring — `case momentPrimer` + `proceedToMomentPrimer()` on coordinator; `AmiirQuizStepView`'s `onFinish`/`onFinishMany` route through primer; nav case in `AmiirOnboardingFlowView` at `5/8`.
- Joiner wiring — `case momentPrimer` + `proceedToMomentPrimer()` on coordinator; `JoinerQuizStepView.onFinish` routes through primer; nav case in `MemberOnboardingFlowView` at `3/6`.
- Step indicators bumped: amir shared 1/8, coreHabits 2/8, identity 3/8, quiz 4/8, primer 5/8, aiGen 6/8, foundation 7/8, activation 8/8. Joiner circleAlignment 1/6, quiz 2/6, primer 3/6, aiGen 4/6, identity 5/6, authGate 6/6.

**Deviation from plan/notes worth recording:**
The plan/notes both said to switch `JoinerPersonalHabitsView`'s Continue/Skip callbacks. In the actual current joiner flow (after the 2026-04-25 reorder), `personalHabits` is dead code — `proceedToPersonalHabits()` is never called and the quiz routes straight to AI gen via `JoinerQuizStepView.onFinish`. So I switched **that** edge instead. `JoinerPersonalHabitsView.swift:135` stale `current:3, total:7` was left as-is (still out of scope; the view itself is unreachable).

### QA matrix — primer-specific (run cold-installed)

**Amir**
1. Walk to primer → step bar reads `5/8`.
2. Three beats cascade in (icon → text, staggered ~0.35s).
3. Tap **Allow Camera** → system dialog appears once → grant → advances to AI gen (`6/8`).
4. Cold reinstall → primer → **Maybe later** → no system dialog → advances. Open Moment camera later → existing in-app cold prompt fires (fallback intact).
5. Cold reinstall → primer → **Allow Camera** → **Don't Allow** → advances. Open Moment camera later → existing `permissionDeniedView` Settings deep link renders.
6. Full walk: 1/8 → 2/8 → 3/8 → 4/8 → 5/8 → 6/8 → 7/8 → 8/8. No stale `/7`.

**Joiner**
7. Walk to primer (after quiz) → step bar reads `3/6`.
8. Same three CTA paths (Allow→grant, Maybe later, Allow→deny).
9. Full walk: 1/6 → 2/6 → 3/6 → 4/6 → 5/6 → 6/6.
10. Building-hadith `transitionToCircle` still fires before circle alignment, untouched.

**Cross-cut**
11. Tap Allow Camera rapidly → button disables during `isRequesting`, no double-prompt.
12. `axiom:console` during primer → no AVFoundation warnings.

---

## QA matrix

### Amir flow (cold start)
- Transition screen before the quiz shows the subtitle *"Next, let's talk through a habit you can personally work on."*
- Pre-quiz "processing" screen never exceeds ~3 s, even on airplane mode (fallback suggestions render).
- Habit-pick step: tap 2 suggestions → both selected; tap a 3rd → no-op; "Create 2 habits" CTA.
- Post-auth: 2 `habits` rows + 2 `habit_plans` rows persist for the picked suggestions.

### Shared-habit screen (#1)
- Only **3 ranked habits + custom tile** render (no longer all 10).
- Different personalization answers re-rank the 3 (e.g. "Just starting" → prayers; "Deeply rooted" → Tahajjud/Quran/Sadaqah).
- Cap-3 still holds — picking 3 ranked dims the custom tile; picking 2 ranked + custom holds at 3.

### Struggle quizzes (#3)
- "Something else…" tile appears under the enum options on both Islamic and Life screens.
- Tapping reveals a textfield; typing enables the CTA even with zero enum options selected.
- Mixed selection (1 enum + custom) → CTA enables.
- Gemini prompt does **not** contain the literal `"custom:"` prefix (verify via `axiom:console` or backend logs).
- Persisted Supabase `profiles.struggles_islamic` looks like `["custom:<text>", "<enum_slug>"]`.
- Re-entry path (post-auth habit-creation intercept): textfield pre-populates if a `custom:`-slug exists.
- Back-nav then forward → custom text persists (lives on coordinator, not view-local state).

### Joiner regression
- Joiner quiz still single-select on the habit pick screen.
- Joiner's transition screen has **no** subtitle.
- Joiner *does* now show the custom-struggle field (shared views). Decide during QA whether to keep — gating instructions in "Deferred decisions" below.

---

## Deferred decisions (NOT pre-test blockers)

- **Personalization-question copy audit** in `AmiirSharedPersonalizationView` — now load-bearing because the catalog is gone. If recommendations feel off in QA, that's where to look.
- **Persist `spiritualityLevel` / `timeCommitment` / `heartOfCircle` to `profiles`** — currently session-only; needed for future re-ranking but not day-1.
- **"See more" affordance** on the trimmed habit screen — only revisit if QA shows top-3 ranking misses too often.
- **Multi-add custom struggles** — single entry confirmed; only revisit if QA reveals the need.
- **Edit-screen UI for custom entries** — no edit screen exists yet.
- **Joiner exemption from custom struggles** — if product wants Amir-only: add `coordinator.allowsCustomStruggle: Bool = true`, set false in `JoinerQuizStepView.onAppear`, gate `QuizCustomRow` in both struggle views.

---

## Post-QA next steps

If QA passes clean → commit Sessions 1+2 work, then move on per project priority order (UI/UX pass → name → logo → animations → landing). If bugs found → file under a "Bugs" section here, fix surgically.
