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

## Phase 1: Auth + Core Navigation Shell

**Goal:** Running app with sign-in, sign-up (Google + Apple), and a tab bar shell. No real content yet.

**Requirements**: [PHASE1-AUTH-APPLE, PHASE1-AUTH-GOOGLE, PHASE1-AUTH-PERSIST, PHASE1-NAV-SHELL, PHASE1-EMPTY-STATES, PHASE1-SUPABASE-CONFIG]

- Sign in with Apple (required by Apple) [PHASE1-AUTH-APPLE]
- Google OAuth via Supabase [PHASE1-AUTH-GOOGLE]
- Auth state persists across app launches [PHASE1-AUTH-PERSIST]
- Tab bar: Home / Community / Profile [PHASE1-NAV-SHELL]
- Empty state screens for each tab [PHASE1-EMPTY-STATES]
- Supabase client configured (env vars via Secrets.plist) [PHASE1-SUPABASE-CONFIG]

**Status:** In planning

**Plans:** 1 plan

Plans:
- [ ] 01-PLAN.md — Supabase config, AuthManager, Apple+Google sign-in, tab shell, empty states

---

## Phase 2: Habits + Daily Check-in

**Goal:** User can manage their habits and check in daily.

**Requirements**: [PHASE2-ONBOARDING, PHASE2-AI-SUGGESTIONS, PHASE2-DAILY-CHECKIN, PHASE2-STREAKS, PHASE2-HABIT-DETAIL]

- Onboarding: select 2-5 habits from preset list (salah, Quran, dhikr, fasting, custom) [PHASE2-ONBOARDING]
- AI step-down suggestions via Gemini 2.0 Flash REST API [PHASE2-AI-SUGGESTIONS]
- Daily check-in screen: list of today's habits, tap to complete [PHASE2-DAILY-CHECKIN]
- Streak tracking: current streak, longest streak, grace days [PHASE2-STREAKS]
- Habit detail: 28-day plan, history calendar [PHASE2-HABIT-DETAIL]

**Status:** Complete (3/3 plans built and verified in Simulator)

**Plans:** 3 plans

Plans:
- [x] 02-01-PLAN.md — Codable models (Habit, HabitLog, Streak), HabitService singleton, GeminiService singleton
- [x] 02-02-PLAN.md — Onboarding flow (HabitSelectionView, RamadanAmountView, AIStepDownView, ContentView routing)
- [x] 02-03-PLAN.md — HomeView daily check-in, HomeViewModel optimistic toggling, HabitDetailView 28-day calendar

---

## Phase 3: Circles (Create, Join, Member View)

**Goal:** User can create a circle, invite friends, and see who's in it.

**Requirements**: [PHASE3-CREATE-CIRCLE, PHASE3-INVITE-LINK, PHASE3-JOIN-CIRCLE, PHASE3-CIRCLES-TAB, PHASE3-CIRCLE-DETAIL, PHASE3-DB-SCHEMA]

- Create circle: name, description, pick prayer time for Circle Moment [PHASE3-CREATE-CIRCLE]
- Invite link generation (deep link: `circles://join/[code]` or HTTPS universal link) [PHASE3-INVITE-LINK]
- Join via invite link → lands in circle after auth [PHASE3-JOIN-CIRCLE]
- My Circles tab: list of joined circles, member count, X/Y checked in today [PHASE3-CIRCLES-TAB]
- Circle detail: member board, habit check-in status (name + ✓/✗, no detail) [PHASE3-CIRCLE-DETAIL]
- Supabase tables: reuse `halaqas` + `halaqa_members` from Legacy schema [PHASE3-DB-SCHEMA]

**Status:** In planning

**Plans:** 3 plans

