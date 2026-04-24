import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendAPNs, APNsConfig } from "../_shared/apns.ts";

const FIRST_THRESHOLD = 2;
const SECOND_THRESHOLD = 4;
const DAILY_CAP = 2;

const apnsConfig: APNsConfig = {
  authKey: Deno.env.get("APNS_AUTH_KEY")!,
  keyId: Deno.env.get("APNS_KEY_ID")!,
  teamId: Deno.env.get("APNS_TEAM_ID")!,
  bundleId: Deno.env.get("APNS_BUNDLE_ID") ?? "app.joinlegacy",
  sandbox: false,
};

type NotificationPreferenceRow = {
  user_id: string;
  notifications_enabled: boolean;
  circle_activity_enabled: boolean;
};

type DeviceTokenRow = {
  user_id: string;
  device_token: string;
};

type CircleMemberRow = {
  user_id: string;
};

type ActivityRow = {
  user_id: string;
};

type ProfileRow = {
  id: string;
  preferred_name: string | null;
};

type ExistingSendRow = {
  recipient_user_id: string;
  send_index: number;
};

type CircleRow = {
  name: string | null;
};

Deno.serve(async (req) => {
  const { circleId, actorUserId } = await req.json();

  if (!circleId || !actorUserId) {
    return new Response(JSON.stringify({ error: "missing_circle_or_actor" }), {
      status: 400,
      headers: { "content-type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const todayUTC = new Date().toISOString().slice(0, 10);
  const todayStart = `${todayUTC}T00:00:00Z`;

  const [{ data: circle }, { data: memberRows }, { data: activityRows }] = await Promise.all([
    supabase
      .from("circles")
      .select("name")
      .eq("id", circleId)
      .maybeSingle(),
    supabase
      .from("circle_members")
      .select("user_id")
      .eq("circle_id", circleId)
      .returns<CircleMemberRow[]>(),
    supabase
      .from("activity_feed")
      .select("user_id")
      .eq("circle_id", circleId)
      .eq("event_type", "habit_checkin")
      .gte("created_at", todayStart)
      .returns<ActivityRow[]>(),
  ]);

  const memberUserIds = (memberRows ?? []).map(({ user_id }) => user_id);
  const recipientUserIds = memberUserIds.filter((userId) => userId !== actorUserId);
  if (!recipientUserIds.length) {
    return json({ sent: 0, reason: "no_recipients" });
  }

  const checkedInUserIds = [...new Set((activityRows ?? []).map(({ user_id }) => user_id))];
  const quietRecipientIds = recipientUserIds.filter((userId) => !checkedInUserIds.includes(userId));
  if (!quietRecipientIds.length) {
    return json({ sent: 0, reason: "no_quiet_recipients" });
  }

  const [preferencesResult, tokensResult, sendLogResult, profilesResult] = await Promise.all([
    supabase
      .from("notification_preferences")
      .select("user_id, notifications_enabled, circle_activity_enabled")
      .in("user_id", quietRecipientIds)
      .returns<NotificationPreferenceRow[]>(),
    supabase
      .from("device_tokens")
      .select("user_id, device_token")
      .in("user_id", quietRecipientIds)
      .returns<DeviceTokenRow[]>(),
    supabase
      .from("circle_check_in_notifications")
      .select("recipient_user_id, send_index")
      .eq("notification_date", todayUTC)
      .in("recipient_user_id", quietRecipientIds)
      .returns<ExistingSendRow[]>(),
    supabase
      .from("profiles")
      .select("id, preferred_name")
      .in("id", checkedInUserIds)
      .returns<ProfileRow[]>(),
  ]);

  const preferenceMap = new Map(
    (preferencesResult.data ?? []).map((row) => [row.user_id, row])
  );
  const tokenMap = new Map<string, string[]>();
  for (const token of tokensResult.data ?? []) {
    tokenMap.set(token.user_id, [...(tokenMap.get(token.user_id) ?? []), token.device_token]);
  }
  const sendIndexMap = new Map<string, number[]>();
  for (const row of sendLogResult.data ?? []) {
    sendIndexMap.set(row.recipient_user_id, [
      ...(sendIndexMap.get(row.recipient_user_id) ?? []),
      row.send_index,
    ]);
  }
  const profileMap = new Map(
    (profilesResult.data ?? []).map((profile) => [profile.id, profile.preferred_name?.trim() ?? ""])
  );

  const results: Array<{ recipientUserId: string; sendIndex: number }> = [];

  for (const recipientUserId of quietRecipientIds) {
    const preferences = preferenceMap.get(recipientUserId);
    if (preferences && (!preferences.notifications_enabled || !preferences.circle_activity_enabled)) {
      continue;
    }

    const deviceTokens = tokenMap.get(recipientUserId) ?? [];
    if (!deviceTokens.length) {
      continue;
    }

    const priorSendIndexes = sendIndexMap.get(recipientUserId) ?? [];
    if (priorSendIndexes.length >= DAILY_CAP) {
      continue;
    }

    const distinctOtherMemberIds = checkedInUserIds.filter((userId) => userId !== recipientUserId);
    const distinctMemberCount = distinctOtherMemberIds.length;
    const sendIndex = priorSendIndexes.length + 1;
    const threshold = sendIndex === 1 ? FIRST_THRESHOLD : SECOND_THRESHOLD;
    if (distinctMemberCount < threshold) {
      continue;
    }

    const { error: insertError } = await supabase
      .from("circle_check_in_notifications")
      .insert({
        recipient_user_id: recipientUserId,
        circle_id: circleId,
        trigger_user_id: actorUserId,
        notification_date: todayUTC,
        send_index: sendIndex,
        distinct_member_count: distinctMemberCount,
      });

    if (insertError?.code === "23505") {
      continue;
    }
    if (insertError) {
      console.error("[send-circle-check-in] failed to insert send log", insertError);
      continue;
    }

    const body = summaryBody(
      distinctOtherMemberIds,
      profileMap,
      ((circle as CircleRow | null)?.name?.trim()) || "your circle"
    );

    for (const deviceToken of deviceTokens) {
      const result = await sendAPNs(
        deviceToken,
        {
          title: "Your circle is moving",
          body,
          badge: 1,
          data: {
            type: "circle_check_in",
            route: "circle_detail",
            circleId,
            detailTab: "huddle",
          },
        },
        apnsConfig
      );

      if (!result.success) {
        console.error(
          `[send-circle-check-in] APNs failed recipient=${recipientUserId} token=${deviceToken}: ${result.error}`
        );
      }
    }

    results.push({ recipientUserId, sendIndex });
  }

  return json({ sent: results.length, deliveries: results });
});

function summaryBody(
  memberIds: string[],
  profileMap: Map<string, string>,
  circleName: string
): string {
  const names = memberIds
    .map((userId) => profileMap.get(userId) || "")
    .filter((name) => name.length > 0)
    .slice(0, 2);

  if (memberIds.length === 2 && names.length === 2) {
    return `${names[0]} and ${names[1]} checked in with ${circleName}.`;
  }

  if (names.length === 2) {
    return `${names[0]}, ${names[1]}, and ${memberIds.length - 2} other${
      memberIds.length - 2 === 1 ? "" : "s"
    } checked in with ${circleName}.`;
  }

  if (names.length === 1) {
    return `${names[0]} and ${memberIds.length - 1} other${
      memberIds.length - 1 === 1 ? "" : "s"
    } checked in with ${circleName}.`;
  }

  return `${memberIds.length} members checked in with ${circleName}.`;
}

function json(body: unknown) {
  return new Response(JSON.stringify(body), {
    headers: { "content-type": "application/json" },
  });
}
