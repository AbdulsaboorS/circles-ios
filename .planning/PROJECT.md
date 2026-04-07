# Circles — Product Vision & Requirements (v2.3)

**Date:** 2026-03-26 (vision); **execution status:** 2026-04-07 — Phase 12 complete, Phase 13 active (see `STATE.md` / `HANDOFF.md` for current iteration state).
**Status:** Finalized for Execution (Private MVP)

---

## Vision

The Islamic social accountability app for Muslims ages 15-35. The "Islamic BeReal" for your closest circle.

**One-sentence pitch:** A private accountability space where your circle keeps each other consistent on daily habits through a shared daily moment anchored to prayer.

---

## Foundational Principles (Non-Negotiables)

1. **Privacy over Virality** — There is no "Public" mode. If it isn't in a circle, it doesn't exist for other users.
2. **Connection over Competition** — No leaderboards, no like counts. We celebrate presence, not performance.
3. **Muslim-Native UX** — Every notification, label, and interaction should feel like it was built by a Muslim, for a Muslim.
4. **Low-Friction Accountability** — Habit logging takes less than 3 seconds. The AI handles planning; the user handles the doing.

**Anti-patterns:** No leaderboards, no public profiles, no follower counts, no shaming mechanics.

---

## Core Mechanics

### A. The Circle Moment (The Heartbeat)
- System-controlled daily trigger: server picks one prayer globally as the "Moment of the Day" (e.g., Asr)
- Push notification fires relative to each user's **local** prayer time (rolling wave effect via Aladhan API)
- 30-minute capture window: photo + optional caption (max 100 chars)
- **Reciprocity Gate**: Gate activates the moment the window OPENS. Feed (Global + per-Circle) is blurred until user posts. No exceptions.
- On-time indicator: "Posted at Asr" badge if posted within window
- Late posts: allowed, tagged "Posted late" — no streak penalty, no shame
- One post = unlocks feed across ALL circles simultaneously
- Text-only fallback if camera unavailable (stored as `circle_moments` row with null `photo_url`)

### B. Dual-Track Habit System
- **Accountable Habits**: Linked to a specific circle. Completions broadcast to that circle's feed only. A habit can be accountable in multiple circles independently.
- **Personal Habits**: Private-only. Never broadcast. No one else sees these.
- Users can convert a Personal habit → Accountable at any time
- AI generates a 28-day roadmap per habit (Gemini 3 Flash preview): manual **Generate** on habit detail plus background jobs after onboarding completion
- Refinement guardrail: 3 AI refinements per habit per **UTC ISO week** (`refinement_cycle` + `apply_habit_plan_refinement` RPC)

### C. Circle Core Habits
- Amir selects 2-3 "Core Habits" that define the circle's mission
- Members must pick at least 1 core habit to join
- Core habits displayed on circle card and detail view

### D. The "Amir" (Leader) Flow — under 60 seconds
1. **Circle Identity**: Name + gender setting (Brothers / Sisters / Mixed)
2. **Core Mission**: Select 2-3 habits from curated Islamic list
3. **Prayer Sync**: Location (Aladhan-based prayer time)
4. **Soul Gate** (hard lock): Must trigger native share sheet before onboarding completes. After completion, background jobs enqueue 28-day plans for habits created in-session (`HabitPlanService`).
5. **Landing**: Home tab — Daily Intentions

### E. The "Member" (Joiner) Flow
1. **Rich Circle Preview**: Unauthenticated. Shows circle name, member count, group streak. Zero personal data.
2. **Sign-In**: Google / Apple
3. **Habit Alignment**: "Ahmad is tracking Fajr and Quran. Which will you do?" Must select ≥ 1.
4. **Prayer Sync**: Location
5. **Landing**: Global Feed (Circles tab)

### F. Navigation Structure
- **App entry**: Circles tab (Global Feed) — maximizes social activation
- **Circles tab**: Two sub-views
  - View 1: Global Feed — unified chronological feed from all circles (photo moments + habit check-ins + milestones). Reciprocity gated.
  - View 2: My Circles — scrollable list of Circle Cards (name, member avatars, group streak flame)
