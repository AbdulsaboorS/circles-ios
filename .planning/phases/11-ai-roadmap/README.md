Phase 11 — AI roadmap (Supabase)

Run **`migration.sql`** in the SQL Editor **before** using “Refine plan” in the app. It adds `refinement_cycle` and the `apply_habit_plan_refinement` RPC (weekly cap of 3 refinements).

Generating an initial plan uses client upsert only and works once `habit_plans` exists from Phase 1 schema.
