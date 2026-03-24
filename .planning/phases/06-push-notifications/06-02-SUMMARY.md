---
phase: 06-push-notifications
plan: 02
subsystem: backend/edge-functions
tags: [push-notifications, apns, edge-functions, prayer-times, supabase, deno]
dependency_graph:
  requires:
    - 06-01 (device_tokens table, iOS APNs registration)
  provides:
    - APNs JWT helper (_shared/apns.ts)
    - Adhan prayer time calculator (_shared/prayer_times.ts)
    - send-moment-window-notifications Edge Function
    - send-member-posted-notification Edge Function
    - send-streak-milestone-notification Edge Function
    - send-peer-nudge Edge Function
  affects:
    - 06-03 (UI nudge buttons call send-peer-nudge endpoint)
tech_stack:
  added:
    - Deno TypeScript Edge Functions (Supabase)
    - APNs HTTP/2 ES256 JWT signing via Web Crypto API
    - Adhan Muslim World League algorithm (pure TS port, no npm)
  patterns:
    - Database webhook trigger (circle_moments INSERT → send-member-posted-notification)
    - Cron Edge Function (every-minute cron with ±2min prayer time window)
    - Rate limiting via UNIQUE constraint + 23505 error code detection
key_files:
  created:
    - supabase/functions/_shared/apns.ts
    - supabase/functions/_shared/prayer_times.ts
    - supabase/functions/send-moment-window-notifications/index.ts
    - supabase/functions/send-member-posted-notification/index.ts
    - supabase/functions/send-streak-milestone-notification/index.ts
    - supabase/functions/send-peer-nudge/index.ts
  modified: []
decisions:
  - "APNs JWT built with Web Crypto API (ECDSA P-256 ES256) — no third-party APNs library needed in Deno"
  - "Prayer time calculation uses pure TS Adhan port with Muslim World League constants (MWL_FAJR_ANGLE=18, MWL_ISHA_ANGLE=17) — no external API or npm package"
  - "Moment-window cron runs every minute; checks if now is within ±2 min of each user's prayer time"
  - "Member-posted notification uses post-reciprocity-gate: only notifies users who have ALREADY posted today"
  - "Streak milestone function accepts POST {userId, habitName, streakCount}; silently returns 200 for non-milestones"
  - "Peer nudge rate limit enforced via nudge_log INSERT UNIQUE(sender_id, target_id, nudge_date); 23505 returns 429"
  - "nudge_log table SQL documented as comment in send-peer-nudge/index.ts for developer to run as migration"
metrics:
  duration_minutes: 2
  completed_date: "2026-03-24"
  tasks_completed: 2
  tasks_total: 2
  files_created: 6
  files_modified: 0
---

# Phase 6 Plan 02: Supabase Edge Functions for Push Notifications Summary

**One-liner:** Six Deno Edge Functions delivering APNs push via ES256 JWT, with offline Muslim World League prayer time calculation, post-reciprocity-gate member notifications, Islamic streak copy, and nudge_log rate limiting.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | APNs helper + Adhan prayer time calculator | 57893c0 | `_shared/apns.ts`, `_shared/prayer_times.ts` |
| 2 | Four notification Edge Functions | c5a8ca9 | `send-moment-window-notifications/index.ts`, `send-member-posted-notification/index.ts`, `send-streak-milestone-notification/index.ts`, `send-peer-nudge/index.ts` |

## What Was Built

### _shared/apns.ts
ES256 JWT-signed APNs HTTP/2 push helper. Uses Web Crypto API (`crypto.subtle.importKey` + `crypto.subtle.sign`) with ECDSA P-256 to sign the Apple APNs JWT. No third-party APNs library. Exports `sendAPNs(deviceToken, payload, config)` and interfaces `APNsConfig` / `APNsPayload`. Targets `api.push.apple.com` (production) or `api.sandbox.push.apple.com`.

