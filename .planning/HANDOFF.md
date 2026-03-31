# Agent handoff — Circles iOS

**Use this when switching agents.** Detailed inventory lives in `STATE.md` and `ROADMAP.md`.

## Read first

| File | Purpose |
|------|---------|
| [`STATE.md`](STATE.md) | What's built, phase list, **open issues & QA** |
| [`ROADMAP.md`](ROADMAP.md) | Phase 12 scope + remaining work |
| [`../CLAUDE.md`](../CLAUDE.md) | Repo layout, conventions, SQL notes, troubleshooting |

## Current position

- **Product:** v2.4 — Phase **11.2 (E2E QA + Bug Fixes) IN PROGRESS**
- **Latest commit:** `db72af5` (Phase 11.2 QA fixes batch 1) + uncommitted batch 2 in session
- **User is actively testing on their real device.** More QA feedback expected.

## What was done this session (Phase 11.2 QA fixes)

### Batch 1 — commit `db72af5`
- **Amir onboarding Step 1:** Added "Your Name" field → saved to `profiles.preferred_name`
- **Amir onboarding: new Step 3 (Personal Intentions):** Curated grid filtered from shared habits, skippable, max 3 selections; created as private habits (`is_accountable=false`) in `createCircleAndProceed`; AI roadmaps fire for them too. StepIndicator updated to 5 steps across all Amir onboarding views.
- **HomeView header:** Centered + enlarged (28→34pt)
- **ProfileView:** "Edit Profile" sheet added — editable display name + read-only email
- **DB:** Deduplicated `habit_plans` rows; added `UNIQUE(habit_id, user_id)` constraint (named `habit_plans_habit_id_user_id_key`) → fixes ON CONFLICT error on 28-day plan generation
- **DB:** Inserted `daily_moments` row for 2026-03-31 with `prayer_name = 'dhuhr'`

### Batch 2 — uncommitted at session end (commit immediately)
- **ProfileView `saveProfileName`:** Fixed to use `[String: AnyJSON]` (was `[String: String]`, not persisting)
- **DailyMomentService:** Added fallback — if no location in profile, `windowStart = startOfDay` so gate opens for location-less accounts during testing
- **ContentView:** Returning (already-onboarded) users opening an invite deep link now get `JoinFromLinkView` sheet instead of being silently routed to the main tab
- **New file `JoinFromLinkView.swift`:** Thin wrapper around `JoinCircleView` with pre-filled code for deep link join
- **HomeView FAB:** Lowered `.padding(.bottom, 88)` → `16` (was floating too high above tab bar)
- **HabitDetailView:** Weekly plan cards now default to all-collapsed; after `generatePlan()` succeeds, Week 1 is auto-expanded so user sees it generated

## Open QA items still to test / fix

- **Joiner onboarding flow:** User to test with deep link `circles://join/Z5QZTNN5` (Isha at Masjid, brothers). Note: for an already-onboarded user, the `JoinFromLinkView` sheet now surfaces. For testing the full joiner **onboarding** flow (MemberOnboardingCoordinator), user must be on a fresh account that hasn't completed onboarding.
- **Circle Moment:** `daily_moments` row exists for today (dhuhr). DailyMomentService now opens gate for accounts with no location (fallback = start of day). User needs to reload/relaunch app to pick up the new row.
- **Member onboarding flow** — not fully tested yet by user
- **Generate 28-day plan** — user confirmed it's working ✓ after constraint fix

## Swift / Xcode 26 note

**`Color.msToken` must be explicit** — Xcode 26 / Swift 6 does NOT infer `Color` from shorthand dot syntax (`.msGold`). Always use `Color.msGold`, `Color.msTextPrimary`, etc.

## Deep link format

Custom URL scheme (not universal links): `circles://join/INVITECODE`
Example: `circles://join/Z5QZTNN5`
Paste in Safari address bar or Notes and tap to open app.

## Invite codes (for testing)

| Circle | Invite Code | Type |
|--------|-------------|------|
| Isha at Masjid (Abdulsaboor's) | `Z5QZTNN5` | Brothers |
| Fair | `JMY7P3UE` | Brothers |

## Secrets (local only)

`Circles/Secrets.plist`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`.

## Git

`main` → `origin` (GitHub: AbdulsaboorS/circles-ios)
