/** Queue authorization is evaluated with a server-only client, never with cached UI state. */
export const preferenceKeys = Object.freeze({
  activity_started: "friend_starts", joined_live: "friend_starts", fyrup: "fyrup",
  session_invite: "invitations", invite_response: "invitations", session_joined: "invitations",
  workout_plan_shared: "invitations", session_started: "invitations", session_cancelled: "invitations",
  session_updated: "invitations", blind_workout_received: "invitations",
  reaction: "reactions", flame_reaction: "reactions", blind_workout_completed: "reactions",
  blind_reaction: "reactions", shot_reaction: "reactions",
  friend_request: "friend_requests", friend_accepted: "friend_requests",
  session_reminder: "reminders", supplement_reminder: "reminders", weekly_goal: "weekly_goal", crew_goal: "crew_goal",
  shot_called: "weekly_goal", shot_achieved: "weekly_goal",
});

const blindTypes = new Set(["blind_workout_received", "blind_workout_completed", "blind_reaction"]);
const shotTypes = new Set(["shot_called", "shot_achieved", "shot_reaction"]);
const isUUID = (value) => typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);

/** Display only: typed, exact historical system templates; never change user-authored bodies. */
export function notificationCopy(note) {
  let { title, body } = note;
  switch (note.type) {
    case "supplement_reminder": return { title: "Deine Erinnerung", body: "Ein Eintrag auf deiner heutigen Liste ist noch offen." };
    case "activity_started": title = title.replace(/ trainiert gerade 🔥$/, " ist gerade LIVE 🔥"); break;
    case "session_invite":
      if (title === "Trainingseinladung 🔥") title = "Session-Einladung 🔥";
      title = title.replace(/ lädt dich zum Training ein\.$/, " lädt dich zu einer Session ein."); break;
    case "session_updated": if (title === "Training wurde aktualisiert") title = "Session aktualisiert"; break;
    case "session_started": if (title === "Training wurde gestartet 🔥") title = "Die Session ist jetzt LIVE 🔥"; break;
    case "session_cancelled":
      if (title === "Training abgesagt") title = "Session abgesagt";
      if (body === "Der Host hat das Training abgesagt.") body = "Der Host hat die Session abgesagt."; break;
    case "session_joined": if (body === "Ein Freund hat sich deinem Training angeschlossen.") body = "Ein Freund ist bei deiner Session dabei."; break;
    case "session_reminder": if (title === "Training in 30 Minuten 🔥") title = "Deine Session startet in 30 Minuten 🔥"; break;
    case "workout_plan_shared":
      if (title === "Ein Trainingsplan für dich") title = "Ein Workout-Plan für dich";
      title = title.replace(/ teilt einen Trainingsplan\.$/, " teilt einen Workout-Plan."); break;
    case "weekly_goal": body = body.replace(/^([0-9]+ \/ [0-9]+) Trainings\. Wochenziel geschafft\.$/, "$1 Einheiten. Wochenziel geschafft."); break;
    case "shot_called": body = body.replace(/^([3-7]) Trainings diese Woche\.$/, "$1 Einheiten diese Woche."); break;
  }
  return { title, body };
}

/** Reserved routing fields always come from the authorized row, never its data bag. */
export function notificationPayload(note) {
  const supplement = note.type === "supplement_reminder";
  return {
    ...(supplement ? { dose_id: note.data.dose_id } : note.data),
    aps: { alert: notificationCopy(note), sound: "default", "mutable-content": 1,
      ...(supplement ? { category: "FYRUP_SUPPLEMENT" } : {}) },
    fyrup_type: note.type,
    fyrup_notification_id: note.id,
    fyrup_recipient_id: note.recipient_id,
  };
}

export function notificationDeliveryHeaders(note) {
  if (note.type !== "supplement_reminder") return {};
  if (!isUUID(note.data?.dose_id)) throw new Error("Invalid reminder receipt");
  // No delayed delivery after offline periods. New, still-open reminders may follow
  // at the user's bounded cadence; APNS cannot recall a previously delivered alert.
  return { "apns-expiration": "0", "apns-collapse-id": `supplement-${note.data.dose_id.toLowerCase()}` };
}

