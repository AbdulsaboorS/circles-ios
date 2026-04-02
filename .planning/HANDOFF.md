# Agent handoff — Circles iOS

**Use this when switching agents.** Detailed inventory lives in `STATE.md` and `ROADMAP.md`.

## Read first

| File | Purpose |
|------|---------|
| [`STATE.md`](STATE.md) | Built features, open QA, and remaining risks |
| [`ROADMAP.md`](ROADMAP.md) | Phase order and upcoming scope |
| [`../CLAUDE.md`](../CLAUDE.md) | Repo conventions, secrets, Xcode/Supabase notes |

## Current position

- **Product:** v2.4 — Phase **11.2 (E2E QA + UX polish) COMPLETE**
- **Branch:** `main`
- **Remote:** `origin` → GitHub `AbdulsaboorS/circles-ios`
- **Latest pushed commit:** pending close-out push from this session
- **Next session should begin Phase 11.3 onboarding rebuild work.**

## What shipped this session

### Already pushed before this session
- `df2b2f9` — QA batch 4: roadmap refinement decode fixed, avatar upload error surfaced, avatar bucket RLS added, `daily_moments` row seeded
- `97d316e` — auto-commit wrapper

### Pushed before this close-out
- `4fa6ce6` — local **Reflection Log** for `HabitDetailView` (`UserDefaults`, one note per habit per day, today-only UI)
- `d5bf103` — invite preview refresh + **username-based test login** (`username` maps to `username@circles.test`)
- `0c858d2` — camera permission fix (`NSCameraUsageDescription`), debug camera shortcuts, lowercase storage paths for avatar/moment uploads
- `459772a` — member onboarding habit-step UX simplification + real Moment post error exposure
- `fcc4c9c` — roadmap loading overlay for generate/refine
- `7c07287` — capture reset fix + member onboarding CTA validation/unblock attempt

### Implemented in this closing session
- AI roadmap overlay now shows a lightweight animated progress treatment during generate/refine instead of a static loading state.
- Moment camera/preview flow was refactored:
  - first-shot white screen fixed by moving preview presentation to item-based draft state
  - stale preview fixed by capture-generation tracking in `CameraManager`
  - shutter gated on `isSessionReady`
  - debug camera shortcuts removed after QA
- Feed cards now use a shared identity header with **avatar + name + circle + timestamp**.
- Habit check-in copy now follows the requested structure:
  - `PFP - NAME > CIRCLE`
  - second line `checking into 'habit'`
- Feed author avatars now come from a shared author-profile cache in `FeedViewModel`, not only reaction profiles.
- Invite preview now shows a cleaner member face pile + avatar-backed member preview rows.

## What is confirmed working

- Profile photo upload now works.
- AI refinement decode path now works; token-limit message appears correctly when applicable.
- Reflection Log is implemented on `HabitDetailView`.
- Camera permission prompt now appears and the camera can capture.
- First-shot white-screen path is fixed.
- Feed header/avatar polish is implemented and approved by the user.
- Invite preview page is on the green Midnight Sanctuary styling, includes test-account login, and shows member PFPS/face pile where preview fetch permits it.

## Deferred items for later verification

### 1. Moment posting should be re-tested only in a real prayer window
- Out-of-window/debug-style post testing surfaced `StorageError(... "new row violates row-level security policy" ...)`.
- User considers that acceptable for now because the post path should be verified against a **real live Moment window**, not a forced test shortcut.
- Do not spend more time on this in Phase 11.2. Re-check only when a real Moment of the Day triggers.
- UI already surfaces the real error in `MomentPreviewView` if it fails again.

### 2. Moment compositing/output still needs polish later
- Core camera bugs were fixed, but the actual composited image treatment may still need visual polish once real posting is verified.
- Treat this as a future quality pass, not a current blocker.

### 3. Member onboarding blocker is superseded
- The remaining joiner/onboarding rough edges are intentionally deferred because Phase 11.3 will rebuild onboarding in depth.
- Do not chase the old first-screen blocker unless it blocks Phase 11.3 migration work itself.

## Testing notes for next agent

- For deep-link testing on iPhone, **do not use Chrome’s address bar**.
- Current supported deep-link path is custom URL scheme:
  - `circles://join/Z5QZTNN5`
- Use a tappable link from Notes, Messages, Mail, or Safari.
- `https://joinlegacy.app/join/...` is **not** a universal-link app open flow yet.

## Backend/manual items still outstanding

- `seed-daily-moment` Edge Function is deployed, but **daily cron setup is still manual**:
  1. Enable `pg_cron`
  2. Create daily HTTP cron job hitting `/functions/v1/seed-daily-moment`

## Relevant files touched this session

- `Circles/Home/HabitDetailView.swift`
- `Circles/Home/ReflectionLogStore.swift`
- `Circles/Onboarding/CirclePreviewView.swift`
- `Circles/Feed/FeedIdentityHeader.swift`
- `Circles/Feed/FeedView.swift`
- `Circles/Feed/FeedViewModel.swift`
- `Circles/Feed/HabitCheckinRow.swift`
- `Circles/Feed/MomentFeedCard.swift`
- `Circles/Feed/StreakMilestoneCard.swift`
- `Circles/Moment/MomentPreviewView.swift`
- `Circles/Moment/MomentCameraView.swift`
- `Circles/Moment/CameraManager.swift`
- `Circles/Community/CommunityView.swift`
- `Circles/Circles/CircleDetailView.swift`

## Quick next-session priority order

1. Begin **Phase 11.3 — Onboarding In Depth**.
2. Use `.planning/phases/11.3-onboarding-in-depth/` plans as the implementation guide.
3. Carry forward only these deferred checks from 11.2:
   - re-test Moment posting during a real prayer window
   - polish composited Moment output later if needed