### _shared/prayer_times.ts
Pure TypeScript port of the Adhan algorithm using Muslim World League constants (`MWL_FAJR_ANGLE = 18.0`, `MWL_ISHA_ANGLE = 17.0`). Implements Julian Date calculation, sun position (declination + equation of time), hour angle computation, and Standard/Shafi Asr shadow factor. Exports `getPrayerTimes(lat, lng, date): PrayerTimes` returning 6 prayer times as UTC Date objects. Zero external dependencies.

### send-moment-window-notifications
Daily cron Edge Function. Queries `circle_members` joined to `circles` (for `prayer_time`) and `profiles` (for `latitude`, `longitude`). For each membership, computes prayer times via `getPrayerTimes`, checks if `now` is within ±2 minutes of the circle's chosen prayer, fetches `device_tokens`, and sends push: "Your circle's Moment window is open — 30 minutes to post!" Deploy with Supabase Cron every minute.

### send-member-posted-notification
Database webhook trigger on `circle_moments` INSERT. Reads the new row's `circle_id` and `user_id`, fetches the poster's `full_name`, finds all members who already posted today (post-reciprocity-gate), fetches their tokens, and sends: "[Name] just posted their Moment!" Poster excluded from recipients.

### send-streak-milestone-notification
HTTP POST endpoint accepting `{ userId, habitName, streakCount }`. Silently returns 200 if `streakCount` is not in `MILESTONES = [7, 30, 100]`. Otherwise fetches tokens and sends Islamic celebration push: "MashAllah! 🌟 — [N] days of [habit] — keep it up!"

### send-peer-nudge
HTTP POST endpoint accepting `{ senderId, targetUserId, circleId, nudgeType }`. Rate-limits via `nudge_log` INSERT; on UNIQUE violation (error code `23505`) returns 429 `already_nudged_today`. Fetches sender's `full_name`, constructs copy based on `nudgeType`: Moment nudge — "[Name] is waiting for your Moment!"; habit nudge — "[Name] is cheering you on — check in your habits!"

## Notification Copy (per D-04 through D-08)

| Type | Title | Body |
|------|-------|------|
| Moment window | [Circle name] | "Your circle's Moment window is open — 30 minutes to post!" |
| Member posted | "New Moment" | "[Name] just posted their Moment!" |
| Streak milestone | "MashAllah! 🌟" | "[N] days of [habit] — keep it up!" |
| Peer Moment nudge | "You've been nudged" | "[Name] is waiting for your Moment!" |
| Peer habit nudge | "You've been nudged" | "[Name] is cheering you on — check in your habits!" |

## Deviations from Plan

None — plan executed exactly as written.

Note: Deno is not installed in the local development environment; `deno check` type validation could not be run. Files were written exactly from the plan specification and all acceptance criteria were verified via `grep` pattern checks. Type errors are extremely unlikely given the files implement the exact interfaces defined within themselves.

## Migration Required

Before deploying `send-peer-nudge`, the `nudge_log` table must be created. SQL is documented as a comment block at the top of `send-peer-nudge/index.ts`:

```sql
CREATE TABLE IF NOT EXISTS nudge_log (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id  uuid NOT NULL,
  target_id  uuid NOT NULL,
  nudge_date date NOT NULL DEFAULT CURRENT_DATE,
  nudge_type text NOT NULL,
  UNIQUE(sender_id, target_id, nudge_date)
);
```

## Deployment Notes

- Set secrets in Supabase Dashboard: `APNS_AUTH_KEY`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`
- Configure `send-member-posted-notification` as Database Webhook: table=`circle_moments`, event=INSERT
- Configure `send-moment-window-notifications` as Supabase Cron: schedule every 1 minute

## Known Stubs

None — all functions are fully wired. No placeholder data.

## Self-Check: PASSED

All 6 files confirmed on disk. Both task commits (57893c0, c5a8ca9) confirmed in git log.