/**
 * Result is send, drop (known revoked/muted/stale), or defer (unknown due to failure).
 * Supabase reports normal query errors in `error`; rejected promises also fail closed.
 * @param {any} db
 * @param {any} note
 * @returns {Promise<"send" | "drop" | "defer">}
 */
export async function evaluateQueuedNotification(db, note) {
  try {
    const key = Object.hasOwn(preferenceKeys, note.type) ? preferenceKeys[note.type] : null;
    if (!key || !isUUID(note.recipient_id)) return "drop";
    const preferences = await db.from("notification_preferences").select(key).eq("user_id", note.recipient_id).maybeSingle();
    if (preferences.error) return "defer";
    // A missing row uses the same default as SQL coalesce(..., true).
    if (preferences.data !== null) {
      if (!isObject(preferences.data) || !Object.hasOwn(preferences.data, key)) return "defer";
      if (preferences.data[key] === false) return "drop";
      if (preferences.data[key] !== true && preferences.data[key] !== null) return "defer";
    }

    if (note.type === "supplement_reminder") {
      if (!isUUID(note.id) || note.actor_id != null || !isUUID(note.data?.dose_id)) return "drop";
      const allowed = await db.rpc("can_dispatch_supplement", { p_notification: note.id });
      if (allowed.error || typeof allowed.data !== "boolean") return "defer";
      return allowed.data ? "send" : "drop";
    }
    if (!blindTypes.has(note.type) && !shotTypes.has(note.type)) return "send";
    if (!isUUID(note.actor_id) || note.actor_id === note.recipient_id || !isObject(note.data)) return "drop";

    if (blindTypes.has(note.type)) {
      if (!isUUID(note.data.blind_workout_id)) return "drop";
      const result = await db.from("blind_workouts").select("id,creator_id,recipient_id,status")
        .eq("id", note.data.blind_workout_id).maybeSingle();
      if (result.error) return "defer";
      const workout = result.data;
      if (workout === null) return "drop";
      if (!isObject(workout) || !isUUID(workout.id) || !isUUID(workout.creator_id)
        || !isUUID(workout.recipient_id) || typeof workout.status !== "string") return "defer";
      if (workout.id !== note.data.blind_workout_id || workout.creator_id === workout.recipient_id) return "drop";
      if (note.type === "blind_workout_received") {
        if (workout.creator_id !== note.actor_id || workout.recipient_id !== note.recipient_id || workout.status !== "sent") return "drop";
      } else if (note.type === "blind_workout_completed") {
        if (workout.recipient_id !== note.actor_id || workout.creator_id !== note.recipient_id || workout.status !== "completed") return "drop";
      } else {
        const participants = new Set([workout.creator_id, workout.recipient_id]);
        if (!participants.has(note.actor_id) || !participants.has(note.recipient_id) || workout.status !== "completed") return "drop";
        const reaction = await db.from("blind_workout_reactions").select("reaction")
          .eq("blind_workout_id", workout.id).eq("user_id", note.actor_id).maybeSingle();
        if (reaction.error) return "defer";
        if (reaction.data === null) return "drop";
        if (!isObject(reaction.data) || typeof reaction.data.reaction !== "string") return "defer";
        if (reaction.data.reaction !== note.body) return "drop";
      }
    } else {
      if (!isUUID(note.data.commitment_id) || !isUUID(note.data.week_id) || !isUUID(note.data.user_id)) return "drop";
      const result = await db.from("weekly_commitments").select("id,user_id,week_id,achieved")
        .eq("id", note.data.commitment_id).maybeSingle();
      if (result.error) return "defer";
      const commitment = result.data;
      if (commitment === null) return "drop";
      if (!isObject(commitment) || !isUUID(commitment.id) || !isUUID(commitment.user_id)
        || !isUUID(commitment.week_id) || typeof commitment.achieved !== "boolean") return "defer";
      if (commitment.id !== note.data.commitment_id || commitment.user_id !== note.data.user_id || commitment.week_id !== note.data.week_id) return "drop";
      if (note.type === "shot_reaction") {
        if (commitment.user_id !== note.recipient_id || commitment.user_id === note.actor_id) return "drop";
        const reaction = await db.from("weekly_shot_reactions").select("reaction")
          .eq("commitment_id", commitment.id).eq("user_id", note.actor_id).maybeSingle();
        if (reaction.error) return "defer";
        if (reaction.data === null) return "drop";
        if (!isObject(reaction.data) || typeof reaction.data.reaction !== "string") return "defer";
        if (reaction.data.reaction !== note.body) return "drop";
      } else if (commitment.user_id !== note.actor_id || (note.type === "shot_achieved" && !commitment.achieved)) return "drop";
    }

    // One database statement checks accepted friendship and blocks in BOTH directions.
    // A missing EXECUTE grant or unavailable DB is never interpreted as permission.
    const friendship = await db.rpc("are_friends", { a: note.recipient_id, b: note.actor_id });
    if (friendship.error || typeof friendship.data !== "boolean") return "defer";
    return friendship.data ? "send" : "drop";
  } catch {
    return "defer";
  }
}

