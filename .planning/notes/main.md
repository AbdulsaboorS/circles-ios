# main — Phase 14 Context + Session Hook

## Goal

Scope lock session only — no implementation. Locked Phases 14–15 of the Personalization Era with user after critical review + investor feedback review. Updated ROADMAP.md / STATE.md / HANDOFF.md.

## Scope

Documentation + planning only. No code changes. Decided what ships pre-MVP vs what goes to the parking lot.

## Touched Files

- `.planning/ROADMAP.md` — inserted Phase 14 (Meaningful Habits) + Phase 15 (Social Pulse); renumbered old 14–18 → 16–19; added Parking Lot section
- `.planning/STATE.md` — Current Focus shifted from "Functionality fixes" to Phase 14; progress.total_phases bumped 18 → 19; noted streak glow work folds into Phase 14
- `.planning/HANDOFF.md` — notifications worktree now points at `phase-15-social-pulse`; next workstream on main remains Phase 14

## Decisions

### Locked Phase 14 — Meaningful Habits (~2.5–3 weeks)

1. **Niyyah prompt on habit creation** — one text field ("What's your niyyah for this?"); works for personal AND shared habits; no separate struggle-lens field for shared. Shows on Habit Detail as emotional anchor. Feeds AI plan.
2. **Catalog expansion** — 10 → ~30 items, 5 categories (Worship / Character / Knowledge / Health / Service). Revisit salah-as-habit framing in SPEC (collapse to "Pray 5 daily" or lift to separate consistency tracker).
3. **Onboarding quiz — 2 screens** — Islamic struggles + Life struggles (multi-select), simple branching rules, **max 3 suggested habits per result**, **skippable**, **redoable from Profile → Settings → "My Focus Areas"**. Answers stored as JSONB on `profiles` (`struggles_islamic`, `struggles_life`), private. Wired into Amir onboarding (after Step 2), Joiner onboarding (after Habit Alignment), in-app new-intention flow.
4. **Check-off ritual upgrade** — hold-to-complete + Niyyah-style animation + "Alhamdulillah" micro-moment. Reuses existing NiyyahDissolve / NoorAura / IslamicGeometricPattern.
5. **Single master geometric pattern streak visual** — always-on from day 1, intensity scales with streak. Starts from existing 8-pointed IslamicGeometricPattern. **One master pattern for all users** — no per-user niyyah seeding in v1. Retires static star. In-flight streak glow work pauses and folds in.

**Schema deltas:** `habits.niyyah TEXT` nullable; `profiles.struggles_islamic JSONB`, `profiles.struggles_life JSONB`.

### Locked Phase 15 — Social Pulse (~1–1.5 weeks)

Absorbs the old "Notifications" phase. Adds nudge push, comment push, permission modal UX, real-device end-to-end edge function verification, copy/tone audit. `send-moment-window-notifications` is already live via cron (Session 19); Phase 15 adds the social-interactive push on top. Existing `phase-15-social-pulse` worktree maps here.

### Parked (post-MVP, validate with real TestFlight users first)

- Intention arcs + end_dates + past-intentions archive + AI-extended roadmaps
- Photo evidence on habit check-ins
- Streak personalization with per-user niyyah seeding
- Habit check-in photo → Circle Moment promotion
- Quiz v2 (AI-generated beyond branching)
- Pattern-based nudges

### Rejected framings worth remembering

- **Arcs are scope creep** — user + critical agent aligned; investor disagreed but user's instinct won. "Pray Fajr forever" is identity, not a 28-day project. End_dates create dropout cliffs. AI roadmap extension across arcs is unsolved complexity.
- **Don't move Branding up** — investor pushed; rejected. Design system is locked from Phase 11.1 / 13; Branding Finalization is a 1–2 day naming task, not a blocker.
- **Struggle lens for shared habits is the same niyyah prompt** — one field covers both contexts; no schema divergence.

## Verified

- Docs cross-reference cleanly (ROADMAP phase numbers match STATE and HANDOFF)
- No code changes this session — no build to verify

## Next

- User: decide whether Phase 14 SPEC work runs on `main` or in a new worktree (separate from `phase-15-social-pulse`)
- User: run `/gsd:plan-phase` on Phase 14 to create `.planning/phases/14-meaningful-habits/` with SPEC + migration plan
- Optional: update PROJECT.md (v2.3 vision doc) to fold in niyyah prompt + onboarding quiz mechanics. Deferred this session for context reasons — low-risk to land when Phase 14 ships.
- Keep the notifications worktree aligned with Phase 15 naming.

## Blockers

None. Scope is locked.

## Notes For Re-entry

- **Context for next session:** User was exhausted by round after round of scope refinement. They finalized by saying "lets lock scope we need to move to building quick." Respect that. Don't reopen the scope unless user explicitly asks.
- **Watch for scope regression:** if anyone proposes arcs, end_dates, photo-on-check-in, or per-user streak pattern seeding — those are parked and were explicitly rejected. Don't re-suggest them; point to the parking lot.
- **The investor memo:** user shared an investor critique mid-session. Investor was right on notifications move-up and cutting photos + streak seeding. Investor was wrong on arcs ("necessary / genius") and on moving branding up. User's edits correctly split the difference.
- **Habit count per quiz:** user picked **3 max** over "5–7." Honor this number in SPEC.
- **Current iOS date:** 2026-04-20.
- **Don't touch PROJECT.md without the user's ack** — vision doc, deferred intentionally.
