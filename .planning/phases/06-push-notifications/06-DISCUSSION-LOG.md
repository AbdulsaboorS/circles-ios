# Phase 6: Push Notifications — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-24
**Phase:** 06-push-notifications
**Areas discussed:** Notification architecture, Prayer time calculation, Location for prayer times, Permission prompt UX, Notification types (expanded)

---

## Notification Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid (local + server-side) | Local for scheduled (Moment window, streaks), server-side APNs for event-driven (member posted) | |
| Full server-side APNs | All notifications via Supabase Edge Function → Apple APNs | ✓ |
| Local only | All via UNNotificationCenter — cannot support member-posted-Moment | |

**User's choice:** Full server-side APNs
**Notes:** User wants notifications to fire even if app hasn't been opened in days.

---

## Token Storage

| Option | Description | Selected |
|--------|-------------|----------|
| New device_tokens table | user_id + device_token + created_at. Multi-device support. | ✓ |
| Column on profiles table | Add apns_token column. One device per user. | |

**User's choice:** New device_tokens table

---

## Notification Types

| Option | Description | Selected |
|--------|-------------|----------|
| Moment window open | Daily at circle's prayer time | ✓ |
| Member posted Moment | After you've posted (post-gate) | ✓ |
| Streak milestone | At 7, 30, 100-day milestones | ✓ |
| Peer nudge (Moment) | Manual nudge button for peers who haven't posted | ✓ |
| Peer nudge (Habit) | Manual nudge for peers who haven't checked in habits | ✓ |

**User's choice:** All 5 types
**Notes:** User also raised "encouraging nudges from us" — resolved as expanding streak notifications with Islamic celebration copy (MashAllah framing). Automated daily habit reminder deferred to v1.1.

---

## Prayer Time Calculation

| Option | Description | Selected |
|--------|-------------|----------|
| Adhan Swift library | Offline, SPM, no API key, proven | ✓ |
| Prayer time API | Network-dependent, simpler code | |
| Qivam API | Mosque-specific schedules, open source, early-stage | Deferred v1.1 |

**User's choice:** Adhan Swift
**Notes:** User flagged Qivam.com for consideration. Investigated — Qivam is mosque-directory-based (per-mosque schedules, not generic calculator). Agreed to ship Adhan Swift first; Qivam as opt-in "Follow my mosque's times" in v1.1.

---

## Scheduling Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| On app open, schedule 7 days ahead | App computes + schedules on each open | |
| Server-side cron job | Edge Function runs daily, sends APNs per user | ✓ |

**User's choice:** Server-side cron
**Notes:** User wants notifications to fire even if the user never opens the app. Location must be stored server-side.

---

## Location for Prayer Times

| Option | Description | Selected |
|--------|-------------|----------|
| City/country picker + store timezone | User picks city in onboarding. No CLLocationManager needed. | ✓ |
| CLLocationManager + store coordinates | Precise GPS, but another system permission prompt | |

**User's choice:** City/country picker
**Follow-up — where city picker lives:**

| Option | Description | Selected |
|--------|-------------|----------|
| During onboarding (after habit selection) | Set once, ready from day one | ✓ |
| Profile settings only | User finds it after first wrong notification | |
| On first circle join | Contextual but adds friction to join flow | |

**User's choice:** During onboarding

---

## Permission Prompt UX

| Option | Description | Selected |
|--------|-------------|----------|
| Soft-prompt then system prompt | Custom modal explaining value → iOS dialog | ✓ |
| System prompt directly after first circle join | Raw iOS dialog, no context | |
| System prompt during onboarding city step | Contextual but no circle context yet | |

**User's choice:** Soft-prompt then system prompt
**Notes:** Soft-prompt triggered on first circle join/create. Custom modal copy: "Your circle posts their Moment at [Prayer]. Turn on notifications to never miss the 30-minute window."

---

## Community Tab Badge

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — badge on Community tab | Unread count for new Moments + nudges | ✓ |
| No badge | Push only, keep tab bar clean | |

**User's choice:** Yes, badge on Community tab (Phase 5 had deferred this to Phase 6)

---

## Claude's Discretion

- Adhan calculation method (Muslim World League vs ISNA)
- City dataset approach (bundled JSON vs API)
- Nudge button placement in CircleDetailView
- Badge clear mechanism
- device_tokens upsert vs append strategy
- Streak milestone thresholds beyond 7/30/100

## Deferred Ideas

- Qivam mosque-schedule integration (v1.1)
- Automated daily habit reminder push (v1.1)
- Cross-circle notification deduplication/batching (Claude's discretion for MVP)
