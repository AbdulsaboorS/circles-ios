---
version: 2.3
last_updated: "2026-03-30"
purpose: "Manual verification after DB migrations and before UI polish (Phase 12)"
---

# Manual QA — Circles iOS

Use this when validating **Phase 11 (AI roadmap + refinement RPC)** after running `.planning/phases/11-ai-roadmap/migration.sql`, and for **regression smoke** before shipping.

## Prerequisites

- `Circles/Secrets.plist` present locally with `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`.
- Supabase: Phase 1 `habit_plans` table exists; **Phase 11 migration applied** (column `refinement_cycle` + function `apply_habit_plan_refinement` + grants).
- Test account signed in; network available (Gemini + Supabase).

---

## A. Phase 11 — 28-day roadmap (Habit detail)

| # | Action | Expected |
|---|--------|----------|
| A1 | Home → open a habit that **has no** `habit_plans` row (or delete plan in DB for a test habit) | Roadmap section shows copy + **Generate 28-day plan** only (no week rows yet). |
| A2 | Tap **Generate 28-day plan** | Brief loading; then **exactly 28** milestones in **4 week** groups (Week 1–4). |
| A3 | Check milestone rows | Each row: Day *n*, short date (MM/DD from local calendar), title + description. |
| A4 | **Today** styling | The milestone whose calendar day matches **today** (local) is visually marked as today (accent / emphasis). |
| A5 | **Refine plan** visible | With a plan loaded, **Refine plan** appears in the roadmap header. |
| A6 | Tap **Refine plan** → enter optional note → **Refine with AI** | Sheet dismisses; milestones update; no crash. |
| A7 | Supabase (optional) | Row in `habit_plans`: `refinement_count` increased; `refinement_cycle` matches current UTC ISO week key after server update. |
| A8 | Fourth refinement **same UTC week** | After 3 successful refines in the same ISO week, tapping refine shows **limit** message (client `isRefinementLimitReached` or server error surfaced in UI). |
| A9 | Habit **plan notes** | If `habits.plan_notes` is set, generation/refine should still succeed and content should feel informed by context (subjective sanity check). |

**Edge cases**

- **Bad Gemini JSON / network error**: App should show an error string, not hang; plan state should not corrupt silently.
- **Re-open habit**: Leaving and returning to Habit detail should reload plan from Supabase (`fetchPlan`).

---

## B. Phase 11 — Onboarding background plans

| # | Action | Expected |
|---|--------|----------|
| B1 | **Amir** path: complete full onboarding (including Soul Gate) with ≥1 habit created | After landing on Home, open each new habit’s detail; within a reasonable time, roadmap may already exist (background `ensureAIRoadmapForOnboarding`). If not immediate, pull to refresh / re-open screen — eventual consistency. |
| B2 | **Member** path: join with invite, pick ≥1 core habit, finish | Same as B1 for habits created in that session. |

---

## C. Regression smoke (keep green for Phase 12 UI work)

| Area | Quick check |
|------|-------------|
| Auth | Sign out / sign in (Apple or Google). |
| Home | Toggle a personal + an accountable habit; stats update. |
| Circles tab | Global feed loads; switch to My Circles. |
| Reciprocity gate | Before posting today’s moment, feed is gated; post moment → feed unlocks. |
| Circle detail | Member strip, Amir gear → settings sheet opens; moment CTA if applicable. |
| Feed cards | Open **comment** drawer on a moment / check-in / milestone; post and dismiss. |
| Reactions | React; face pile shows (when others reacted). |
| Profile | Avatar, stats, sign out. |

---

## D. Build verification (CLI)

From repo root (full permissions if sandbox blocks SwiftPM cache):

```bash
xcodebuild -scheme Circles -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ./.derivedData build
```

Expect **`BUILD SUCCEEDED`**.

---

*Next focus: Phase 12 — copy, App Store metadata, privacy manifest, TestFlight.*
