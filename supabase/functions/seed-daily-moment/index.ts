import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PRAYERS = ["fajr", "dhuhr", "asr", "maghrib", "isha"];

Deno.serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Today's UTC date string
  const today = new Date().toISOString().slice(0, 10);

  // Skip if a row already exists for today
  const { data: existing } = await supabase
    .from("daily_moments")
    .select("id")
    .eq("moment_date", today)
    .limit(1);

  if (existing && existing.length > 0) {
    return new Response(
      JSON.stringify({ status: "already_seeded", date: today }),
      { headers: { "content-type": "application/json" } }
    );
  }

  // Pick a random prayer (kept as cosmetic label)
  const prayer = PRAYERS[Math.floor(Math.random() * PRAYERS.length)];

  // Pick a random UTC time between 13:00–03:00 UTC (≈ 8am–10pm ET)
  // We model this as: hour 13–23 OR 0–2 UTC
  // Simple approach: pick from range [13, 23] and [0, 2]
  const earlyHours = [0, 1, 2];
  const lateHours = Array.from({ length: 11 }, (_, i) => i + 13); // 13–23
  const allHours = [...lateHours, ...earlyHours];
  const hour = allHours[Math.floor(Math.random() * allHours.length)];
  const minute = Math.floor(Math.random() * 60);
  const momentTime = `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;

  const { error } = await supabase
    .from("daily_moments")
    .insert({ moment_date: today, prayer_name: prayer, moment_time: momentTime });

  if (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "content-type": "application/json" } }
    );
  }

  return new Response(
    JSON.stringify({ status: "seeded", date: today, prayer }),
    { headers: { "content-type": "application/json" } }
  );
});
