# Circles iOS — Claude Code Instructions

## What This Is

A native Swift/SwiftUI iOS app — an Islamic social accountability tool for Muslims. Circle Moment (BeReal-style daily check-in anchored to prayer times) + habit tracking + small private circles.

See `.planning/PROJECT.md` for full product vision. See `.planning/ROADMAP.md` for phase breakdown.

## Tech Stack

- **Language**: Swift 6
- **UI**: SwiftUI
- **Backend**: Supabase Swift SDK (via SPM)
- **Auth**: Supabase (Google OAuth + Sign in with Apple)
- **AI**: Gemini 2.0 Flash REST API
- **Storage**: Supabase Storage (photos)
- **Push**: APNs
- **Xcode**: 26.3
- **Bundle ID**: `app.joinlegacy`
- **iOS target**: 17.0+

## Project Structure

```
Circles/
├── CirclesApp.swift          # App entry point, Supabase client init
├── ContentView.swift         # Root view (auth routing)
├── Assets.xcassets/          # App icon, images, colors
├── Secrets.plist             # GITIGNORED — Supabase URL/anon key, etc.
├── Auth/                     # Sign in with Apple, Google OAuth views
├── Onboarding/               # Habit selection, AI step-down wizard
├── Home/                     # Daily habit check-in
├── Circles/                  # My Circles list, Circle detail
├── Moment/                   # Camera, post, reciprocity gate
├── Feed/                     # Unified circle feed
├── Profile/                  # User profile, settings
├── Services/                 # SupabaseService, AuthService, HabitService, etc.
└── Models/                   # Codable types for DB rows
```

## Environment / Secrets

Sensitive keys go in `Circles/Secrets.plist` (gitignored by default). Access via:

```swift
guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
      let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
    fatalError("Secrets.plist not found")
}
```

Required keys:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `GEMINI_API_KEY`

## Key Conventions

- SwiftUI views use `@StateObject` / `@EnvironmentObject` for Supabase session
- Supabase client is a singleton: `SupabaseService.shared`
- Models conform to `Codable` and map directly to Supabase table columns (snake_case → camelCase via `CodingKeys` or custom decoder)
- Optimistic UI for habit check-ins and reactions
- No `UIKit` unless absolutely necessary (camera, APNs — use SwiftUI wrappers first)

## Database (Supabase — shared with Legacy web)

Reuse existing tables where possible:
- `habits` — user habits
- `habit_logs` — daily check-in records
- `streaks` — streak tracking
- `halaqas` — circles
- `halaqa_members` — circle membership
- `activity_feed` — circle activity items
- `habit_reactions` — reactions

New tables (to be added via migration):
- `circle_moments` — photo posts per circle per day
- Prayer time per circle field on `halaqas`

## Working Rules

### 1. Plan First
- For any multi-file change: enter plan mode, write plan, get principal-plan-reviewer to check it before building
- Single-file, obvious changes: build directly

### 2. Phase Discipline
- Build phases in order — don't skip ahead
- Each phase gets a PLAN.md before execution, SUMMARY.md after
- Update STATE.md after every completed phase

### 3. No Hacks
- If something feels wrong, stop and re-plan. Don't push through.
- Root cause > patch. Senior Swift developer standards.

### 4. Verification Before Done
- Build must succeed (no warnings if possible, no errors)
- Feature must be demonstrable in Simulator before marking done

### 5. Supabase SQL
- SQL migrations run via Supabase MCP or Dashboard
- Claude writes the Swift code; backend migrations handled separately

## GSD Tracking

- `.planning/PROJECT.md` — product context, requirements, decisions
- `.planning/ROADMAP.md` — phases and success criteria
- `.planning/STATE.md` — what's done, what's next, blockers
- `.planning/phases/XX-phase-name/PLAN.md` — per-phase plan
- `.planning/phases/XX-phase-name/SUMMARY.md` — per-phase completion record

---
*Last updated: 2026-03-23*
