---
version: 2.4
last_updated: "2026-04-02"
current_phase: "Phase 11.3 — Onboarding In Depth"
status: "Ready To Start"
---

# Circles iOS — State (v2.4)

## Current Focus

**Phase 11.3 — Onboarding In Depth** — Phase 11.2 QA/polish is closed. Next session should begin the onboarding rebuild using the plans in `.planning/phases/11.3-onboarding-in-depth/`.

**Handoff:** [`.planning/HANDOFF.md`](HANDOFF.md) for the next agent.

---

## What's Built — v2.3 Phases

### Phase 1 — Schema + Model Foundations ✓
- DB: `habits` (is_accountable, circle_id), `circles` (gender_setting, group_streak_days, core_habits), `profiles` (avatar_url)
- New tables: `comments`, `habit_plans`, `daily_moments`
- Swift models: `Circle`, `Habit`, `HabitLog` updated; `Comment`, `HabitPlan`, `DailyMoment`, `Profile` created

### Phase 2 — Navigation Restructure ✓
- App entry → Circles tab (tag 1)
- Tab label "Community" → "Circles"
- Home tab = Daily Intentions only (no social feed)

### Phase 3 — Profile Photos ✓
- `AvatarView` component (AsyncImage + initials fallback, configurable size)
- `AvatarService`: upload to `avatars` Storage bucket, save URL to profiles, fetch profiles + impact stats
- `ProfileView`: full redesign — PHPicker avatar picker, name, member-since, stats AppCard (Total Days / Best Streak / Circles), settings
- `CircleDetailView` member strip: uses AvatarView, loads member profiles, role = "Amir"

### Phase 4 — Dual-Track Habits ✓
- `HabitService.createAccountableHabit` (is_accountable=true, circle_id linked)
- `HabitService.broadcastHabitCompletion` → inserts into `activity_feed`
- `HomeViewModel.toggleHabit` broadcasts accountable completions (fire-and-forget)
- `HomeView`: "Shared Intentions" + "Personal Intentions" sections with descriptive sub-labels

### Phase 5 — Circle Core Habits + Gender Locking ✓
- `CircleService.createCircleForAmir` (genderSetting + coreHabits JSONB)
- `CircleService.fetchCircleByCode` for preview + join
- `CreateCircleView`: design system + Brothers/Sisters/Mixed picker
- `JoinCircleView`: design system + gender check + confirmation alert on mismatch
- `MyCirclesView`: group streak flame displayed on cards

### Phase 6 — Amir Onboarding Overhaul ✓
- `AmiirOnboardingCoordinator`: 4-step state machine, Soul Gate hard lock
- Steps: Circle Identity → Core Habits (max 3, curated list) → Location → Soul Gate
- Soul Gate: `ShareSheet` UIActivityViewController bridge; "Begin My Journey" disabled until share initiated
- On onboarding completion: background `HabitPlanService.ensureAIRoadmapForOnboarding` per habit created in session (fire-and-forget; details Phase 11)
- `StepIndicator` component (animated pill progress)
- `ContentView`: routes new users to Amir flow; Amir lands on Home tab

### Phase 7 — Member/Joiner Flow + Rich Circle Preview ✓
- `CirclePreviewView`: unauthenticated landing — circle name, core habits, group streak, inline Sign in with Apple/Google
- `MemberOnboardingCoordinator`: join circle + create accountable habits + save location
- Steps: Habit Alignment (must pick ≥ 1 core habit) → Location → joins circle on city select
- `ContentView`: anon + invite code → preview; new user + invite code (post-auth) → member flow

### Phase 8 — Prayer of the Day + Reciprocity Gate v2 ✓
- `DailyMomentService`: fetches today's prayer from `daily_moments`, calls Aladhan API for exact prayer time, checks if user posted today across all circles
- Gate activates when window OPENS (not after it closes)
- `ReciprocityGateView`: frosted blur overlay with "Unlock Your Circles" CTA
- `CommunityView`: global feed wrapped in gate, camera opens for first circle
- `CircleDetailView`: feed section wrapped in gate
- `MomentFeedCard`: "Posted at [Prayer]" badge for on-time, "Posted late" for late
- `FeedItem`: Equatable conformance + `circleId` / `postType` computed properties

### Phase 9 — Comment Drawer ✓
- `CommentService`: fetchComments, addComment, deleteComment (RLS: circle members only)
- `CommentDrawerView`: slide-up `.medium/.large` sheet — avatars, comment list, text input, send, delete own, empty state
- `MomentFeedCard`, `HabitCheckinRow`, `StreakMilestoneCard`: comment bubble icon added
- `FeedView`: manages `commentingOnItem` state, presents `CommentDrawerView` as sheet