Plans:
- [ ] 03-01-PLAN.md — Circle + HalaqaMember models, CircleService singleton (data layer)
- [ ] 03-02-PLAN.md — CirclesView (My Circles list), CreateCircleView, JoinCircleView, CircleDetailView (UI layer)
- [ ] 03-03-PLAN.md — Deep link handling (circles://join/CODE), tab selection wiring, human verification

---

## Phase 4: Circle Moment (Camera, Post, Reciprocity Gate)

**Goal:** The core BeReal-style mechanic. User gets notified at circle's prayer time, opens camera, posts a Moment.

**Requirements**: [PHASE4-MOMENT-NOTIFICATION, PHASE4-CAMERA, PHASE4-ACTIVE-WINDOW, PHASE4-POST-MOMENT, PHASE4-RECIPROCITY-GATE, PHASE4-ON-TIME-INDICATOR, PHASE4-STORAGE]

- Circle Moment notification at prayer time (APNs) [PHASE4-MOMENT-NOTIFICATION]
- Camera view: front + back capture (or single camera MVP) [PHASE4-CAMERA]
- 30-minute active window: countdown shown in Circle detail [PHASE4-ACTIVE-WINDOW]
- Post with optional caption [PHASE4-POST-MOMENT]
- Reciprocity gate: blur/lock peer Moments until you post yours today [PHASE4-RECIPROCITY-GATE]
- On-time indicator: ⭐ if posted within window [PHASE4-ON-TIME-INDICATOR]
- Supabase Storage: upload photo to `circle-moments` bucket [PHASE4-STORAGE]

**Status:** Not started

---

## Phase 5: Unified Circle Feed

**Goal:** Single scroll view showing all activity in a circle.

**Requirements**: [PHASE5-FEED-ITEMS, PHASE5-REACTIONS, PHASE5-PAGINATION, PHASE5-RECIPROCITY-LOCK, PHASE5-OPTIMISTIC-REACTIONS]

- Feed items: Circle Moments (photo + caption + on-time star), habit check-ins, streak milestones [PHASE5-FEED-ITEMS]
- Reactions on each item (6 reactions: ❤️ 🤲 💪 🌟 🫶 ✨) [PHASE5-REACTIONS]
- Reverse-chronological, paginated [PHASE5-PAGINATION]
- Today's Moment is locked behind reciprocity gate until posted [PHASE5-RECIPROCITY-LOCK]
- Optimistic reaction updates [PHASE5-OPTIMISTIC-REACTIONS]

**Status:** Not started

---

## Phase 6: Push Notifications

**Goal:** Users get notified when their Circle Moment window opens and when circle members are active.

**Requirements**: [PHASE6-APNS-TOKEN, PHASE6-PRAYER-TIME-NOTIFICATION, PHASE6-PRAYER-TIME-CALC, PHASE6-MEMBER-NOTIFICATIONS, PHASE6-STREAK-NOTIFICATIONS, PHASE6-PERMISSION-PROMPT]

- APNs token registration on first launch [PHASE6-APNS-TOKEN]
- Daily prayer-time notification per circle (based on circle's chosen prayer + user's location) [PHASE6-PRAYER-TIME-NOTIFICATION]
- Prayer time calculation: use Adhan Swift library or a prayer time API [PHASE6-PRAYER-TIME-CALC]
- Notification: Circle Moment window open [PHASE6-MEMBER-NOTIFICATIONS]
- Notification: member posted Moment (after you've posted) [PHASE6-MEMBER-NOTIFICATIONS]
- Notification: streak milestone reached [PHASE6-STREAK-NOTIFICATIONS]
- Notification permission prompt after first circle join [PHASE6-PERMISSION-PROMPT]

**Status:** Not started

---

## Phase 7: App Store Polish + Submission

**Goal:** App is production-ready and passes Apple review.

**Requirements**: [PHASE7-APP-ICON, PHASE7-LAUNCH-SCREEN, PHASE7-STORE-ASSETS, PHASE7-PRIVACY-POLICY, PHASE7-STORE-LISTING, PHASE7-SIWAP-EDGE-CASES, PHASE7-NO-PLACEHOLDERS, PHASE7-TESTFLIGHT, PHASE7-SUBMIT]

- App icon (all required sizes) [PHASE7-APP-ICON]
- Launch screen [PHASE7-LAUNCH-SCREEN]
- Onboarding screenshots for App Store listing [PHASE7-STORE-ASSETS]
- Privacy policy URL [PHASE7-PRIVACY-POLICY]
- App Store description, keywords, category [PHASE7-STORE-LISTING]
- Sign in with Apple edge cases handled [PHASE7-SIWAP-EDGE-CASES]
- No placeholder content anywhere [PHASE7-NO-PLACEHOLDERS]
- TestFlight beta: send to 5-10 real users for 48hr test [PHASE7-TESTFLIGHT]
- Submit for App Store review [PHASE7-SUBMIT]

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
