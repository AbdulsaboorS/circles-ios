# Onboarding Polish — Re-entry

## Status
Onboarding-polish items #1–#5 + 2026-04-25 session work are code-complete, build-clean, and pushed to `origin/main` (commit `485c0c2`). Awaiting hands-on QA.

The implementation history (which session shipped what, file:line receipts, decision rationale) lives in `git log` and the code itself. This file only carries what the next agent needs to **test** the work or **decide** what's deferred. For full design context, the Session 1 + Session 2 plans live at `~/.claude/plans/` (search for "anchor" and "newell").

## 2026-04-25 session additions (push to QA matrix)

- **Joiner flow reorder:** "Some growth is shared..." transition now fires BEFORE the quiz (after circle alignment), not after personal habits. Subtitle "Next, let's talk through a habit you can personally work on." matches amir.
- **New joiner intro quote:** building hadith — *"A believer to another believer is like a building — each part supporting the other."* (replaces the "one body" hadith)
- **Transition screen visuals (both flows):** pulsing moon icon (`.symbolEffect(.pulse, options: .repeating)`), breathing golden glow (3s ease-in-out repeatForever), staggered fade-in via `withAnimation` delays, drifting starfield via `TimelineView` + `Canvas` (14 stars).
- **Progress bar:** `StepIndicator` rewritten — capsule dots → continuous gradient bar with spring fill animation. Numbering corrected: amir = 7 steps (Personalization, CoreHabits, Identity, Quiz, AIGen, Location, Activation), joiner = 5 steps (CircleAlignment, Quiz, AIGen, Identity, AuthGate). Quiz screens now have the bar via `safeAreaInset(.top)`.

### QA additions for the matrix below
- Joiner: tap "I'm In" on circle alignment → see new building-hadith transition (with subtitle) BEFORE quiz starts; quiz finish goes straight to AI gen, no second transition.
- Both flows: transition screens animate in (icon → quote → subtitle → "tap" hint), starfield drifts in background, glow breathes.
- Both flows: progress bar fills smoothly between steps; amir bar reaches 7/7 at activation, joiner reaches 5/5 at auth gate; quiz screens show 4/7 (amir) and 2/5 (joiner).

## Next session — premium animation pass

User wants to use the `axiom-swiftui-animation-ref` skill to upgrade the transition entry from plain fades to **KeyframeAnimator** with multi-track keyframes. Concrete plan when resuming:

- Icon: scale settle 0.85 → 1.05 (overshoot) → 1.0 + opacity 0 → 1
- Quote: slide-up 8pt + opacity (different timing curve from icon)
- Subtitle: slide-up 4pt + opacity, slight lag
- Glow: one-time entry pulse (1.0 → 1.3 → 1.0) before settling into the existing slow breathing loop

Restraint is the rule — small offsets (≤8pt), generous durations (≥0.5s). Apply inside `OnboardingTransitionView` so both flows benefit from one change.

> **Note for next session:** user will briefly QA today's changes first, then move to the keyframe upgrade.

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
