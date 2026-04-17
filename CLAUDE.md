# Circles iOS — Claude Code Instructions

## What This Is

A native Swift/SwiftUI iOS app — a private Islamic accountability tool ("Islamic BeReal"). Circle Moment (BeReal-style daily check-in anchored to prayer times) + habit tracking + small private circles.

See `.planning/PROJECT.md` for full product vision (v2.3 PRD). See `.planning/ROADMAP.md` for phase breakdown. See `.planning/STATE.md` for what's built, **open issues**, and what's next. **Switching agents:** read `.planning/HANDOFF.md` first.

## Tech Stack

- **Language**: Swift 6
- **UI**: SwiftUI
- **Backend**: Supabase Swift SDK (via SPM)
- **Auth**: Supabase (Google OAuth + Sign in with Apple)
- **AI**: Gemini 3 Flash (preview) REST API — model `gemini-3-flash-preview` in `GeminiService`
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
- `habit_plans` — AI 28-day roadmaps (`milestones` JSONB, `refinement_count`, `refinement_week`, `refinement_cycle`); refinements via RPC `apply_habit_plan_refinement` (weekly cap)
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
- Early phases have `SPEC.md` / SQL under `.planning/phases/`; later phases may ship README + migration only
- Update `STATE.md` after meaningful phase or QA changes

### 2. No Hacks
- Root cause > patch. Senior Swift developer standards.

### 3. Verification Before Done
- Build must succeed (zero errors)
- Feature demonstrable in Simulator before marking done

### 4. Commits
- Commit at meaningful, self-contained checkpoints
- Prefer one commit per bug fix, feature slice, or focused refactor
- Do not batch unrelated changes into one commit
- Push to `origin main` after stable checkpoints, or at minimum at the end of each work session

### 5. SQL
- Migrations run via Supabase Dashboard → SQL Editor
- Always confirm with user before running destructive SQL
- **`habit_plans` / schema cache:** run `.planning/phases/01-schema-foundations/habit_plans_align_app.sql` — it ends with `NOTIFY pgrst, 'reload schema'`. There is no “reload schema” control under Settings → API on hosted Supabase; changes usually apply within seconds.

### 6. Troubleshooting (quick)

| Symptom | Likely cause / next step |
|--------|---------------------------|
| **`NSURLErrorDomain -1011`** on Generate plan | Gemini returned **non-200**; check key, quota, model id. See `STATE.md` → Open issues A. |
| PostgREST **milestones / schema cache** | Run `habit_plans_align_app.sql`; optional lone `NOTIFY pgrst, 'reload schema';` |
| SF Symbol **name as text** on habit detail | `HabitDetailView` uses `Text(habit.icon)` — should match `Image(systemName:)` pattern (see `STATE.md` C). |

## Skills in Use

- **Axiom** — iOS/Swift domain patterns (auto-invoked during implementation)
- **SuperDesign** — visual design drafts before SwiftUI implementation

---
*Last updated: 2026-04-02 — v2.4, Phase 11.2 closed; Phase 11.3 queued next. Open QA and deferred checks live in `STATE.md`, handoff in `HANDOFF.md`.*
