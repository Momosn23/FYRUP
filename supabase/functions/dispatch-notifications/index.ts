import { importPKCS8, SignJWT } from "npm:jose@5";
import { createClient } from "npm:@supabase/supabase-js@2";

function adminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Missing Supabase service configuration");
  return createClient(url, key, { auth: { persistSession: false } });
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

async function apnsToken() {
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const pem = Deno.env.get("APNS_PRIVATE_KEY")!.replaceAll("\\n", "\n");
  const key = await importPKCS8(pem, "ES256");
  return new SignJWT({}).setProtectedHeader({ alg: "ES256", kid: keyId }).setIssuer(teamId).setIssuedAt().sign(key);
}

Deno.serve(async (request) => {
  if (request.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) return json({ error: "unauthorized" }, 401);
  const db = adminClient();
  const { data: notifications, error } = await db.from("notifications").select("id,recipient_id,type,title,body,data").is("push_sent_at", null).order("created_at").limit(100);
  if (error) return json({ error: error.message }, 500);
  if (!notifications?.length) return json({ delivered: 0 });
  const jwt = await apnsToken();
  const topic = Deno.env.get("APNS_TOPIC") ?? "app.fyrup.ios";
  let delivered = 0;
  let deferred = 0;
  for (const note of notifications) {
    const preferenceKey: Record<string, string> = {
      activity_started: "friend_starts", joined_live: "friend_starts", fyrup: "fyrup",
      session_invite: "invitations", invite_response: "invitations", session_joined: "invitations",
      workout_plan_shared: "invitations",
      session_started: "invitations", session_cancelled: "invitations", session_updated: "invitations", reaction: "reactions", flame_reaction: "reactions",
      friend_request: "friend_requests", friend_accepted: "friend_requests",
      session_reminder: "reminders", weekly_goal: "weekly_goal", crew_goal: "crew_goal",
    };
    const key = preferenceKey[note.type];
    if (key) {
      const { data: preferences } = await db.from("notification_preferences").select(key).eq("user_id", note.recipient_id).maybeSingle();
      if (preferences?.[key] === false) {
        await db.from("notifications").update({ push_sent_at: new Date().toISOString() }).eq("id", note.id);
        continue;
      }
    }
    const { data: tokens } = await db.from("device_tokens").select("token,environment").eq("user_id", note.recipient_id);
    let canFinalize = true;
    for (const device of tokens ?? []) {
      const host = device.environment === "ios-sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
      const response = await fetch(`https://${host}/3/device/${device.token}`, {
        method: "POST",
        headers: { authorization: `bearer ${jwt}`, "apns-topic": topic, "apns-push-type": "alert", "apns-priority": "10" },
        body: JSON.stringify({ aps: { alert: { title: note.title, body: note.body }, sound: "default", "mutable-content": 1 }, ...note.data, fyrup_type: note.type }),
      });
      if (response.ok) delivered++;
      else if (response.status === 410) await db.from("device_tokens").delete().eq("token", device.token);
      else canFinalize = false;
    }
    if (canFinalize) await db.from("notifications").update({ push_sent_at: new Date().toISOString() }).eq("id", note.id);
    else deferred++;
  }
  return json({ delivered, deferred });
});
