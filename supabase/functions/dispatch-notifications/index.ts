import { importPKCS8, SignJWT } from "npm:jose@5";
import { createClient } from "npm:@supabase/supabase-js@2";
import { dispatchQueuedNotification } from "./dispatch-queue.mjs";

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
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (!cronSecret || request.headers.get("x-cron-secret") !== cronSecret) return json({ error: "unauthorized" }, 401);
  const db = adminClient();
  const { data: notifications, error } = await db.from("notifications").select("id,recipient_id,actor_id,type,title,body,data").is("push_sent_at", null).order("created_at").limit(100);
  if (error) return json({ error: error.message }, 500);
  if (!notifications?.length) return json({ delivered: 0 });
  // Do not request APNS credentials for a batch consisting entirely of muted/revoked rows.
  let jwt: Promise<string> | undefined;
  const topic = Deno.env.get("APNS_TOPIC") ?? "app.fyrup.ios";
  let delivered = 0;
  let deferred = 0;
  let suppressed = 0;
  for (const note of notifications) {
    let token: string;
    const result = await dispatchQueuedNotification({ db, note, prepareToSend: async () => {
      jwt ??= apnsToken(); token = await jwt;
    }, sendToDevice: async (authorizedNote, device) => {
      const host = device.environment === "ios-sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
      return await fetch(`https://${host}/3/device/${device.token}`, {
        method: "POST",
        headers: { authorization: `bearer ${token}`, "apns-topic": topic, "apns-push-type": "alert", "apns-priority": "10" },
        body: JSON.stringify({ ...authorizedNote.data, aps: { alert: { title: authorizedNote.title, body: authorizedNote.body },
          sound: "default", "mutable-content": 1 }, fyrup_type: authorizedNote.type }),
      });
    } });
    delivered += result.delivered; deferred += result.deferred; suppressed += result.suppressed;
  }
  return json({ delivered, deferred, suppressed });
});
