import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendAPNs, APNsConfig } from "../_shared/apns.ts";

type MomentRegion = "americas" | "europe" | "east_asia" | "west_asia";

type DailyMomentRow = {
  region: MomentRegion | null;
  prayer_name: string | null;
  moment_date: string;
  moment_time: string | null;
};

type ProfileRow = {
  id: string;
  region: MomentRegion | null;
  timezone: string | null;
};

const apnsConfig: APNsConfig = {
  authKey: Deno.env.get("APNS_AUTH_KEY")!,
  keyId: Deno.env.get("APNS_KEY_ID")!,
  teamId: Deno.env.get("APNS_TEAM_ID")!,
  bundleId: Deno.env.get("APNS_BUNDLE_ID") ?? "app.joinlegacy",
  sandbox: false,
};

const REGION_TIMEZONES: Record<MomentRegion, string> = {
  americas: "America/New_York",
  europe: "Europe/Paris",
  east_asia: "Asia/Tokyo",
  west_asia: "Asia/Dubai",
};

const ONE_DAY_MS = 24 * 60 * 60 * 1000;

function inferRegion(timezone: string | null | undefined): MomentRegion {
  if (!timezone) return "americas";

  if (
    timezone.startsWith("America/") ||
    timezone.startsWith("US/") ||
    timezone.startsWith("Canada/")
  ) {
    return "americas";
  }

  if (
    timezone.startsWith("Europe/") ||
    timezone.startsWith("Africa/") ||
    timezone.startsWith("Atlantic/")
  ) {
    return "europe";
  }

  if (
    timezone.startsWith("Asia/Tok") ||
    timezone === "Asia/Seoul" ||
    timezone.startsWith("Asia/Shang") ||
    timezone.startsWith("Asia/Hong") ||
    timezone === "Asia/Taipei" ||
    timezone.startsWith("Asia/Singap") ||
    timezone.startsWith("Australia/") ||
    timezone.startsWith("Pacific/")
  ) {
    return "east_asia";
  }

  if (timezone.startsWith("Asia/") || timezone.startsWith("Indian/")) {
    return "west_asia";
  }

  return "americas";
}

function localDateString(date: Date, timeZone: string): string {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });

  return formatter.format(date);
}

function localHour(date: Date, timeZone: string): number {
  const formatter = new Intl.DateTimeFormat("en-GB", {
    timeZone,
    hour: "2-digit",
    hour12: false,
  });

  return Number(formatter.format(date));
}

function resolveScheduledAt(row: DailyMomentRow): Date | null {
  if (!row.region || !row.moment_time) return null;

  const [yearStr, monthStr, dayStr] = row.moment_date.split("-");
  const [hourStr, minuteStr] = row.moment_time.split(":");
  const year = Number(yearStr);
  const month = Number(monthStr);
  const day = Number(dayStr);
  const hour = Number(hourStr);
  const minute = Number(minuteStr);

  if ([year, month, day, hour, minute].some(Number.isNaN)) {
    return null;
  }

  const baseUTC = new Date(Date.UTC(year, month - 1, day, hour, minute, 0, 0));
  const regionTimeZone = REGION_TIMEZONES[row.region];

  for (const offset of [0, 1, -1]) {
    const candidate = new Date(baseUTC.getTime() + offset * ONE_DAY_MS);
    if (
      localDateString(candidate, regionTimeZone) === row.moment_date &&
      localHour(candidate, regionTimeZone) >= 9 &&
      localHour(candidate, regionTimeZone) < 24
    ) {
      return candidate;
    }
  }

  return baseUTC;
}

Deno.serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const now = new Date();
  const windowMs = 2 * 60 * 1000;

  const candidateDates = [
    new Date(now.getTime() - ONE_DAY_MS),
    now,
    new Date(now.getTime() + ONE_DAY_MS),
  ].map((date) => date.toISOString().slice(0, 10));

  const { data: dailyMoments } = await supabase
    .from("daily_moments")
    .select("region, prayer_name, moment_date, moment_time")
    .in("moment_date", candidateDates);

  const activeMoments = (dailyMoments ?? [])
    .map((row) => {
      const typedRow = row as DailyMomentRow;
      const scheduledAt = resolveScheduledAt(typedRow);
      if (!scheduledAt || !typedRow.region) return null;
      const diff = Math.abs(now.getTime() - scheduledAt.getTime());
      if (diff > windowMs) return null;
      return {
        region: typedRow.region,
        prayerName: typedRow.prayer_name ?? "asr",
        scheduledAt,
      };
    })
    .filter((row): row is { region: MomentRegion; prayerName: string; scheduledAt: Date } => row !== null);

  if (!activeMoments.length) {
    return new Response(
      JSON.stringify({
        message: "no active regional moment windows",
        now: now.toISOString(),
      }),
      { headers: { "content-type": "application/json" } },
    );
  }

  const activeRegions = new Set(activeMoments.map((row) => row.region));
  const regionMetadata = new Map(
    activeMoments.map((row) => [row.region, row]),
  );

  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("device_token, user_id");

  if (!tokens?.length) {
    return new Response(JSON.stringify({ sent: 0, reason: "no device tokens" }), {
      headers: { "content-type": "application/json" },
    });
  }

  const userIds = [...new Set(tokens.map(({ user_id }) => user_id))];
  const { data: preferences } = await supabase
    .from("notification_preferences")
    .select("user_id, notifications_enabled, moment_window_enabled")
    .in("user_id", userIds);

  const { data: profiles } = await supabase
    .from("profiles")
    .select("id, region, timezone")
    .in("id", userIds);

  const preferenceMap = new Map(
    (preferences ?? []).map((row: {
      user_id: string;
      notifications_enabled: boolean;
      moment_window_enabled: boolean;
    }) => [row.user_id, row]),
  );

  const profileMap = new Map(
    (profiles ?? []).map((row) => {
      const typedRow = row as ProfileRow;
      const resolvedRegion = typedRow.region ?? inferRegion(typedRow.timezone);
      return [typedRow.id, resolvedRegion];
    }),
  );

  const sentUserIds = new Set<string>();
  const sentByRegion: Record<string, number> = {};

  for (const { device_token, user_id } of tokens) {
    const prefs = preferenceMap.get(user_id);
    if (prefs && (!prefs.notifications_enabled || !prefs.moment_window_enabled)) {
      continue;
    }

    const userRegion = profileMap.get(user_id) ?? "americas";
    if (!activeRegions.has(userRegion)) {
      continue;
    }

    const metadata = regionMetadata.get(userRegion);
    if (!metadata) {
      continue;
    }

    try {
      await sendAPNs(
        device_token,
        {
          title: "It's Moment time ✨",
          body: "Share your pause. Your circle is waiting.",
          data: {
            type: "moment_window",
            prayer: metadata.prayerName,
            region: userRegion,
          },
        },
        apnsConfig,
      );
      sentUserIds.add(user_id);
      sentByRegion[userRegion] = (sentByRegion[userRegion] ?? 0) + 1;
    } catch (err) {
      console.error(`[send-moment-window] APNs failed for userId=${user_id}:`, err);
    }
  }

  return new Response(
    JSON.stringify({
      sent: sentUserIds.size,
      activeRegions: [...activeRegions],
      sentByRegion,
      scheduledAt: Object.fromEntries(
        [...regionMetadata.entries()].map(([region, row]) => [region, row.scheduledAt.toISOString()]),
      ),
    }),
    { headers: { "content-type": "application/json" } },
  );
});
