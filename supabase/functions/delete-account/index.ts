import { adminClient, json } from "../_shared/client.ts";

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
