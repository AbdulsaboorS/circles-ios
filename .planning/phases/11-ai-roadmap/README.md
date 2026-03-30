# Phase 11 — AI roadmap (Supabase + app)

## SQL

Run **`migration.sql`** in the Supabase SQL Editor **before** using **Refine plan** in the app.

- Adds `habit_plans.refinement_cycle` (TEXT).
- Creates **`apply_habit_plan_refinement(p_habit_id uuid, p_milestones jsonb)`** — returns updated row; enforces **3 refinements per UTC ISO week** per habit plan.

**Initial “Generate 28-day plan”** uses the Swift client (`HabitPlanService.upsertInitialPlan`) against existing `habit_plans` from Phase 1 schema — no extra SQL beyond Phase 1 for that path.

## Smoke (after migration)

Habit detail → **Generate 28-day plan** (28 days, week groups, Today) → **Refine** a few times → confirm **4th refine same UTC week** hits the limit. Optional: Amir/Member onboarding and re-open new habits for background plans.
