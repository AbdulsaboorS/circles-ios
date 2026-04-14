import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendAPNs, APNsConfig } from "../_shared/apns.ts";

const apnsConfig: APNsConfig = {
  authKey: Deno.env.get("APNS_AUTH_KEY")!,
  keyId: Deno.env.get("APNS_KEY_ID")!,
  teamId: Deno.env.get("APNS_TEAM_ID")!,
  bundleId: Deno.env.get("APNS_BUNDLE_ID") ?? "app.joinlegacy",
  sandbox: false,
};

Deno.serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const now = new Date();
  const todayUTC = now.toISOString().slice(0, 10); // "YYYY-MM-DD"
  const windowMs = 2 * 60 * 1000; // ±2 minutes

  // Step 1: Get today's daily moment row (including random moment_time)
  const { data: dailyMoment } = await supabase
    .from("daily_moments")
    .select("prayer_name, moment_time")
    .eq("moment_date", todayUTC)
    .maybeSingle();

  if (!dailyMoment?.moment_time) {
    return new Response(
      JSON.stringify({ message: "no moment_time scheduled today", date: todayUTC }),
      { headers: { "content-type": "application/json" } }
    );
  }

  // Step 2: Check if now is within ±2 minutes of the scheduled moment_time (UTC)
  const [hourStr, minuteStr] = dailyMoment.moment_time.split(":");
  const scheduledTime = new Date(now);
  scheduledTime.setUTCHours(parseInt(hourStr, 10), parseInt(minuteStr, 10), 0, 0);

  const diff = Math.abs(now.getTime() - scheduledTime.getTime());
  if (diff > windowMs) {
    return new Response(
      JSON.stringify({
        message: "not moment time yet",
        scheduledAt: scheduledTime.toISOString(),
        now: now.toISOString(),
        diffSeconds: Math.round(diff / 1000),
      }),
      { headers: { "content-type": "application/json" } }
    );
  }

  // Step 3: Fetch all device tokens
  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("device_token, user_id");

  if (!tokens?.length) {
    return new Response(JSON.stringify({ sent: 0, reason: "no device tokens" }), {
      headers: { "content-type": "application/json" },
    });
  }

  // Step 4: Send APNs push to every device
  const prayerName = dailyMoment.prayer_name ?? "asr";
  const sent: string[] = [];

  for (const { device_token, user_id } of tokens) {
    try {
      await sendAPNs(
        device_token,
        {
          title: "It's Moment time ✨",
          body: "Share your pause. Your circle is waiting.",
          data: { type: "moment_window", prayer: prayerName },
        },
        apnsConfig
      );
      sent.push(user_id);
    } catch (err) {
      console.error(`[send-moment-window] APNs failed for userId=${user_id}:`, err);
    }
  }

  return new Response(
    JSON.stringify({ sent: sent.length, scheduledAt: scheduledTime.toISOString() }),
    { headers: { "content-type": "application/json" } }
  );
});
