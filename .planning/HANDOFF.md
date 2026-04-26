# Shared Handoff

Repo-wide coordination only. Keep this file short.

Use it for:
- what is on `main`
- active worktrees when they exist
- merge sequencing
- overlap risks

Do not use it for session history, long QA plans, or feature specs.

## Current Repo State

### Default Branch
- `main`

### On Main
- Phase 13 UI/UX pass is complete
- Journey tab shipped
- Profile hero/settings polish shipped
- Phase 14 Meaningful Habits is built and awaiting hands-on validation
- Phase 15 Social Pulse is now merged to `main`
- Phase 15 rollout and combined end-to-end notification QA remain intentionally deferred

### Active Worktrees
- none currently tracked as active in this handoff

### Open Planning Thread
- Onboarding QA pass in progress on `main`. Five minor issues fixed 2026-04-26 (Prayer Sync reframe + double back button, primer copy + niyyah beat, AI-gen → primer transition softened, quiz processing copy). 2026-04-26 session 2 closed bug #5 (step-by-step back-nav confirmed sufficient for MVP, full back-to-start deferred) and shipped Tier A reliability work for #7. Bug #8 still open. No cross-stream conflicts.
- Earlier (2026-04-25 session 2) onboarding gaps A + B baseline still in place; gaps C (mirror copy) and D (Path 1 plan reveal) still deferred.

### Next Session — Pickup Notes
- **Bug #8 (shared-intentions personalization)** is the headline next slice. Decision aligned: keep curated pool of 10 habits fixed, but add Gemini-generated rationales per tile. Match parity with personal-intentions Quiz screen which already shows rationales. See `Circles/Onboarding/AmiirStep2HabitsView.swift` (`.prefix(3)` cap, `habitScore` ranking) and `Circles/Onboarding/Quiz/QuizHabitSelectionView.swift:183` for the rationale render pattern.
- **Bug #7 — Tier B (streaming).** Tier A (timeout 8→15s, `maxOutputTokens: 400`, elapsed-time logs) shipped this session. If user still sees fallback under realistic conditions after Tier A, switch `generateHabitSuggestions` to `streamGenerateContent` for incremental rendering. This is naturally bundled with #8 since both touch `GeminiService` and the suggestions render path.
- **Tier C (model id experiment).** Optional 5-min check: try moving off `gemini-3-flash-preview` to a stable Flash. Risk: same model id is also used by `generate28DayRoadmap`, so any change must be regression-tested on the Generate-Plan path before commit. Hold until a focused session.
- **Local on-device model question (Gemma/Qwen/MiniMax).** Recommendation: not now. Quantized 2-3B models add 1.5-2.5GB to app size or require first-run download (both bad UX), and inference on iPhone is *slower* than Gemini cloud (~10-15s for 300 tokens), not faster. The blessed Apple path is the **Foundation Models framework** (iOS 18+), but Circles' deployment target is iOS 17. Revisit when bumping deployment target — Apple ships the model for free, no app size cost, offline capable.

### Product Priority Order
1. Test onboarding bugs and fix them
2. Do the full UI/UX pass
3. Finalize the name
4. Finalize the logo
5. Work on landing-page video animations and onboarding animations if needed

## Integration Hotspots

- `Circles/CirclesApp.swift`
- `Circles/ContentView.swift`
- `Circles/Navigation/`
- `Circles/Services/`
- `Circles/Profile/`
- `Circles/Home/`
- shared notification models and routing

## Coordination Rules

- one active stream per `git worktree`
- one branch per stream
- no direct commits to `main` unless the user explicitly wants main updated
- keep this file repo-wide and current-state only
- keep detailed QA notes outside startup docs