### Phase 10 — Group Streak + Face Piles + Amir settings ✓
- DB (Supabase): UTC group streak trigger + `group_streak_last_complete_utc_date` (applied in your project; no SQL files in repo)
- `CircleService`: `fetchCircle`, `updateCircleSettings`, `removeMember`
- After a Moment post: `CircleDetailView` refetches circle; `CommunityView` calls `loadCircles` so My Circles streak updates
- `FeedViewModel` + `ReactionBar`: batch reactor profiles, overlapping face pile (max 5 + “+N”)
- `AmirCircleSettingsView`: Amir gear on circle detail — edit core habits (≤3), gender; remove members
- `CircleDetailView` member strip cap 14 + overflow badge; `MembersListView` avatars + Amir label

### Phase 11.1 — Midnight Sanctuary UI Pass ✓ (All groups complete)

**Design system:** Deep forest green bg `#1A2E1E`, gold `#D4A240`, cream `#F0EAD6`, sage `#8FAF94`, cards `#243828`/`#1E3122`. Tokens scoped `private extension Color` per file (global DesignTokens.swift consolidation deferred until all screens done).

**All commits (on `main`):**
- `4dfdc18` — HomeView full redesign + HabitDetailView icon fix (`Text(habit.icon)` → `Image(systemName:)`)
- `82f2656` — Auth + Amir Onboarding (4 steps) + Member Onboarding (2 steps)
- `b487333` — Community/Feed group: CommunityView, MyCirclesView, FeedView, all feed cards, ReactionBar, ReciprocityGateView; email/password test login added to AuthView
- `1d0dfbd` — Groups 3 & 4: CircleDetailView, CreateCircleView, JoinCircleView, MomentCameraView, MomentPreviewView, ProfileView, HabitDetailView (full MS pass)

**Implementation note:** Xcode 26 / Swift 6 requires explicit `Color.msToken` prefix — shorthand dot syntax (`.msGold`) fails to infer `Color` when the expected type is `ShapeStyle`.

**Phase 11.1 complete.** Next: Phase 11.2 — E2E QA + Bug Fixes.

### Phase 11.2 — E2E QA + Bug Fixes ✓
- `HabitDetailView`: Reflection Log landed and AI roadmap loading now shows animated progress treatment during generate/refine.
- Moment flow:
  - first-shot white-screen bug fixed by moving preview presentation to a single draft item state
  - stale-preview bug fixed by capture-generation tracking in `CameraManager`
  - shutter now waits for `isSessionReady`
  - debug camera shortcuts removed after QA
- Feed polish:
  - shared author header with avatar + name + circle + timestamp
  - habit check-in copy now uses the requested `checking into 'habit'` line
  - feed author avatars now come from a dedicated author-profile cache in `FeedViewModel`
- Invite preview polish:
  - retained test-account login path
  - improved member preview with face pile + avatar-backed member rows
- Deferred out of 11.2:
  - Moment posting should be re-tested only during a real live prayer window
  - Moment compositing/output polish can happen after real posting is verified
  - old member onboarding blocker is superseded by Phase 11.3 rebuild

**Per-screen implementation pattern:**
1. Add `private extension Color` with MS tokens at top of file
2. Replace `AppBackground()` → `Color(hex: "1A2E1E").ignoresSafeArea()`
3. Replace `Color.accent` → `msGold`, `colors.textPrimary` → `msTextPrimary`, `colors.textSecondary` → `msTextMuted`
4. Replace `AppCard { }` wrapper → inline `RoundedRectangle.fill(msCardShared)` with `msBorder` overlay
5. Replace `PrimaryButton` → inline gold Capsule button (msGold bg, msBackground text)
6. Build after each group — zero errors before commit

**Supabase action still needed:** Authentication → Settings → disable "Confirm email" so test accounts created via email/password work instantly.

### Phase 11 — AI Roadmap v2 ✓ (code complete; see Open issues for QA)
- DB: **Refine** — run `.planning/phases/11-ai-roadmap/migration.sql` (`refinement_cycle` + `apply_habit_plan_refinement`, 3 refinements per UTC ISO week)
- DB: **`habit_plans` shape** — if PostgREST errors on missing `milestones`, run `.planning/phases/01-schema-foundations/habit_plans_align_app.sql` (idempotent; ends with `NOTIFY pgrst, 'reload schema'`). Hosted Supabase has **no** Settings → API “reload schema” button.
- `GeminiService`: model `gemini-3-flash-preview`; dedicated `URLSession` **45s request / 60s resource** timeouts on AI calls
- `GeminiService.generate28DayRoadmap` — exactly 28 milestones JSON; optional user note for refine
- `HabitPlanService`: fetch/upsert initial plan, `applyRefinement` via RPC, `userFacingMessage(from:)` for schema-timeout copy; `ensureAIRoadmapForOnboarding` for Amir + Member flows
- `HabitPlan` + `HabitMilestone`: `refinementCycle`, calendar alignment helpers (`calendarDateString`, `isMilestoneToday`, `displayWeek`)
- `HabitDetailView`: **Generate 28-day plan**, week-grouped roadmap + **Today**, **Refine plan** sheet + limit copy
- `AmiirOnboardingCoordinator` / `MemberOnboardingCoordinator`: background plans for habits created at onboarding

