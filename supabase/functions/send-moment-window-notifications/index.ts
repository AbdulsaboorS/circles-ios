import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendAPNs, APNsConfig } from "../_shared/apns.ts";
import { getPrayerTimes } from "../_shared/prayer_times.ts";

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

  // Step 1: Get today's prayer from daily_moments
  const { data: dailyMoment } = await supabase
    .from("daily_moments")
    .select("prayer_name")
    .eq("date", todayUTC)
    .maybeSingle();

  if (!dailyMoment?.prayer_name) {
    return new Response(
      JSON.stringify({ message: "no prayer scheduled today", date: todayUTC }),
      { headers: { "content-type": "application/json" } }
    );
  }

  const prayerName: string = dailyMoment.prayer_name;

  // Step 2: Fetch all users with location, joined with their circle memberships
  const { data: memberships } = await supabase
    .from("circle_members")
    .select(`
      user_id,
      circle_id,
      circles!inner(id, name),
      profiles!inner(latitude, longitude, timezone)
    `)
    .not("profiles.latitude", "is", null);

  if (!memberships || memberships.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), {
      headers: { "content-type": "application/json" },
    });
  }

  // Step 3: Deduplicate — one notification per user (pick first circle for title)
  const userMap = new Map<string, { lat: number; lng: number; circleName: string }>();
  for (const m of memberships) {
    if (!userMap.has(m.user_id)) {
      const profile = m.profiles as { latitude: number; longitude: number; timezone: string };
      const circle = m.circles as { name: string };
      userMap.set(m.user_id, {
        lat: profile.latitude,
        lng: profile.longitude,
        circleName: circle.name,
      });
    }
  }

  const sent: string[] = [];

  for (const [userId, { lat, lng, circleName }] of userMap.entries()) {
    // Step 4: Calculate prayer time for this user's location
    const times = getPrayerTimes(lat, lng, now);
    const prayerTime = times[prayerName as keyof typeof times];
    if (!prayerTime) continue;

    const diff = Math.abs(now.getTime() - prayerTime.getTime());
    if (diff > windowMs) continue;

    // Step 5: Fetch device tokens and send notification
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("device_token")
      .eq("user_id", userId);

    if (!tokens?.length) continue;

    for (const { device_token } of tokens) {
      await sendAPNs(
        device_token,
        {
          title: circleName,
          body: "Time to capture this moment. Your circle is waiting. \u2728",
          data: { type: "moment_window" },
        },
        apnsConfig
      );
    }
    sent.push(userId);
  }

  return new Response(JSON.stringify({ sent: sent.length, prayer: prayerName }), {
    headers: { "content-type": "application/json" },
  });
});
