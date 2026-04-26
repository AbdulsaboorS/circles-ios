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

## Next session — finish onboarding gaps A + B (paused at context limit 2026-04-25)

**Approved plan:** `~/.claude/plans/i-pick-path-1-delegated-jellyfish.md` (read this first — has insertion points, screen design, exact step-indicator deltas, verification checklist).

**Path 1 locked in for Gap D** (pre-auth synchronous plan generation). C and D are deferred to a later session. This session only ships A + B.

**Shipped this session:**
- `CameraManager.swift` — added `static func requestVideoAccess() async -> Bool`. Onboarding-safe, only prompts when status is `.notDetermined`. Existing `checkPermission()` untouched.

**Remaining (do in this order):**
1. **Create `Circles/Onboarding/OnboardingMomentPrimerView.swift`** — single shared view, three educational beats (clock.badge.fill / camera.rotate.fill / eye.slash.fill), cascading keyframe entry mirroring `OnboardingTransitionView.swift:80-111`. Init: `currentStep: Int, totalSteps: Int, onContinue: () -> Void`. Primary CTA "Allow Camera" calls `CameraManager.requestVideoAccess()` then `onContinue()` regardless of result. Secondary "Maybe later" calls `onContinue()` directly. Reuse `Color.msGold/.msBackground/.msTextPrimary/.msTextMuted` and `StepIndicator`.
2. **Amir wiring** — add `case momentPrimer` to `AmiirOnboardingCoordinator.Step` (between `onboardingQuiz` and `aiGeneration`), add `proceedToMomentPrimer()`, switch `AmiirQuizStepView`'s exit callback to call it instead of `proceedToAIGeneration()`. Add the case to `AmiirOnboardingFlowView` nav switch with `currentStep: 5, totalSteps: 8`. Bump step indicators: shared 1/8, coreHabits 2/8, identity 3/8, quiz 4/8, aiGen 6/8, foundation 7/8, activation 8/8.
3. **Joiner wiring** — add `case momentPrimer` to `MemberOnboardingCoordinator.Step` (between `personalHabits` and `aiGeneration`), add `proceedToMomentPrimer()`, switch `JoinerPersonalHabitsView`'s "Continue" + "Skip" callbacks (lines 138, 167) from `proceedToAIGeneration()` to it. Add nav case to `MemberOnboardingFlowView` with `currentStep: 3, totalSteps: 6`. Bump step indicators: circleAlignment 1/6, joinerQuiz 2/6, aiGen 4/6, identity 5/6, authGate 6/6.
4. **Pre-existing JoinerPersonalHabitsView.swift:135 bug** — `StepIndicator(current: 3, total: 7)` is a stale leftover (joiner is /5 today, /6 after this work). NOT in scope but worth flagging if QA notices it.
5. Build + walk verification checklist from the plan file.

All file paths, line numbers, callback patterns, and the complete reuse list are in the plan file — no need to re-derive.

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