- **Home tab**: Daily Intentions only — personal habit check-ins, no social feed
- **Profile tab**: Identity (photo, name, member since), impact stats (total days, best streak, circle count), habit badges grid, settings

### G. Comment Drawer (MVP)
- Tapping any feed item opens a slide-up comment drawer
- Comments are circle-specific and entirely private to that group
- Push notifications for new comments
- No global moderation (trusted circles self-moderate)

### H. Social Interactions
- **Reactions**: 6 curated non-competitive icons (👍 ❤️ 🔥 🙌 🤲 💡). No counts — show face pile of who reacted.
- **Nudge**: Tap nudge icon next to a member who hasn't posted → friendly push notification: "Humza is waiting for your moment!"
- **Group Streak**: Displayed on circle cards. Increments when all members post their moment on the same day.

### I. Profile & Identity
- Profile photo (MVP) — powers face piles, member boards, reaction identity
- PHPicker → Supabase Storage (avatars bucket) → `profiles.avatar_url`
- Impact stats: Total Days, Best Streak, Circle Count
- Habit badges grid with individual streak per habit
- Settings: name, location, notification preferences, sign out

### J. Muslim-Native Copy Guidelines
- "Daily Intentions" not "Tasks"
- "Posted late" not "Failed" or "Missed"
- "No worries, consistency is a journey. Try again for Isha?" not "You missed your goal."
- Notifications: spiritual, supportive tone throughout

---

## Technical Architecture

### Stack
- **Language / UI**: Swift 6, SwiftUI
- **Backend**: Supabase (shared with Legacy web)
- **AI**: Gemini 3 Flash (preview) REST API
- **Auth**: Supabase (Google OAuth + Sign in with Apple)
- **Push**: APNs via Supabase Edge Functions
- **Storage**: Supabase Storage (circle-moments bucket, avatars bucket)
- **Prayer Times**: Aladhan API (replaces NOAA solar calculator for prayer-specific logic)
- **Bundle ID**: `app.joinlegacy` | **Xcode**: 26.3 | **iOS target**: 17.0+

### Security (RLS)
- Users can only read/write `circle_moments` and `habit_logs` if they have an active membership in the relevant `circle_id`
- Gender-lock enforcement: if circle `gender_setting = 'sisters'`, invite link shows "Sisters-only circle" confirmation before join is allowed
- Rich Circle Preview: RLS relaxed only for `circles.name`, `circles.member_count`, `circles.group_streak_days` for unauthenticated reads. Zero personal data exposed.

### Database Schema (v2.3)

**Modified tables:**
- `habits` → add `is_accountable BOOLEAN DEFAULT false`, `circle_id UUID REFERENCES circles(id)`
- `circles` → add `gender_setting TEXT DEFAULT 'mixed'`, `group_streak_days INT DEFAULT 0`, `core_habits JSONB`
- `profiles` → add `avatar_url TEXT`

**New tables:**
- `comments` — id, post_id, post_type, circle_id, user_id, text, created_at
- `habit_plans` — id, habit_id, user_id, milestones JSONB, week_number INT, refinement_count INT, refinement_week INT, **refinement_cycle** TEXT (UTC ISO week key), created_at, updated_at; RPC **`apply_habit_plan_refinement`** for capped refinements
- `daily_moments` — id, prayer_name TEXT, date DATE UNIQUE (server picks one prayer per day)

---

## What's Out of Scope (v2.3 MVP)
- Real-time chat / DMs
- Public profiles or discovery
- Leaderboards or rankings
- Payments / subscriptions
- Web version
- Android
- Circle Moment video

---

*Last updated: 2026-04-07 — v2.3; Phase 12 cleanup complete, Phase 13 interactive UI/UX pass active. Operational QA is tracked in `STATE.md`.*
