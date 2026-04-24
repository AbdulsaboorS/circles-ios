# Circles iOS — Claude Code Instructions

## What This Is

A native Swift/SwiftUI iOS app — a private Islamic accountability tool ("Islamic BeReal"). Circle Moment (BeReal-style daily check-in anchored to prayer times) + habit tracking + small private circles.

**Switching agents:** read `.planning/HANDOFF.md` first, then `.planning/STATE.md`.

Open `.planning/ROADMAP.md` only if sequencing matters. Open `.planning/PROJECT.md` only if product vision or product rules matter.

## How to Think About This Project

Four principles guide all implementation work:

### 1. Think Before Coding
State assumptions explicitly. If uncertain, ask rather than guess. Present multiple interpretations when ambiguity exists. Surface tradeoffs. Push back if a simpler approach is available. Stop when confused and name what's unclear.

### 2. Simplicity First
Minimum code that solves the problem — nothing speculative. No features beyond what was asked, no abstractions for single-use code, no error handling for impossible scenarios. If it could be 50 lines instead of 200, rewrite it. The test: Would a senior engineer say this is overcomplicated?

### 3. Surgical Changes
Touch only what you must. Don't improve adjacent code, refactor things that aren't broken, or match pre-existing dead code — mention it instead. Every changed line should trace directly to the user's request. Remove imports/variables/functions that YOUR changes made unused; don't remove pre-existing dead code.

### 4. Goal-Driven Execution
Define success criteria upfront. Loop until verified. State a brief plan with checkpoints. Write tests first when debugging or validating. Build must succeed; feature must be demonstrable in Simulator. Strong verification criteria let work proceed independently.

### 5. Feynman Summary
For non-trivial responses, explain plainly — if you can't explain it simply in plain English, reanalyze until you can. This applies to all communication back to the user.

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

## Product Rules

Moment mechanic mirrors BeReal exactly. For design questions: default to BeReal's approach. Differentiation is context only (niyyah, circles, privacy), never the mechanic. See memory `project_moment_mechanic.md`.

## Working Rules

### 1. Phase Discipline
Follow roadmap ordering unless the user explicitly reprioritizes. Update shared planning docs only when current repo state materially changes.

### 2. Commits
One commit per logical unit (fix, feature slice, refactor). Keep commits self-contained. Commit to git when a logical unit is complete.

### 3. SQL
Run via Supabase Dashboard. Confirm destructive ops first. Schema cache: run `habit_plans_align_app.sql`.

### 4. Quick Troubleshooting

| Issue | Fix |
|-------|-----|
| `NSURLErrorDomain -1011` on Generate plan | Gemini non-200 — check key, quota, model |
| PostgREST schema cache | Run `habit_plans_align_app.sql` |
| SF Symbol name as text | Use `Image(systemName:)` pattern |

## Skills in Use

Axiom (iOS/Swift) and SuperDesign (visual design) — auto-invoked during implementation.
