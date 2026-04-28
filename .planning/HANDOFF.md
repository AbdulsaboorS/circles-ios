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
- Deterministic onboarding `HabitCatalog` flow and final onboarding QA fixes are on `main`
- Onboarding is fully functional and MVP-ready after user hands-on QA of both Amir and Joiner flows on 2026-04-27
- UX pass fixes are now shipped for Home, Community/feed, Circles, Habit detail/roadmap, and Journey
- Profile/settings UX pass was not completed; no new Profile/settings product changes were shipped in this stream
- Phase 15 rollout and combined end-to-end notification QA remain intentionally deferred

### Active Worktrees
- none currently tracked as active in this handoff

### Open Planning Thread
- Onboarding work is closed for MVP unless new bugs surface.
- Current stream is bug-bashing the shipped UX pass across Home → Feed → Circles → Habit → Journey.
- After bug-bashing, finish the deferred Profile/settings UX pass, then move to dedicated UI polish. Phase 15 rollout stays deferred.

### Next Session — Pickup Notes
- **Continue bug-bashing the shipped UX pass.** User is testing Home → Feed → Circles → Habit → Journey and will report user-visible bugs next session.
- **Shipped UX areas to treat as active QA scope:** Home/Daily Intentions, Community feed + gate states, circles list/detail/join/create, habit detail + plan generation/refinement, and Journey.
- **Deferred area:** Profile/settings still needs its dedicated UX pass; no new Profile/settings UI behavior was intentionally shipped in this stream.
- **Build baseline:** `xcodebuild -quiet -project Circles.xcodeproj -scheme Circles -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' build` passed on 2026-04-27. Remaining warning is the pre-existing `FeedService.swift:99` unnecessary `await`.

### Product Priority Order
1. Bug-bash the shipped UX pass and fix the reported issues
2. Finish the deferred Profile/settings UX pass
3. Do the full UI polish pass
4. Finalize the name
5. Finalize the logo
6. Work on landing-page video animations and onboarding animations if needed

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
