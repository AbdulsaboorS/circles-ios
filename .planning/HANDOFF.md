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
- BeReal-style regional Moment model is now code-complete in repo: 4 fixed regions, region-local `daily_moments`, regional notification routing, onboarding region confirmation, and Profile region picker
- Phase 15 rollout and combined end-to-end notification QA remain intentionally deferred

### Active Worktrees
- none currently tracked as active in this handoff

### Open Planning Thread
- Onboarding work is closed for MVP unless new bugs surface.
- Current stream is manual QA of the regional Moment rewrite plus deployment of the updated `send-moment-window-notifications` edge function.
- D1 was applied directly on Supabase by the user; D2 was added in repo and run manually. The D1 SQL still does not exist in-repo.

### Next Session — Pickup Notes
- **Run manual Moment QA for the regional model.** Focus on the two original bugs: no second window within one region-local day, and circles-list preview/timestamp matching the just-posted Moment.
- **Deploy the updated edge function before notification QA.** `supabase/functions/send-moment-window-notifications/index.ts` is updated in repo but not deployed from this session.
- **Profile/onboarding region UX is now in scope for smoke test.** Verify auto-inferred onboarding region, manual override, and Profile region changes refreshing the active `daily_moments` query without crashing.
- **Build baseline:** `xcodebuild -quiet -project Circles.xcodeproj -scheme Circles -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' build` passed on 2026-04-28. Remaining warning is the pre-existing `AuthManager.swift:21` unnecessary `await`.

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
