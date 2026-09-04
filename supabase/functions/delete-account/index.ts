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

Deno.serve(async (request) => {
  const authorization = request.headers.get("authorization");
  if (!authorization) return json({ error: "unauthorized" }, 401);
  const db = adminClient();
  const token = authorization.replace(/^Bearer\s+/i, "");
  const { data: { user }, error } = await db.auth.getUser(token);
  if (error || !user) return json({ error: "unauthorized" }, 401);
  const { error: deletionError } = await db.auth.admin.deleteUser(user.id, false);
  if (deletionError) return json({ error: "deletion_failed" }, 500);
  return json({ deleted: true });
});
