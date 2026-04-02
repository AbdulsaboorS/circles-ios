# Agent handoff — Circles iOS

**Use this when switching agents.** Detailed inventory lives in `STATE.md` and `ROADMAP.md`.

## Read first

| File | Purpose |
|------|---------|
| [`STATE.md`](STATE.md) | Built features, open QA, and remaining risks |
| [`ROADMAP.md`](ROADMAP.md) | Phase order and upcoming scope |
| [`../CLAUDE.md`](../CLAUDE.md) | Repo conventions, secrets, Xcode/Supabase notes |

## Current position

- **Product:** v2.4 — Phase **11.2 (E2E QA + UX polish) IN PROGRESS**
- **Branch:** `main`
- **Remote:** `origin` → GitHub `AbdulsaboorS/circles-ios`
- **Latest pushed commit:** `7c07287`
- **User is testing on a real iPhone and plans to finish Phase 11.2 polish next, then move to Phase 11.3.**

## What shipped this session

### Already pushed before this session
- `df2b2f9` — QA batch 4: roadmap refinement decode fixed, avatar upload error surfaced, avatar bucket RLS added, `daily_moments` row seeded
- `97d316e` — auto-commit wrapper

### Pushed this session
- `4fa6ce6` — local **Reflection Log** for `HabitDetailView` (`UserDefaults`, one note per habit per day, today-only UI)
- `d5bf103` — invite preview refresh + **username-based test login** (`username` maps to `username@circles.test`)
- `0c858d2` — camera permission fix (`NSCameraUsageDescription`), debug camera shortcuts, lowercase storage paths for avatar/moment uploads
- `459772a` — member onboarding habit-step UX simplification + real Moment post error exposure
- `fcc4c9c` — roadmap loading overlay for generate/refine
- `7c07287` — capture reset fix + member onboarding CTA validation/unblock attempt

## What is confirmed working

- Profile photo upload now works.
- AI refinement decode path now works; token-limit message appears correctly when applicable.
- Reflection Log is implemented on `HabitDetailView`.
- Camera permission prompt now appears and the camera can capture.
- Invite preview page is on the green Midnight Sanctuary styling and includes test-account login.

## Open blockers paused for next session

### 1. Moment posting still fails with RLS
- **Observed error on device:** `new row violates row level security policy`
- Camera capture works, but posting a Moment still fails at the backend insert step.
- This is no longer a camera problem; it is likely a **Supabase RLS policy issue on `circle_moments`**.
- UI now surfaces the actual error in `MomentPreviewView`.
- Likely next step: inspect `circle_moments` INSERT policy in Supabase and align it with current authenticated circle-member rules.

### 2. First camera capture sometimes shows a white screen
- User reports a one-time bug on the first camera attempt: tap shutter → white screen.
- If they back out and retry, camera flow behaves more normally.
- Capture reset logic was added, but this one-time white-screen bug is **not confirmed fixed**.

### 3. Preview image can still look stale/weird
- User reported that the preview sometimes looked like the previous shot instead of the latest one.
- Reset logic was added in camera and presentation flow, but this is **not yet verified resolved**.

### 4. Member onboarding still blocks at first screen
- Even after habit-step UX updates, user still says they **cannot get past the first message/screen**.
- The relevant files are:
  - `Circles/Onboarding/MemberStep1HabitsView.swift`
  - `Circles/Onboarding/MemberOnboardingFlowView.swift`
  - `Circles/Onboarding/MemberOnboardingCoordinator.swift`
- User specifically said: "**STIL not leting me get past the first message.**"
- Next agent should watch for whether:
  - validation is shown but navigation does not occur,
  - navigation path updates but screen does not transition,
  - or the user is still blocked before habit selection is recognized.

## UX follow-ups requested but not yet done

- Feed card consolidation:
  - desired layout: `PFP - NAME > CIRCLE`
  - second line: `checking into 'habit'`
- PFP persistence/consistency across more surfaces, especially onboarding and feed.
- Invite preview should show user PFPS if backend preview access permits it.
- Moment compositing/output still needs polish after backend posting is unblocked.

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
- `Circles/Auth/AuthView.swift`
- `Circles/Onboarding/CirclePreviewView.swift`
- `Circles/Info.plist`
- `Circles/Services/AvatarService.swift`
- `Circles/Services/MomentService.swift`
- `Circles/Moment/MomentPreviewView.swift`
- `Circles/Moment/MomentCameraView.swift`
- `Circles/Moment/CameraManager.swift`
- `Circles/Onboarding/MemberStep1HabitsView.swift`
- `Circles/Community/CommunityView.swift`
- `Circles/Circles/CircleDetailView.swift`

## Quick next-session priority order

1. Fix `circle_moments` RLS so posting works.
2. Reproduce and fix the first-capture white-screen / stale-preview bug if still present.
3. Fix the member onboarding first-screen blocker.
4. Finish Phase 11.2 feed/PFP polish.
5. Then begin Phase 11.3 onboarding-in-depth work.