---

## What's Built — v1 Foundation (carried into v2.3)

### Auth
- Sign in with Apple + Google OAuth via Supabase
- `AuthManager` (@Observable @MainActor) with session persistence

### Design System
- `DesignTokens.swift`: color + font tokens, semantic aliases, AppColors resolver
- `ThemeManager.shared`: ThemeMode (auto/light/dark), NOAA solar auto-switch
- `AppBackground.swift`: dual animated blob background
- `Components.swift`: AppCard, PrimaryButton, ChipButton, SectionHeader
- `AvatarView.swift`: reusable circular avatar component

### Habits
- `Habit`, `HabitLog`, `Streak`, `HabitPlan` models
- `HabitService`: fetchActiveHabits, toggleHabitLog, updateLogNote, updatePlanNotes, createAccountableHabit, broadcastHabitCompletion
- `HabitPlanService`: fetchPlan, upsertInitialPlan, applyRefinement (RPC), ensureAIRoadmapForOnboarding
- `GeminiService`: fetchSuggestion, generate28DayRoadmap
- `HomeViewModel` + `HomeView` + `HabitDetailView` (roadmap + refine)

### Circles
- `Circle`, `CircleMember` models (with genderSetting, coreHabits, groupStreakDays)
- `CircleService`: fetchMyCircles, fetchCircle, createCircle, createCircleForAmir, joinByInviteCode, fetchCircleByCode, fetchMembers, updateCircleSettings, removeMember
- `CirclesViewModel`: loadCircles, createCircle, joinCircle
- `CommunityView`: Feed|Circles swipeable TabView
- `MyCirclesView`: organic card layout (featured + stacked), group streak, CTAs
- `CreateCircleView`, `JoinCircleView` (gender enforcement)
- `CircleDetailView`: member board (AvatarView), Amir settings sheet, feed, moment banner, nudge

### Circle Moment
- `CircleMoment` model
- `MomentService`: fetchTodayMoments, uploadPhoto, postMoment, computeIsOnTime
- `CameraManager`, `MomentCameraView`, `MomentPreviewView`, `MomentCardView`
- Reciprocity gate v2 via `DailyMomentService` (full-feed blur)

### Feed
- `FeedItem` enum (moment, habitCheckin, streakMilestone) — Identifiable, Sendable, Equatable
- `FeedService.fetchFeedPage(circleIds: [UUID], ...)` — multi-circle aware
- `FeedViewModel`: loadInitial, loadNextPage, refresh — all accept [UUID]
- `FeedView`: LazyVStack, pagination, comment drawer; `FeedViewModel` reaction face piles
- `MomentFeedCard`, `HabitCheckinRow`, `StreakMilestoneCard`, `ReactionBar`
- `ReciprocityGateView`, `CommentDrawerView`

### Onboarding (v2.3)
- `AmiirOnboardingCoordinator` + 4 step views (Circle Identity, Habits, Location, Soul Gate)
- `MemberOnboardingCoordinator` + 2 step views (Habit Alignment, Location)
- `CirclePreviewView` — unauthenticated invite landing
- `StepIndicator`, `ShareSheet`

### Push Notifications
- `NotificationService`: APNs permission, device token management
- Edge Functions: moment-window cron, member-posted trigger, streak-milestone, peer nudge

### Profile
- `ProfileView`: avatar picker (PHPicker), stats, settings, sign out
- `AvatarService`: upload, fetch profiles, fetch stats

### Services
- `DailyMomentService`: prayer of day + Aladhan API + gate state
- `CommentService`: CRUD on `comments` table

---

## Active Technical Decisions

- `@Observable @MainActor` pattern throughout (Swift 6)
- Service singletons via `@Observable` (not ObservableObject)
- `DATE` columns stored as String in Swift models
- `import Supabase` required in every file accessing `auth.session?.user.id`
- `SwiftUI.Circle()` qualified to avoid naming conflict with `Circle` model
- `circles` + `circle_members` custom tables (RLS via `auth_user_circle_ids()` SECURITY DEFINER)
- `FeedService.fetchFeedPage(circleIds: [UUID])` — multi-circle unified feed
- `FeedViewModel` accepts `[UUID]` throughout; single-circle calls pass `[circle.id]`
- `AvatarService` used for profile fetch + stats (not a separate ProfileService)
- `DailyMomentService.shared` is a singleton read by CommunityView + CircleDetailView
- Aladhan API method=3 (MWL) matches Edge Function prayer time calculations
- `ShareSheet` is a `UIViewControllerRepresentable` wrapper for `UIActivityViewController`
- Soul Gate hard lock: `hasSharedInvite = true` set when share button tapped (share sheet opened)
- One commit per build session (phase group) — not per individual file change
- Git: `main` branch, remote `origin` = GitHub (AbdulsaboorS/circles-ios)

