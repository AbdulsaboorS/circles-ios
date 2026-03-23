# Circles — Islamic Social Accountability App

## Product Vision

Circles is a native iOS app for Muslim Gen Z and millennials that gives existing Islamic accountability groups (halaqas, MSA chapters, friend groups) a dedicated digital home. The core mechanic: a small circle of trusted people, a daily habit layer, and a "Circle Moment" — a BeReal-style daily check-in anchored to a chosen prayer time.

**Core insight:** Muslims already structure their days around salah. The prayer-time anchor gives a daily social check-in ritual a pre-existing behavioral hook no secular app can replicate.

## App Name

**Circles** — subtitle TBD for App Store (e.g., "Circles: Islamic Accountability"). Keeps "Circles" branding from Legacy web while differentiating from "Circles - Know Your People" (secular social app, App Store id6753855763) via subtitle and positioning.

Alternative if App Store rejects: **Halaqa** — the exact Arabic word for an Islamic accountability circle.

## Core Mechanics

### 1. Small Accountability Circles
- Max 10-12 members per circle (MVP)
- Private by default — invite-only
- Invite link is the primary onboarding entry point
- Multiple circles per user supported
- Circle name, description, chosen prayer time (Fajr / Dhuhr / Asr / Maghrib / Isha)

### 2. Daily Habit Tracking
- Each user tracks 2-5 personal habits
- Daily check-in with streak tracking + grace day system
- Habit types: salah, Quran, dhikr, fasting, tahajjud, sadaqah, custom
- AI-powered personalized 28-day "step-down" plan per habit (Gemini 2.0 Flash — reused from Legacy backend)
- Circle members see each other's check-in status (name + ✓/✗, not the habit detail)

### 3. Circle Moment (BeReal-style)
- Each circle picks one prayer time as their "Moment time"
- At that prayer time, all members get a push notification: "Your circle's Moment is starting"
- 30-minute window to post: a photo (front/back camera) + optional caption
- **Reciprocity gate:** you must post your Moment to see your circle's Moments today
- On-time indicator: ⭐ "Posted at Asr" shown if posted within the window
- Late posts still allowed — no shame, just no star
- Miss it entirely: no streak break, it's optional but sticky

### 4. Unified Circle Feed
- Single feed per circle, reverse-chronological
- Three item types: Circle Moments (photo posts), habit check-ins, streak milestones
- Reactions on each item (limited set: 5-7 Islamic-context reactions)
- No comments on Moments (MVP) — keeps feed clean

### 5. Invite-as-Onboarding
- Invite link is the first thing a new user sees
- Tapping an invite link → download prompt → sign up → land directly in the circle
- No cold-start discovery needed

## Target User

Muslim Gen Z and millennials (ages 15-35), primarily diaspora (US, UK, Canada, France, Germany). Existing accountability networks: MSA chapters, Ramadan halaqa groups, friend circles. High smartphone use, skeptical of preachy apps, want something authentically theirs.

## Backend

Supabase (reused from Legacy web app):
- Existing tables: `habits`, `habit_logs`, `shawwal_fasts`, `streaks`, `halaqas`, `halaqa_members`, `habit_reactions`, `activity_feed`
- New tables needed: `circle_moments`, `circle_moment_reactions`, prayer time per circle
- Supabase Storage: photo bucket for Circle Moments
- Auth: Google OAuth (existing) + Sign in with Apple (required for App Store)

## Tech Stack

- **Language / UI**: Swift 6, SwiftUI
- **Backend**: Supabase Swift SDK (via SPM)
- **AI**: Gemini 2.0 Flash via REST (reuse Legacy API endpoints or call directly)
- **Auth**: Supabase + Sign in with Apple
- **Push Notifications**: APNs via Supabase Edge Functions or direct APNs
- **Storage**: Supabase Storage (photos)
- **Deploy**: App Store (primary), TestFlight (beta)

## Apple Developer

- Account enrolled ($99/year)
- Bundle ID: `app.joinlegacy`
- Xcode 26.3

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Native Swift over Capacitor | App Store approval, performance, native camera/APNs access |
| Supabase reused from Legacy | Existing auth, tables, RLS carry over — no backend rebuild |
| Invite-as-onboarding | Eliminates cold start; trust is pre-existing from offline relationships |
| Reciprocity gate on Moments | Proven BeReal mechanic — post to see others; FOMO → action |
| Prayer-time anchor for Moment | Habit stacking on pre-existing Muslim daily structure — best behavioral trigger |
| No comment threads (MVP) | Keeps feed low-maintenance; reduces moderation surface |
| Sign in with Apple required | App Store guideline: required if Google OAuth offered |
| Max 10-12 per circle (MVP) | Maintains intimacy; halaqas traditionally 4-12 people |

## Differentiation vs. Competitors

- **vs. Pillars**: Pillars is a solo prayer utility. Circles is a social network built on salah timing.
- **vs. Muslamica**: Muslamica is broad Islamic social media. Circles is intimate, accountability-first.
- **vs. BeReal**: BeReal had random triggers. Circle Moment is anchored to prayer — deeper cultural meaning, better retention hook.
- **vs. HabitShare**: HabitShare is passive checkmarks. Circles has a visual shared moment.
- **vs. "Circles - Know Your People"**: That's a secular novelty app. Circles is an accountability tool for Muslims with an Islamic habit layer.

## What's Out of Scope (v1.0)

- Real-time chat / DMs
- Public profiles or discovery feed
- Leaderboards or rankings
- Payments / subscriptions
- Circle Moment comments (deferred to v1.1)
- Web version (Legacy web = marketing site only)
- Android

## Phases (MVP → Launch)

See ROADMAP.md for detailed phase breakdown.

**High-level:**
- Phase 1: Auth + Core Navigation Shell
- Phase 2: Habits + Daily Check-in
- Phase 3: Circles (create, join, member view)
- Phase 4: Circle Moment (camera, post, reciprocity gate)
- Phase 5: Unified Circle Feed
- Phase 6: Push Notifications
- Phase 7: App Store Polish + Submission

---
*Last updated: 2026-03-23*
