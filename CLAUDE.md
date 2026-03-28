# Circles iOS — Claude Code Instructions

## What This Is

A native Swift/SwiftUI iOS app — a private Islamic accountability tool ("Islamic BeReal"). Circle Moment (BeReal-style daily check-in anchored to prayer times) + habit tracking + small private circles.

See `.planning/PROJECT.md` for full product vision (v2.3 PRD). See `.planning/ROADMAP.md` for phase breakdown. See `.planning/STATE.md` for what's built and what's next.

## Tech Stack

- **Language**: Swift 6
- **UI**: SwiftUI
- **Backend**: Supabase Swift SDK (via SPM)
- **Auth**: Supabase (Google OAuth + Sign in with Apple)
- **AI**: Gemini 2.0 Flash REST API
- **Prayer Times**: Aladhan API (api.aladhan.com, method=3 MWL)
- **Storage**: Supabase Storage (`circle-moments` bucket, `avatars` bucket)
- **Push**: APNs
- **Xcode**: 26.3
- **Bundle ID**: `app.joinlegacy`
- **iOS target**: 17.0+

## Project Structure

```
Circles/
├── CirclesApp.swift          # App entry, deep link handling, APNs delegate
├── ContentView.swift         # Root routing (auth → onboarding → main app)
├── Assets.xcassets/
├── Secrets.plist             # GITIGNORED — Supabase URL/anon key, Gemini key
├── Auth/                     # AuthView (Sign in with Apple + Google)
├── Onboarding/               # AmiirOnboarding (4 steps), MemberOnboarding (2 steps), CirclePreviewView
├── Home/                     # Daily Intentions — HomeView, HabitDetailView
├── Community/                # CommunityView (Feed|Circles), MyCirclesView
├── Circles/                  # CircleDetailView, CreateCircleView, JoinCircleView
├── Moment/                   # MomentCameraView, MomentPreviewView, CameraManager
├── Feed/                     # FeedView, feed cards, ReciprocityGateView, CommentDrawerView
├── Profile/                  # ProfileView
├── DesignSystem/             # DesignTokens, Components, AppBackground, AvatarView, ThemeManager
├── Services/                 # All service singletons
├── Models/                   # Codable types for DB rows
└── Navigation/               # MainTabView
```

## Environment / Secrets

`Circles/Secrets.plist` (gitignored). Required keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`.

## Key Conventions

- `@Observable @MainActor` pattern throughout (Swift 6 — not ObservableObject)
- Supabase client singleton: `SupabaseService.shared`
- `import Supabase` required in every file accessing `auth.session?.user.id`
- Models conform to `Codable`, snake_case → camelCase via `CodingKeys`
- `DATE` columns stored as `String` in Swift models ("YYYY-MM-DD")
- `SwiftUI.Circle()` must be qualified — `Circle` model name conflict
- Optimistic UI for habit check-ins and reactions

## Database (Supabase)

Active tables:
- `habits` — user habits (is_accountable, circle_id, plan_notes)
- `habit_logs` — daily check-ins (notes field)
- `habit_plans` — AI 28-day roadmaps (refinement_count, week tracking)
- `streaks` — streak tracking
- `circles` — private circles (gender_setting, core_habits, group_streak_days)
- `circle_members` — membership (role: admin/member)
- `circle_moments` — photo posts
- `activity_feed` — habit check-ins + streak milestones for feed
- `habit_reactions` — reactions on feed items
- `comments` — circle-private comment threads
- `profiles` — user profiles (preferred_name, gender, avatar_url, location)
- `device_tokens` — APNs device tokens
- `daily_moments` — server-selected prayer of the day (one row per date)

RLS: `auth_user_circle_ids()` SECURITY DEFINER function prevents recursion in circle-member policies.

## Working Rules

### 1. Phase Discipline
- Build phases in order per ROADMAP.md
- Each phase gets a SPEC.md before execution
- Update STATE.md after every completed phase group

### 2. No Hacks
- Root cause > patch. Senior Swift developer standards.

### 3. Verification Before Done
- Build must succeed (zero errors)
- Feature demonstrable in Simulator before marking done

### 4. Commits
- One commit per build session (phase group)
- Push to `origin main` after each commit

### 5. SQL
- Migrations run via Supabase Dashboard → SQL Editor
- Always confirm with user before running destructive SQL

## Skills in Use

- **Axiom** — iOS/Swift domain patterns (auto-invoked during implementation)
- **SuperDesign** — visual design drafts before SwiftUI implementation

---
*Last updated: 2026-03-26 — v2.3, Phases 1-9 complete*
