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
  const payload = await req.json();
  const record = payload.record; // new circle_moments row
  const { circle_id: circleId, user_id: posterId } = record;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const today = new Date().toISOString().split("T")[0];

  // Fetch poster's display name from profiles
  const { data: posterProfile } = await supabase
    .from("profiles")
    .select("full_name")
    .eq("id", posterId)
    .single();
  const posterName = posterProfile?.full_name ?? "Someone in your circle";

  // Find all circle members who have ALREADY posted today (post-reciprocity-gate)
  const { data: postedToday } = await supabase
    .from("circle_moments")
    .select("user_id")
    .eq("circle_id", circleId)
    .gte("posted_at", `${today}T00:00:00Z`);

  const eligibleUserIds = (postedToday ?? [])
    .map((r: { user_id: string }) => r.user_id)
    .filter((uid: string) => uid !== posterId); // exclude the poster

  if (!eligibleUserIds.length) return new Response("no eligible recipients", { status: 200 });

  // Fetch tokens for eligible users
  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("user_id, device_token")
    .in("user_id", eligibleUserIds);

  for (const { device_token } of tokens ?? []) {
    await sendAPNs(device_token, {
      title: "New Moment",
      body: `${posterName} just posted their Moment!`,
      data: { circleId, type: "member_posted" },
    }, apnsConfig);
  }

  return new Response(JSON.stringify({ notified: tokens?.length ?? 0 }), {
    headers: { "content-type": "application/json" },
  });
});
