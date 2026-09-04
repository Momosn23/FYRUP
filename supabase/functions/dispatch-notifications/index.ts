import { importPKCS8, SignJWT } from "npm:jose@5";
import { adminClient, json } from "../_shared/client.ts";

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
  const { data: notifications, error } = await db.from("notifications").select("id,recipient_id,title,body,data").is("push_sent_at", null).order("created_at").limit(100);
  if (error) return json({ error: error.message }, 500);
  if (!notifications?.length) return json({ delivered: 0 });
  const jwt = await apnsToken();
  const topic = Deno.env.get("APNS_TOPIC") ?? "app.fyrup.ios";
  let delivered = 0;
  for (const note of notifications) {
    const { data: tokens } = await db.from("device_tokens").select("token,environment").eq("user_id", note.recipient_id);
    for (const device of tokens ?? []) {
      const host = device.environment === "ios-sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
      const response = await fetch(`https://${host}/3/device/${device.token}`, {
        method: "POST",
        headers: { authorization: `bearer ${jwt}`, "apns-topic": topic, "apns-push-type": "alert", "apns-priority": "10" },
        body: JSON.stringify({ aps: { alert: { title: note.title, body: note.body }, sound: "default", "mutable-content": 1 }, ...note.data }),
      });
      if (response.ok) delivered++;
      if (response.status === 410) await db.from("device_tokens").delete().eq("token", device.token);
    }
    await db.from("notifications").update({ push_sent_at: new Date().toISOString() }).eq("id", note.id);
  }
  return json({ delivered });
});

