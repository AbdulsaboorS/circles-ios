import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendAPNs, APNsConfig } from "../_shared/apns.ts";

const MILESTONES = [7, 30, 100];

const apnsConfig: APNsConfig = {
  authKey: Deno.env.get("APNS_AUTH_KEY")!,
  keyId: Deno.env.get("APNS_KEY_ID")!,
  teamId: Deno.env.get("APNS_TEAM_ID")!,
  bundleId: Deno.env.get("APNS_BUNDLE_ID") ?? "app.joinlegacy",
  sandbox: false,
};

Deno.serve(async (req) => {
  const { userId, habitName, streakCount } = await req.json();

  if (!MILESTONES.includes(Number(streakCount))) {
    return new Response("not a milestone", { status: 200 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("device_token")
    .eq("user_id", userId);

  for (const { device_token } of tokens ?? []) {
    await sendAPNs(device_token, {
      title: "MashAllah! 🌟",
      body: `${streakCount} days of ${habitName} — keep it up!`,
      data: { type: "streak_milestone", streakCount, habitName },
    }, apnsConfig);
  }

  return new Response(JSON.stringify({ notified: tokens?.length ?? 0 }), {
    headers: { "content-type": "application/json" },
  });
});
