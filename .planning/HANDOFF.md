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
- Onboarding QA pass in progress on `main`. Bugs #1–4 + #6 fixed 2026-04-26 session 1. Bug #5 closed session 2 (back-nav sufficient for MVP). Bug #7 Tier A shipped session 2. **Bug #8 shipped session 3 (this session)** — pending hands-on QA. No cross-stream conflicts.
- Earlier (2026-04-25 session 2) onboarding gaps A + B baseline still in place; gaps C (mirror copy) and D (Path 1 plan reveal) still deferred.

### Next Session — Pickup Notes
- **QA Bug #8 first.** Run Amir onboarding end-to-end. On Step 2 ("Your circle's habits"), the three ranked tiles should render a one-sentence rationale under each habit name in 12 pt serif italic. Defaults render instantly (`AmiirOnboardingCoordinator.defaultRationales`); Gemini-personalized text swaps in within 1–15 s. Watch Xcode console for `[Gemini rationales] ok — N item(s) in Xms`. Back to step 1 with no edits and return → expect `[Gemini rationales] cache hit`. Edit step 1 answer and return → expect a fresh fetch. On forced flaky network → defaults stay, no error UI. Files touched: `Circles/Services/GeminiService.swift` (+90 lines), `Circles/Onboarding/AmiirOnboardingCoordinator.swift` (+170 lines), `Circles/Onboarding/AmiirStep2HabitsView.swift` (rewritten tile layout).
- **Bug #7 Tier B / Tier C — pending user choice on provider direction.** User indicated they may switch to a faster provider rather than swap Gemini model ids. Recommendation when they're ready: add **Groq** (Llama 3.3 70B) as a parallel service used only for `generateHabitSuggestions` *and* the new `generateHabitRationales` — leaves roadmap on Gemini, zero regression risk, dramatic latency win (200–500 ms vs. 5–15 s cold). Requires new key in `Secrets.plist` (user will plug in). Skip OpenRouter (proxy hop, no win) and Nvidia NIM (more friction). Tier B (Gemini streaming) and Tier C (Gemini stable Flash swap) remain valid fallbacks if user prefers staying on Gemini.
- **Local on-device model question (Gemma/Qwen/MiniMax).** Still not recommended. Apple Foundation Models framework (iOS 18+) is the right path once Circles bumps deployment target above iOS 17.

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
