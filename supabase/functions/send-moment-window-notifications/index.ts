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
  const windowMs = 2 * 60 * 1000; // ±2 minutes

  // Fetch all circle memberships with user location + circle prayer_time
  const { data: memberships } = await supabase
    .from("circle_members")
    .select(`
      user_id,
      circle_id,
      circles!inner(id, name, prayer_time),
      profiles!inner(latitude, longitude, timezone)
    `)
    .not("profiles.latitude", "is", null);

  if (!memberships) return new Response("no memberships", { status: 200 });

  const sent: string[] = [];

  for (const m of memberships) {
    const prayerName: string = (m.circles as { prayer_time: string }).prayer_time ?? "fajr";
    const lat: number = (m.profiles as { latitude: number }).latitude;
    const lng: number = (m.profiles as { longitude: number }).longitude;
    const circleId: string = m.circle_id;
    const circleName: string = (m.circles as { name: string }).name;
    const userId: string = m.user_id;

    const times = getPrayerTimes(lat, lng, now);
    const prayerTime = times[prayerName as keyof typeof times];
    if (!prayerTime) continue;

    const diff = Math.abs(now.getTime() - prayerTime.getTime());
    if (diff > windowMs) continue;

    // Fetch device tokens for this user
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("device_token")
      .eq("user_id", userId);

    if (!tokens?.length) continue;

    for (const { device_token } of tokens) {
      await sendAPNs(device_token, {
        title: circleName,
        body: "Your circle's Moment window is open — 30 minutes to post!",
        data: { circleId, type: "moment_window" },
      }, apnsConfig);
    }
    sent.push(userId);
  }

  return new Response(JSON.stringify({ sent: sent.length }), {
    headers: { "content-type": "application/json" },
  });
});