/**
 * The injected sender keeps policy/queue failure paths runnable without APNS credentials.
 * @param {{ db: any, note: any, prepareToSend?: () => Promise<void>, sendToDevice: (note: any, device: any) => Promise<{ ok: boolean, status: number }>, now?: () => Date }} options
 */
export async function dispatchQueuedNotification({ db, note, prepareToSend = async () => {}, sendToDevice, now = () => new Date() }) {
  let delivered = 0;
  const finish = async (suppressed = false) => {
    try {
      const result = await db.from("notifications").update({ push_sent_at: now().toISOString() })
        .eq("id", note.id).is("push_sent_at", null);
      return { delivered, deferred: result.error ? 1 : 0, suppressed: suppressed && !result.error ? 1 : 0 };
    } catch {
      return { delivered, deferred: 1, suppressed: 0 };
    }
  };
  const decision = await evaluateQueuedNotification(db, note);
  if (decision === "drop") return finish(true);
  if (decision === "defer") return { delivered, deferred: 1, suppressed: 0 };
  let devices;
  try {
    const result = await db.from("device_tokens").select("token,environment").eq("user_id", note.recipient_id);
    if (result.error || !Array.isArray(result.data)) return { delivered, deferred: 1, suppressed: 0 };
    devices = result.data;
  } catch {
    return { delivered, deferred: 1, suppressed: 0 };
  }
  let canFinalize = true;
  let prepared = false;
  for (const device of devices) {
    if (!isObject(device) || typeof device.token !== "string" || !/^[0-9a-f]+$/i.test(device.token)
      || !["ios", "ios-sandbox"].includes(device.environment)) {
      canFinalize = false;
      continue;
    }
    // Key import/token generation can take time: complete it before the last privacy read.
    if (!prepared) {
      try { await prepareToSend(); prepared = true; }
      catch { return { delivered, deferred: 1, suppressed: 0 }; }
    }
    // Re-check immediately before EACH device, not only when loading the queued row.
    // No system can retract a notification APNS already accepted before revocation.
    const latestDecision = await evaluateQueuedNotification(db, note);
    if (latestDecision === "drop") return finish(true);
    if (latestDecision === "defer") return { delivered, deferred: 1, suppressed: 0 };
    try {
      const response = await sendToDevice(note, device);
      if (response.ok) delivered++;
      else if (response.status === 410) {
        const removal = await db.from("device_tokens").delete().eq("user_id", note.recipient_id).eq("token", device.token);
        if (removal.error) canFinalize = false;
      } else canFinalize = false;
    } catch {
      canFinalize = false;
    }
  }
  return canFinalize ? finish() : { delivered, deferred: 1, suppressed: 0 };
}
