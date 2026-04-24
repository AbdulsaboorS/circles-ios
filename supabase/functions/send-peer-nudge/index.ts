// nudge_log table required — run this migration before deploying:
// CREATE TABLE IF NOT EXISTS nudge_log (
//   id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
//   sender_id  uuid NOT NULL,
//   target_id  uuid NOT NULL,
//   nudge_date date NOT NULL DEFAULT CURRENT_DATE,
//   nudge_type text NOT NULL,
//   UNIQUE(sender_id, target_id, nudge_date)
// );

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendAPNs, APNsConfig } from "../_shared/apns.ts";

const apnsConfig: APNsConfig = {
  authKey: Deno.env.get("APNS_AUTH_KEY")!,
  keyId: Deno.env.get("APNS_KEY_ID")!,
  teamId: Deno.env.get("APNS_TEAM_ID")!,
  bundleId: Deno.env.get("APNS_BUNDLE_ID") ?? "app.joinlegacy",
  sandbox: false,
};

Deno.serve(async (req) => {
  const { senderId, targetUserId, circleId, nudgeType, message } = await req.json();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: targetPreferences } = await supabase
    .from("notification_preferences")
    .select("notifications_enabled, nudges_enabled")
    .eq("user_id", targetUserId)
    .maybeSingle();

  if (targetPreferences && (!targetPreferences.notifications_enabled || !targetPreferences.nudges_enabled)) {
    return new Response(JSON.stringify({ sent: 0, reason: "target_disabled_notifications" }), {
      headers: { "content-type": "application/json" },
    });
  }

  // If the target has no active device tokens, skip without consuming quota.
  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("device_token")
    .eq("user_id", targetUserId);

  if (!tokens?.length) {
    return new Response(JSON.stringify({ sent: 0, reason: "no_device_tokens" }), {
      headers: { "content-type": "application/json" },
    });
  }

  // Rate-limit: 1 nudge per sender per target per day
  const today = new Date().toISOString().split("T")[0];
  const { error: rateError } = await supabase
    .from("nudge_log")
    .insert({ sender_id: senderId, target_id: targetUserId, nudge_date: today, nudge_type: nudgeType });

  if (rateError?.code === "23505") {
    // UNIQUE violation — already nudged today
    return new Response(JSON.stringify({ error: "already_nudged_today" }), { status: 429 });
  }
  if (rateError) {
    return new Response(JSON.stringify({ error: "nudge_log_failed", details: rateError.message }), { status: 500 });
  }

  // Get sender name
  const { data: senderProfile } = await supabase
    .from("profiles")
    .select("preferred_name")
    .eq("id", senderId)
    .maybeSingle();
  const senderName = senderProfile?.preferred_name ?? "A circle member";

  const trimmedMessage = typeof message === "string" ? message.trim() : "";
  const route = nudgeType === "habit_reminder" ? "home" : "circles";
  const body = nudgeType === "moment"
    ? `${senderName} is waiting for your Moment!`
    : nudgeType === "custom" && trimmedMessage.length > 0
      ? `${senderName}: ${trimmedMessage}`
      : `${senderName} is cheering you on — check in your habits!`;

  for (const { device_token } of tokens ?? []) {
    await sendAPNs(device_token, {
      title: "You've been nudged",
      body,
      data: { circleId, route, type: "nudge", nudgeType },
    }, apnsConfig);
  }

  return new Response(JSON.stringify({ sent: tokens?.length ?? 0 }), {
    headers: { "content-type": "application/json" },
  });
});
