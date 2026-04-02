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

  // Pick a random prayer
  const prayer = PRAYERS[Math.floor(Math.random() * PRAYERS.length)];

  const { error } = await supabase
    .from("daily_moments")
    .insert({ moment_date: today, prayer_name: prayer });

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
