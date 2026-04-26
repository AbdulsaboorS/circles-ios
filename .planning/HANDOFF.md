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
- **Onboarding Moment primer revamped 2026-04-26.** Primer position flipped: was `quiz → primer → AI gen`, now `quiz → AI gen → primer` so the "your Moment is the cue back to your habits" value prop lands after the plan reveal. Amir primer is now step 6/8, Joiner 4/6. AI-gen indicators shifted to Amir 5/8 and Joiner 3/6. `OnboardingMomentPrimerView` rebuilt: animated phone-frame demo at top (`MomentDemoView` — TimelineView 6s loop: viewfinder w/ countdown pill + dual capture + Maghrib gradient → flash → niyyah typewrites *"Reading Qur'an after Maghrib, for the creator."* → "Posted ✓" → fade) and reframed copy ("Once a day. One chance." / "Your daily cue back." / "Only your circle sees it."). Stale "near a prayer time" line scrubbed. Demo is SwiftUI-only MVP, designed as a single swappable component for a real recorded video before launch. **Awaiting hands-on QA next session.**
- Earlier (2026-04-25 session 2) onboarding gaps A + B baseline still in place; gaps C (mirror copy) and D (Path 1 plan reveal) still deferred.

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
