// APNs HTTP/2 push helper for Deno (Supabase Edge Functions)
// Signs JWT with ES256 using the APNs auth key (.p8 file contents)

export interface APNsConfig {
  authKey: string;   // .p8 file contents (PEM with -----BEGIN PRIVATE KEY-----)
  keyId: string;     // 10-char APNS_KEY_ID
  teamId: string;    // 10-char APNS_TEAM_ID
  bundleId: string;  // "app.joinlegacy"
  sandbox: boolean;  // false for production
}

export interface APNsPayload {
  title: string;
  body: string;
  badge?: number;
  sound?: string;
  data?: Record<string, unknown>;
}

// Build ES256 JWT for APNs authentication
async function buildAPNsJWT(config: APNsConfig): Promise<string> {
  const header = { alg: "ES256", kid: config.keyId };
  const claims = { iss: config.teamId, iat: Math.floor(Date.now() / 1000) };

  const encode = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const headerB64 = encode(header);
  const claimsB64 = encode(claims);
  const signingInput = `${headerB64}.${claimsB64}`;

  // Import private key from PEM
  const pemBody = config.authKey
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const inputBytes = new TextEncoder().encode(signingInput);
  const sigBuffer = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, cryptoKey, inputBytes);
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sigBuffer)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  return `${headerB64}.${claimsB64}.${sigB64}`;
}

export async function sendAPNs(
  deviceToken: string,
  payload: APNsPayload,
  config: APNsConfig
): Promise<{ success: boolean; error?: string }> {
  const jwt = await buildAPNsJWT(config);
  const host = config.sandbox
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";

  const body = JSON.stringify({
    aps: {
      alert: { title: payload.title, body: payload.body },
      badge: payload.badge ?? 0,
      sound: payload.sound ?? "default",
    },
    ...(payload.data ?? {}),
  });

  try {
    const res = await fetch(`https://${host}/3/device/${deviceToken}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": config.bundleId,
        "apns-push-type": "alert",
        "content-type": "application/json",
      },
      body,
    });
    if (res.status === 200) return { success: true };
    const errBody = await res.text();
    return { success: false, error: `APNs ${res.status}: ${errBody}` };
  } catch (e) {
    return { success: false, error: String(e) };
  }
}