---

## Phase History

| Phase | Status | Summary |
|-------|--------|---------|
| 1 — Schema + Models | ✓ Complete | DB migrations + all Swift models updated/created |
| 2 — Navigation | ✓ Complete | App entry → Circles tab, Home = Daily Intentions |
| 3 — Profile Photos | ✓ Complete | AvatarService, AvatarView, ProfileView redesign |
| 4 — Dual-Track Habits | ✓ Complete | is_accountable, broadcastHabitCompletion, HomeView sections |
| 5 — Core Habits + Gender | ✓ Complete | createCircleForAmir, gender enforcement, streak on cards |
| 6 — Amir Onboarding | ✓ Complete | 4-step flow, Soul Gate hard lock, background AI |
| 7 — Member Flow + Preview | ✓ Complete | CirclePreviewView (anon), MemberOnboardingCoordinator |
| 8 — Prayer Gate v2 | ✓ Complete | DailyMomentService, Aladhan API, full-feed blur gate |
| 9 — Comment Drawer | ✓ Complete | CommentService, CommentDrawerView, comment buttons on all cards |
| 10 — Group Streak + Face Piles | ✓ Complete | UTC trigger SQL, refetch after moment, face piles, Amir settings |
| 11 — AI Roadmap v2 | ✓ Complete | Gemini 3 Flash preview 28-day plan, HabitDetail UI, RPC refinement cap, onboarding hooks |
| 11.1 — Full UI Vision Pass | ✓ Complete | Full Midnight Sanctuary redesign — all screens |
| 11.2 — E2E QA + Bug Fixes | ✓ Complete | QA fixes landed: reflection log, roadmap loading feedback, moment camera fixes, feed/PFP polish, invite preview polish |
| 11.3 — Onboarding In Depth | 🔄 Next | Finalized onboarding flows (Amir + Joiner), animations, deep links, data persistence |
| 12 — Polish + App Store | ⬜ Planned | Muslim-native copy audit, App Store submission |
| 13 — Landing Page Web | ⬜ Planned | Marketing landing page (HTML/Tailwind, design system applied) |

---

## Open issues & QA (handoff)

*Last triage: 2026-04-02 — Phase 11.2 close-out.*

### A. Generate 28-day plan — `NSURLErrorDomain error -1011`

- **Meaning:** `NSURLErrorBadServerResponse` — the Gemini REST call returned **HTTP status other than 200**. `GeminiService` maps any non-200 to `URLError(.badServerResponse)` (see `GeminiService.swift`).
- **Common causes:** API key invalid/expired, quota/billing, model id unavailable in the project/region, or Google returning 4xx/5xx with a body the app does not surface today.
- **Next steps for debugging:** Log `http.statusCode` + response **body** (JSON error from Google) in `generate28DayRoadmap` / `fetchSuggestion`; confirm `GEMINI_API_KEY` and that `gemini-3-flash-preview` is enabled in [Google AI Studio](https://aistudio.google.com/) for the key’s project.

### B. `habit_plans` / PostgREST “milestones” / schema cache

- **Resolved on DB side** by running `habit_plans_align_app.sql` when the table was missing columns.
- If the error returns: re-run that script (idempotent) or execute alone: `NOTIFY pgrst, 'reload schema';`

### C. Habit detail UI (deferred — Phase 12)

- **Hero “icon”:** `HabitDetailView` uses `Text(habit.icon)`, but `habit.icon` stores **SF Symbol names** (e.g. `moon.stars.fill`). Onboarding/home use `Image(systemName:)`. Detail shows raw names → looks broken.
- **Contrast:** Multiple `Color.textSecondary` usages on light cards — static token is **dark-mode** (white @ opacity); should use `AppColors.resolve(colorScheme).textSecondary` for adaptive text.

### D. Error copy

- Schema-related failures get friendly text via `HabitPlanService.userFacingMessage(from:)`. Raw `localizedDescription` still appears for some URLErrors (-1011).

### E. Moment posting / compositing follow-up

- Camera-state bugs were fixed in Phase 11.2, but real posting should be verified during an actual prayer window instead of a forced debug-style path.
- If posting succeeds in the real window, evaluate whether the composited image still needs visual polish.

---

## Blockers

None for **starting Phase 11.3 planning/implementation work**; **AI generate path** may still be blocked by **Gemini API/key/model** until -1011 is diagnosed (see A above).

---

*v2.3 pivot: 2026-03-26. Phases 1–11 code complete. Phase 12 in progress (polish, App Store, open QA above).*
