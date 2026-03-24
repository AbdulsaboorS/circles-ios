# Phase 6: Push Notifications — Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver all push notifications for Circles: daily Moment window alerts (at each circle's chosen prayer time), member-activity notifications (someone posted their Moment, peer habit/Moment nudges), and streak milestone celebrations. Includes APNs registration, device token storage, server-side scheduling via Supabase Edge Functions, prayer time calculation via Adhan Swift library, a city/country location picker in onboarding, notification permission prompt UX, and an unread badge on the Community tab.

Requirements: [PHASE6-APNS-TOKEN, PHASE6-PRAYER-TIME-NOTIFICATION, PHASE6-PRAYER-TIME-CALC, PHASE6-MEMBER-NOTIFICATIONS, PHASE6-STREAK-NOTIFICATIONS, PHASE6-PERMISSION-PROMPT]

</domain>

<decisions>
## Implementation Decisions

### Notification Architecture
- **D-01:** All notifications delivered via full server-side APNs. Supabase Edge Function calls Apple APNs directly. No local notifications.
- **D-02:** APNs device tokens stored in a new `device_tokens` Supabase table: columns `user_id`, `device_token`, `created_at`. Supports multiple devices per user (last-write-wins or append — Claude's discretion).
- **D-03:** iOS client registers for APNs on launch, receives the device token, and upserts it to `device_tokens` via Supabase.

### Notification Types (5 total)
- **D-04:** **Moment window open** — fires daily when the circle's prayer time arrives. Scheduled by server-side cron. Copy: "Your circle's Moment window is open — 30 minutes to post!"
- **D-05:** **Member posted Moment** — fires when a circle member posts their Moment, but ONLY to users who have already posted today (post-reciprocity-gate). Event-driven from MomentService insert trigger or Edge Function.
- **D-06:** **Streak milestone** — fires when a user hits a milestone (7, 30, 100-day streaks). Copy uses Islamic celebration framing: "MashAllah! 7 days of [Habit] — keep it up! 🌟" Fired from streak update logic server-side.
- **D-07:** **Peer Moment nudge** — a circle member can manually tap a "Nudge" button next to a peer who hasn't posted their Moment yet. Sends: "[Name] is waiting for your Moment!" The nudge button appears in the circle member list view.
- **D-08:** **Peer habit nudge** — same mechanic as Moment nudge, but for habit check-ins. Member taps "Nudge" next to someone who hasn't checked in today. Sends: "[Name] is cheering you on — check in your habits!"
- **D-09:** Rate-limit peer nudges to 1 nudge per sender per recipient per day — Claude decides exact implementation.

### Prayer Time Calculation
- **D-10:** Use **Adhan Swift** library (batoulapps/adhan-swift) via SPM. Offline, no API key, proven in Pillars and Muslim Pro. Calculation method: Muslim World League or ISNA (Claude's discretion based on accuracy for common diaspora regions).
- **D-11:** Prayer times are calculated server-side inside the Edge Function using lat/lng stored in Supabase. Adhan is used in the Swift client for display purposes; scheduling decisions happen on the server.
- **D-12:** Server-side cron (Edge Function on schedule) runs daily (e.g., midnight UTC), computes each user's prayer times for the next day using stored lat/lng, and sends APNs at the correct local time per circle per user.
- **D-13:** Future enhancement: Qivam API integration for mosque-specific prayer schedules (v1.1, opt-in "Follow my mosque's times" in Profile).

### Location for Prayer Times
- **D-14:** User sets their city/country in **onboarding** — a new step: "Where are you based?" after habit selection. City name + IANA timezone + approximate lat/lng (derived from city lookup) stored in Supabase `profiles` table (or equivalent user record). No CLLocationManager permission needed.
- **D-15:** City picker is searchable (type to filter cities). Claude decides the city dataset (bundled JSON or API — lightweight bundled list preferred for offline support).
- **D-16:** User can update city in Profile settings after onboarding.

### Notification Permission UX
- **D-17:** Permission prompt is triggered **when the user joins or creates their first circle** (not during onboarding, not at app launch).
- **D-18:** **Soft-prompt first**: show a custom modal explaining why notifications matter — "Your circle posts their Moment at [Prayer]. Turn on notifications to never miss the 30-minute window." → "Enable Notifications" CTA → THEN iOS system `requestAuthorization()` fires.
- **D-19:** If user denies: show a gentle note in CircleDetailView ("Notifications off — turn on in Settings to get Moment alerts") — Claude's discretion on exact placement.

### Community Tab Badge
- **D-20:** Show an unread count badge on the Community tab icon when there is new activity: member posted Moment (post-gate), or someone nudged you.
- **D-21:** Badge clears when user opens the Community tab. Implementation approach is Claude's discretion (local counter vs server-side unread count).

### Claude's Discretion
- Whether `device_tokens` table uses upsert (replace old token) or append (keep all tokens per device)
- Adhan calculation method (Muslim World League vs ISNA vs others)
- City dataset approach (bundled JSON vs lightweight API)
- Exact nudge button placement in CircleDetailView member list
- Streak milestone thresholds beyond 7/30/100 days
- Badge clear mechanism (local counter vs Supabase unread tracking)
- Notification permission denied state in CircleDetailView

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 6 Requirements
- `.planning/ROADMAP.md` §Phase 6 — Official requirements list (PHASE6-APNS-TOKEN through PHASE6-PERMISSION-PROMPT)

### Existing Architecture
- `.planning/phases/04-circle-moment-camera-post-reciprocity-gate/04-CONTEXT.md` — Reciprocity gate logic (must-post-to-see), MomentService, circle_moments table, on-time indicator. Member-posted-Moment notification fires ONLY to users who have already posted.
- `CLAUDE.md` §Database — Supabase tables in use; snake_case → camelCase CodingKeys convention; @Observable @MainActor service pattern
- `CLAUDE.md` §Key Conventions — Swift 6 patterns, SupabaseService.shared singleton

### Prayer Time Library
- Adhan Swift: `batoulapps/adhan-swift` — available via SPM at `https://github.com/batoulapps/adhan-swift`

### Existing Code Integration Points
- `Circles/Circles/CirclesApp.swift` — App entry point; needs `UIApplicationDelegate` adapter for APNs token registration (`didRegisterForRemoteNotificationsWithDeviceToken`)
- `Circles/Circles/Auth/AuthManager.swift` — Auth session; APNs registration should happen post-auth
- `Circles/Circles/Circles/CircleDetailView.swift` — Where peer nudge buttons appear (member list section)
- `Circles/Circles/Navigation/MainTabView.swift` — Community tab badge added here

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SupabaseService.shared` — singleton for all Supabase calls; APNs token upsert uses this
- `@Observable @MainActor` pattern — all new services (e.g., `NotificationService`) must follow this
- `CircleDetailView` — member list section is where nudge buttons are added
- `Color(hex:)` extension — amber `#E8834B` for any notification-related UI elements
- `MainTabView` — Tab bar; badge count added to Community tab here

### Established Patterns
- Service singletons (`CircleService`, `MomentService`) — new `NotificationService` follows same pattern
- `@preconcurrency import` for Apple frameworks not fully annotated for Swift 6 (may apply to UserNotifications)
- Supabase upsert pattern (used in MomentService for Storage) — same for device token upsert

### Integration Points
- `CirclesApp.swift` needs `UIApplicationDelegate` adapter to receive `didRegisterForRemoteNotificationsWithDeviceToken`
- `AuthManager` — after successful sign-in is the right moment to trigger APNs registration flow
- `CircleService.joinByInviteCode` / `createCircle` — after these succeed is when to trigger the notification permission soft-prompt (first circle join)
- `MomentService.postMoment` — after successful post, server-side trigger (or Edge Function webhook) fires member-posted-Moment notification to eligible circle members
- `HabitService.toggleHabitLog` / streak update — streak milestone detection triggers notification via Edge Function

</code_context>

<specifics>
## Specific Ideas

- Soft-prompt copy: "Your circle posts their Moment at [Prayer Time]. Turn on notifications to never miss the 30-minute window." → "Enable Notifications" button
- Streak notification copy: "MashAllah! 7 days of [Habit name] — keep it up! 🌟" — Islamic framing, celebratory, not generic
- Peer nudge copy: "[Name] is waiting for your Moment!" (Moment nudge) / "[Name] is cheering you on — check in your habits!" (habit nudge)
- Moment window notification: "Your circle's Moment window is open — 30 minutes to post!" with deep link into the circle
- Qivam API noted as v1.1 enhancement for mosque-specific prayer schedules (user expressed interest)

</specifics>

<deferred>
## Deferred Ideas

- **Qivam mosque-schedule integration** — v1.1: opt-in "Follow my mosque's times" setting in Profile. User expressed interest but agreed to ship Adhan Swift first.
- **Automated daily habit reminder** — System sends a push at a fixed time ("Don't forget to check in today!"). User chose manual peer nudges instead for Phase 6. Could be a v1.1 scheduled notification.
- **Cross-circle notification aggregation** — If user is in multiple circles with different prayer times, advanced deduplication/batching of Moment window notifications. Claude's discretion for initial implementation (one notif per circle per prayer time).

</deferred>

---

*Phase: 06-push-notifications*
*Context gathered: 2026-03-24*
