# Circles iOS — Roadmap

## Milestone 1: MVP → App Store Submission

**Goal:** A working, submittable iOS app with the core Circle Moment mechanic, habit tracking, and social feed. Real users can create circles, invite friends, track habits, and post daily Moments.

**Success criteria:**
- User can sign in, onboard, and join/create a circle
- User can check in daily habits and see streaks
- Circle Moment posts and reciprocity gate work end-to-end
- Circle feed shows Moments + habit check-ins
- Push notifications fire at selected prayer time
- App passes App Store review

---

## Phase 1 — Auth + Core Navigation Shell

**Goal:** Running app with sign-in, sign-up (Google + Apple), and a tab bar shell. No real content yet.

**Requirements:**
- Sign in with Apple (required by Apple)
- Google OAuth via Supabase
- Auth state persists across app launches
- Tab bar: Home / Circles / Profile
- Empty state screens for each tab
- Supabase client configured (env vars via Secrets.plist)

**Status:** Not started

---

## Phase 2 — Habits + Daily Check-in

**Goal:** User can manage their habits and check in daily.

**Requirements:**
- Onboarding: select 2-5 habits from preset list (salah, Quran, dhikr, fasting, custom)
- AI step-down suggestions via Gemini (call Legacy API endpoint or implement directly)
- Daily check-in screen: list of today's habits, tap to complete
- Streak tracking: current streak, longest streak, grace days
- Habit detail: 28-day plan, history calendar

**Status:** Not started

---

## Phase 3 — Circles (Create, Join, Member View)

**Goal:** User can create a circle, invite friends, and see who's in it.

**Requirements:**
- Create circle: name, description, pick prayer time for Circle Moment
- Invite link generation (deep link: `circles://join/[code]` or HTTPS universal link)
- Join via invite link → lands in circle after auth
- My Circles tab: list of joined circles, member count, X/Y checked in today
- Circle detail: member board, habit check-in status (name + ✓/✗, no detail)
- Supabase tables: reuse `halaqas` + `halaqa_members` from Legacy schema

**Status:** Not started

---

## Phase 4 — Circle Moment (Camera, Post, Reciprocity Gate)

**Goal:** The core BeReal-style mechanic. User gets notified at circle's prayer time, opens camera, posts a Moment.

**Requirements:**
- Circle Moment notification at prayer time (APNs)
- Camera view: front + back capture (or single camera MVP)
- 30-minute active window: countdown shown in Circle detail
- Post with optional caption
- Reciprocity gate: blur/lock peer Moments until you post yours today
- On-time indicator: ⭐ if posted within window
- Late post: allowed, no star
- Supabase Storage: upload photo to `circle-moments` bucket
- New table: `circle_moments` (circle_id, user_id, photo_url, caption, posted_at, is_on_time)

**Status:** Not started

---

## Phase 5 — Unified Circle Feed

**Goal:** Single scroll view showing all activity in a circle.

**Requirements:**
- Feed items: Circle Moments (photo + caption + on-time star), habit check-ins (user logged X habit), streak milestones (user hit 7/14/30 day streak)
- Reactions on each item (6 reactions: ❤️ 🤲 💪 🌟 🫶 ✨)
- Reverse-chronological, paginated
- Today's Moment is locked behind reciprocity gate until posted
- Optimistic reaction updates

**Status:** Not started

---

## Phase 6 — Push Notifications

**Goal:** Users get notified when their Circle Moment window opens and when circle members are active.

**Requirements:**
- APNs token registration on first launch
- Daily prayer-time notification per circle (based on circle's chosen prayer + user's location)
- Prayer time calculation: use Adhan Swift library or a prayer time API
- Notification types:
  - Circle Moment window open: "Your Asr Moment is starting — post now to see your circle"
  - Member posted Moment (after you've posted): "Aisha posted her Moment"
  - Streak milestone reached: "You hit a 7-day streak for Quran! 🎉"
- Notification permission prompt timed well (after user has seen value — after first circle join)

**Status:** Not started

---

## Phase 7 — App Store Polish + Submission

**Goal:** App is production-ready and passes Apple review.

**Requirements:**
- App icon (all required sizes)
- Launch screen
- Onboarding screenshots for App Store listing
- Privacy policy URL
- App Store description, keywords, category
- Sign in with Apple edge cases handled
- No placeholder content anywhere
- TestFlight beta: send to 5-10 real users for 48hr test
- Submit for App Store review

**Status:** Not started

---

## v1.1 (Post-Launch, Parallel with Review)

- Circle Moment comments
- Group circle setup for MSA chapters / masjid youth groups
- Streak sharing card (native share sheet)
- Expanded prayer time options (per-user, not just per-circle)
- Android (React Native or Flutter wrapper — TBD)

---
*Last updated: 2026-03-23*
