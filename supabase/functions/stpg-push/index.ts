// STPG push sender (Supabase Edge Function, Deno).
// Called only by the database triggers in migration 002, which send the shared
// x-stpg-webhook-secret header. Required function secrets (docs/SETUP.md):
//   STPG_WEBHOOK_SECRET, FCM_SERVICE_ACCOUNT, optional FCM_PROJECT_ID.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

function b64url(data: ArrayBuffer | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function accessToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  const jwt = `${header}.${claims}.${b64url(sig)}`;
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const j = await r.json();
  if (!j.access_token) throw new Error(`OAuth failed: ${JSON.stringify(j)}`);
  return j.access_token;
}

function message(type: string, rec: Record<string, unknown>) {
  switch (type) {
    case "stpg_dispatches":
      return { title: `STPG DISPATCH // ${rec.subject ?? ""}`, body: String(rec.message ?? ""), screen: "dispatch", adminsOnly: false };
    case "stpg_missions":
      return { title: `NEW STPG MISSION // ${rec.title ?? ""}`, body: String(rec.instructions ?? ""), screen: "missions", adminsOnly: false };
    case "stpg_assistance_requests":
      return { title: `⚠ DRIVER NEEDS ASSISTANCE // ${rec.request_type ?? ""}`, body: String(rec.message ?? "Open STPG Assistance Command."), screen: "assistance", adminsOnly: true };
    default:
      return null;
  }
}

function sameSecret(a: string, b: string): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
  const expected = Deno.env.get("STPG_WEBHOOK_SECRET") ?? "";
  if (!sameSecret(req.headers.get("x-stpg-webhook-secret") ?? "", expected)) {
    return new Response("forbidden", { status: 403 });
  }
  try {
    const { type, record } = await req.json();
    const msg = message(type, record ?? {});
    if (!msg) return new Response("ignored", { status: 200 });

    // Assistance alerts go to admins only (public.stpg_admins). If that lookup fails,
    // send nothing rather than leaking a driver's emergency to everyone.
    let q = supabase.from("stpg_push_tokens").select("token,user_id");
    if (msg.adminsOnly) {
      const admins = await supabase.from("stpg_admins").select("user_id");
      if (admins.error || !admins.data?.length) return new Response("no admins", { status: 200 });
      q = q.in("user_id", admins.data.map((a: { user_id: string }) => a.user_id));
    }
    const { data: tokens, error } = await q;
    if (error) throw error;
    if (!tokens?.length) return new Response("no tokens", { status: 200 });

    const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
    const project = Deno.env.get("FCM_PROJECT_ID") ?? sa.project_id;
    const at = await accessToken(sa);
    let sent = 0;
    for (const t of tokens) {
      const r = await fetch(`https://fcm.googleapis.com/v1/projects/${project}/messages:send`, {
        method: "POST",
        headers: { Authorization: `Bearer ${at}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token: t.token,
            notification: { title: msg.title, body: msg.body.slice(0, 180) },
            data: { screen: msg.screen },
            android: { priority: "high", notification: { channel_id: "stpg_alerts" } },
            apns: { payload: { aps: { sound: "default" } } },
          },
        }),
      });
      if (r.ok) sent++;
      else {
        const body = await r.text();
        if (body.includes("UNREGISTERED") || body.includes("INVALID_ARGUMENT")) {
          await supabase.from("stpg_push_tokens").delete().eq("token", t.token);
        }
      }
    }
    return new Response(JSON.stringify({ sent }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    console.error(e);
    return new Response("error", { status: 500 });
  }
});
