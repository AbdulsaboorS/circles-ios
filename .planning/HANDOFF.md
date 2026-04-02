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
- **Latest commits:** `bd6fe75` (QA batch 3) + `[pending commit]` (QA batch 4 — refinement + avatar)
- **User is actively testing on their real device.**

## What was done this session (Phase 11.2 QA fixes — batch 3 + 4)

### Batch 3 — commit `bd6fe75`
- **FeedService:** fixed column query `preferred_name` (was `display_name` — caused UUID fallback)
- **FeedItem + FeedService:** added `circleName` to all 3 feed item structs; fetched in parallel with display names
- **HabitCheckinRow / StreakMilestoneCard / MomentFeedCard:** circle name shown on every feed card
- **MomentFeedCard:** photo height 280→420px; circle name header strip added
- **HomeView:** personal intentions button "Update" → "Check in"
- **GeminiService:** friendly 503 error message added
- **HabitPlanService:** (REVERTED in batch 4 — see below)
- **MomentCameraView:** Open Settings button now uses `open(_:options:completionHandler:)` directly
- **supabase/functions/seed-daily-moment:** new Edge Function deployed via Supabase MCP

### Batch 4 — commit pending at session end
- **HabitPlanService `applyRefinement`:** reverted incorrect `[HabitPlan]` array decode; now uses `.single()` → forces PostgREST single-object response. This fixes "data couldn't be read because it isn't in the correct format" on refinement.
- **ProfileView:** added `avatarUploadError` state + alert so upload failures surface to user instead of silently failing
- **Storage RLS policies applied via Supabase MCP:** `avatars` bucket had **zero upload policies** — that was why profile picture upload was silently failing. Applied 3 policies: INSERT (own folder), UPDATE (own folder), SELECT (public).
- **daily_moments row:** seeded `2026-04-02` with `prayer_name = 'asr'` via MCP SQL
- **seed-daily-moment Edge Function:** deployed live via Supabase MCP (status: ACTIVE, verify_jwt: false)

## Daily moment cron — one manual step remaining

The `seed-daily-moment` Edge Function is deployed. To make it fire daily automatically:

1. Go to **Supabase Dashboard → Database → Extensions**
2. Enable **`pg_cron`** (search for it)
3. Go to **Database → Cron Jobs → New cron job**
   - Name: `seed-daily-moment`
   - Schedule: `0 0 * * *` (midnight UTC)
   - Type: HTTP request
   - URL: `https://<project-ref>.supabase.co/functions/v1/seed-daily-moment`
   - Method: POST

Alternatively via pg_net SQL once extensions are enabled:
```sql
SELECT cron.schedule('seed-daily-moment', '0 0 * * *',
  $$SELECT net.http_post('https://<ref>.supabase.co/functions/v1/seed-daily-moment','{}','application/json')$$
);
```

## Items still to test after this session

- **Profile picture upload** — should now work (storage RLS policies added). User needs to relaunch app and retry.
- **AI plan refinement** — should now work (`.single()` decode fix). User should retry refining.
- **Circle Moment camera** — user needs to grant camera permission on device and test posting.
- **Feed names** — should now show real names after `preferred_name` column fix.
- **Circle attribution on feed cards** — new; should appear on all card types.

## Open QA items (carried from before)

- **Member onboarding flow** — not fully tested yet by user
- **Joiner deep link** — `circles://join/Z5QZTNN5` — test with fresh account

## Swift / Xcode 26 note

**`Color.msToken` must be explicit** — Xcode 26 / Swift 6 does NOT infer `Color` from shorthand dot syntax (`.msGold`). Always use `Color.msGold`, `Color.msTextPrimary`, etc.

## Deep link format

Custom URL scheme: `circles://join/INVITECODE`
Example: `circles://join/Z5QZTNN5`

## Invite codes (for testing)

| Circle | Invite Code | Type |
|--------|-------------|------|
| Isha at Masjid (Abdulsaboor's) | `Z5QZTNN5` | Brothers |
| Fair | `JMY7P3UE` | Brothers |

## Secrets (local only)

`Circles/Secrets.plist`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`.

## Git

`main` → `origin` (GitHub: AbdulsaboorS/circles-ios)
