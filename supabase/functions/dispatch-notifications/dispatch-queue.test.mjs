import test from "node:test";
import assert from "node:assert/strict";
import { evaluateQueuedNotification, dispatchQueuedNotification, preferenceKeys, notificationPayload } from "./dispatch-queue.mjs";

const recipient = "00000000-0000-0000-0000-000000000001";
const actor = "00000000-0000-0000-0000-000000000002";
const blindID = "00000000-0000-0000-0000-000000000003";
const commitmentID = "00000000-0000-0000-0000-000000000004";
const weekID = "00000000-0000-0000-0000-000000000005";
const noteID = "00000000-0000-0000-0000-000000000006";
const thirdParty = "00000000-0000-0000-0000-000000000007";
const ok = (data) => ({ data, error: null });
const failure = () => ({ data: null, error: { message: "Database unavailable" } });

test("APNS payload binds notification and recipient IDs to the authorized row", () => {
  const { note } = fixture("shot_called");
  const payload = notificationPayload(note);
  assert.equal(payload.fyrup_notification_id, noteID);
  assert.equal(payload.fyrup_recipient_id, recipient);
  assert.equal(payload.fyrup_type, "shot_called");
  assert.equal(payload.commitment_id, commitmentID);
  assert.equal(payload.week_id, weekID);
  assert.deepEqual(payload.aps.alert, { title: note.title, body: note.body });
});

test("data cannot spoof reserved routing fields or the APNS alert", () => {
  const { note } = fixture("blind_workout_received");
  note.data = { ...note.data, fyrup_notification_id: thirdParty, fyrup_recipient_id: actor,
    fyrup_type: "shot_called", aps: { alert: "Not the authorized alert" } };
  const payload = notificationPayload(note);
  assert.equal(payload.fyrup_notification_id, noteID);
  assert.equal(payload.fyrup_recipient_id, recipient);
  assert.equal(payload.fyrup_type, "blind_workout_received");
  assert.equal(payload.blind_workout_id, blindID);
  assert.deepEqual(payload.aps.alert, { title: note.title, body: note.body });
});

function fixture(type = "shot_called", options = {}) {
  const isReaction = type === "shot_reaction";
  const note = { id: noteID, recipient_id: recipient, actor_id: actor, type, title: "FYRUP", body: "🔥",
    data: type.startsWith("blind_") ? { blind_workout_id: blindID }
      : { commitment_id: commitmentID, week_id: weekID, user_id: isReaction ? recipient : actor } };
  const workout = { id: blindID, creator_id: type === "blind_workout_completed" ? recipient : actor,
    recipient_id: type === "blind_workout_completed" ? actor : recipient,
    status: type === "blind_workout_received" ? "sent" : "completed" };
  const commitment = { id: commitmentID, user_id: isReaction ? recipient : actor, week_id: weekID, achieved: type === "shot_achieved" };
  const queries = [], rpcCalls = [], sends = [];
  const route = (query) => {
    queries.push(query);
    if (options.route) {
      const response = options.route(query);
      if (response !== undefined) return response;
    }
    switch (query.table) {
      case "notification_preferences": return ok({ [query.selected]: true });
      case "blind_workouts": return ok(workout);
      case "weekly_commitments": return ok(commitment);
      case "blind_workout_reactions": case "weekly_shot_reactions": return ok({ reaction: "🔥" });
      case "device_tokens": return query.kind === "delete" ? ok(null) : ok([{ token: "abcdef0123456789", environment: "ios" }]);
      case "notifications": return ok(null);
      default: throw new Error(`Unexpected table ${query.table}`);
    }
  };
  const db = {
    from(table) {
      const query = { table, kind: "select", filters: [], selected: null, values: null };
      const builder = {
        select(value) { query.selected = value; return builder; },
        eq(key, value) { query.filters.push(["eq", key, value]); return builder; },
        is(key, value) { query.filters.push(["is", key, value]); return builder; },
        update(value) { query.kind = "update"; query.values = value; return builder; },
        delete() { query.kind = "delete"; return builder; },
        async maybeSingle() { return await route(query); },
        then(resolve, reject) { return Promise.resolve().then(() => route(query)).then(resolve, reject); },
      };
      return builder;
    },
    async rpc(name, args) {
      rpcCalls.push({ name, args });
      return options.rpc ? await options.rpc(name, args, rpcCalls.length) : ok(true);
    },
  };
  const dispatch = (sendToDevice = async (_note, device) => { sends.push(device); return { ok: true, status: 200 }; }) =>
    dispatchQueuedNotification({ db, note, sendToDevice, now: () => new Date("2026-09-05T12:00:00Z") });
  return { db, note, workout, commitment, queries, rpcCalls, sends, dispatch };
}

test("new types share the exact SQL notification preference categories", () => {
  assert.equal(preferenceKeys.blind_workout_received, "invitations");
  assert.equal(preferenceKeys.blind_workout_completed, "reactions");
  assert.equal(preferenceKeys.blind_reaction, "reactions");
  assert.equal(preferenceKeys.shot_called, "weekly_goal");
  assert.equal(preferenceKeys.shot_achieved, "weekly_goal");
  assert.equal(preferenceKeys.shot_reaction, "reactions");
  assert.equal(preferenceKeys.flame_reaction, "reactions");
});

for (const type of ["blind_workout_received", "blind_workout_completed", "blind_reaction", "shot_called", "shot_achieved", "shot_reaction"]) {
  test(`${type}: validates live record and accepted nonblocked pair before every send`, async () => {
    const context = fixture(type);
    const result = await context.dispatch();
    assert.deepEqual(result, { delivered: 1, deferred: 0, suppressed: 0 });
    assert.equal(context.sends.length, 1);
    assert.equal(context.rpcCalls.length, 2);
    assert.deepEqual(context.rpcCalls[0], { name: "are_friends", args: { a: recipient, b: actor } });
    assert.ok(context.queries.filter((query) => query.table === "notification_preferences").every((query) =>
      query.selected === preferenceKeys[type] && query.filters.some((filter) => filter[1] === "user_id" && filter[2] === recipient)));
    const finalized = context.queries.find((query) => query.table === "notifications" && query.kind === "update");
    assert.deepEqual(finalized.filters, [["eq", "id", noteID], ["is", "push_sent_at", null]]);
  });
}

test("current unfriend or either-direction block suppresses queued alerts", async () => {
  for (const type of ["blind_workout_received", "blind_workout_completed", "blind_reaction", "shot_called", "shot_achieved", "shot_reaction"]) {
    const context = fixture(type, { rpc: () => ok(false) });
    assert.deepEqual(await context.dispatch(), { delivered: 0, deferred: 0, suppressed: 1 }, type);
    assert.equal(context.sends.length, 0, type);
  }
});

test("a revoked pair after queue loading is rechecked before APNS", async () => {
  const context = fixture("shot_called", { rpc: (_name, _args, count) => ok(count === 1) });
  const result = await context.dispatch();
  assert.deepEqual(result, { delivered: 0, deferred: 0, suppressed: 1 });
  assert.equal(context.sends.length, 0);
});

test("privacy is rechecked after slow credential preparation, and preparation failures defer", async () => {
  let stillFriends = true;
  const context = fixture("shot_called", { rpc: () => ok(stillFriends) });
  let sends = 0;
  const result = await dispatchQueuedNotification({ db: context.db, note: context.note,
    prepareToSend: async () => { stillFriends = false; },
    sendToDevice: async () => { sends++; return { ok: true, status: 200 }; } });
  assert.deepEqual(result, { delivered: 0, deferred: 0, suppressed: 1 });
  assert.equal(sends, 0);
  const unavailable = fixture();
  const deferred = await dispatchQueuedNotification({ db: unavailable.db, note: unavailable.note,
    prepareToSend: async () => { throw new Error("APNS key unavailable"); },
    sendToDevice: async () => { sends++; return { ok: true, status: 200 }; } });
  assert.deepEqual(deferred, { delivered: 0, deferred: 1, suppressed: 0 });
  assert.equal(sends, 0);
});

test("revocation between devices prevents the second device push", async () => {
  const context = fixture("shot_achieved", {
    route: (query) => query.table === "device_tokens" ? ok([{ token: "aaaa", environment: "ios" }, { token: "bbbb", environment: "ios-sandbox" }]) : undefined,
    rpc: (_name, _args, count) => ok(count < 3),
  });
  assert.deepEqual(await context.dispatch(), { delivered: 1, deferred: 0, suppressed: 1 });
  assert.equal(context.sends.length, 1);
});

test("preference changes before sending suppress the queued notification", async () => {
  let reads = 0;
  const context = fixture("blind_workout_received", { route: (query) => {
    if (query.table === "notification_preferences") return ok({ [query.selected]: ++reads === 1 });
  } });
  assert.deepEqual(await context.dispatch(), { delivered: 0, deferred: 0, suppressed: 1 });
  assert.equal(context.sends.length, 0);
});

test("preference database errors and malformed responses defer, never default to permission", async () => {
  for (const response of [failure(), ok(undefined), ok({}), ok({ weekly_goal: "true" })]) {
    const context = fixture("shot_called", { route: (query) => query.table === "notification_preferences" ? response : undefined });
    assert.deepEqual(await context.dispatch(), { delivered: 0, deferred: 1, suppressed: 0 });
    assert.equal(context.sends.length, 0);
    assert.ok(!context.queries.some((query) => query.kind === "update"));
  }
});

test("no preference row or SQL null uses the documented default, explicit false suppresses", async () => {
  for (const preference of [null, { weekly_goal: null }, { weekly_goal: false }]) {
    const context = fixture("shot_called", { route: (query) => query.table === "notification_preferences" ? ok(preference) : undefined });
    const result = await context.dispatch();
    assert.equal(result.delivered, preference?.weekly_goal === false ? 0 : 1);
    assert.equal(result.deferred, 0);
  }
});

test("friendship query failures, missing execute grants and nonboolean payloads defer", async () => {
  for (const response of [failure(), { data: null, error: { code: "42501" } }, ok(null), ok("true")]) {
    const context = fixture("blind_reaction", { rpc: () => response });
    assert.deepEqual(await context.dispatch(), { delivered: 0, deferred: 1, suppressed: 0 });
    assert.equal(context.sends.length, 0);
    assert.ok(!context.queries.some((query) => query.kind === "update"));
  }
});

test("a privacy failure after token lookup is also deferred without a send or finalization", async () => {
  const context = fixture("shot_reaction", { rpc: (_name, _args, count) => count === 1 ? ok(true) : failure() });
  assert.deepEqual(await context.dispatch(), { delivered: 0, deferred: 1, suppressed: 0 });
  assert.equal(context.sends.length, 0);
  assert.ok(!context.queries.some((query) => query.kind === "update"));
});

test("deleted source records suppress; source database failures defer", async () => {
  for (const type of ["blind_workout_received", "shot_called"]) {
    const table = type.startsWith("blind") ? "blind_workouts" : "weekly_commitments";
    for (const error of [false, true]) {
      const context = fixture(type, { route: (query) => query.table === table ? (error ? failure() : ok(null)) : undefined });
      assert.equal(await evaluateQueuedNotification(context.db, context.note), error ? "defer" : "drop");
    }
  }
});

test("cancelled, declined and already-accepted invitations are not sent again", async () => {
  for (const status of ["cancelled", "declined", "accepted", "planned", "live", "completed"]) {
    const context = fixture("blind_workout_received"); context.workout.status = status;
    assert.equal(await evaluateQueuedNotification(context.db, context.note), "drop", status);
  }
});

test("blind completion and reactions require a completed source and exact participant roles", async () => {
  for (const type of ["blind_workout_completed", "blind_reaction"]) {
    const status = fixture(type); status.workout.status = "live";
    assert.equal(await evaluateQueuedNotification(status.db, status.note), "drop");
    const stranger = fixture(type); stranger.note.actor_id = thirdParty;
    assert.equal(await evaluateQueuedNotification(stranger.db, stranger.note), "drop");
    const wrongRecipient = fixture(type); wrongRecipient.note.recipient_id = thirdParty;
    assert.equal(await evaluateQueuedNotification(wrongRecipient.db, wrongRecipient.note), "drop");
  }
});

test("forged shot owner, week, actor and premature success are suppressed", async () => {
  for (const change of [
    (context) => { context.note.data.user_id = thirdParty; },
    (context) => { context.note.data.week_id = thirdParty; },
    (context) => { context.note.actor_id = thirdParty; },
    (context) => { context.commitment.achieved = false; },
  ]) {
    const context = fixture("shot_achieved"); change(context);
    assert.equal(await evaluateQueuedNotification(context.db, context.note), "drop");
  }
  const ownerReaction = fixture("shot_reaction"); ownerReaction.note.actor_id = recipient;
  assert.equal(await evaluateQueuedNotification(ownerReaction.db, ownerReaction.note), "drop");
});

test("deleted or replaced reactions do not send outdated emoji; read errors defer", async () => {
  for (const type of ["blind_reaction", "shot_reaction"]) {
    const table = type === "blind_reaction" ? "blind_workout_reactions" : "weekly_shot_reactions";
    for (const [response, expected] of [[ok(null), "drop"], [ok({ reaction: "💪" }), "drop"], [failure(), "defer"]]) {
      const context = fixture(type, { route: (query) => query.table === table ? response : undefined });
      assert.equal(await evaluateQueuedNotification(context.db, context.note), expected);
    }
  }
});

test("null actors, malformed identifiers, missing payload and unknown types never reach APNS", async () => {
  for (const change of [
    (note) => { note.actor_id = null; }, (note) => { note.actor_id = note.recipient_id; },
    (note) => { note.recipient_id = "bad"; }, (note) => { note.data = null; },
    (note) => { note.data.commitment_id = "x)or(true"; }, (note) => { note.type = "unsupported"; },
    (note) => { note.type = "constructor"; },
  ]) {
    const context = fixture(); change(context.note);
    assert.deepEqual(await context.dispatch(), { delivered: 0, deferred: 0, suppressed: 1 });
    assert.equal(context.sends.length, 0);
  }
});

test("network exceptions during preferences or friendship are fail-closed", async () => {
  const preferences = fixture("shot_called", { route: () => { throw new Error("Network"); } });
  assert.deepEqual(await preferences.dispatch(), { delivered: 0, deferred: 1, suppressed: 0 });
  const friendship = fixture("shot_called", { rpc: () => { throw new Error("Network"); } });
  assert.deepEqual(await friendship.dispatch(), { delivered: 0, deferred: 1, suppressed: 0 });
});

test("token lookup failure is not confused with no registered devices", async () => {
  const failed = fixture("shot_called", { route: (query) => query.table === "device_tokens" ? failure() : undefined });
  assert.deepEqual(await failed.dispatch(), { delivered: 0, deferred: 1, suppressed: 0 });
  assert.ok(!failed.queries.some((query) => query.kind === "update"));
  const none = fixture("shot_called", { route: (query) => query.table === "device_tokens" ? ok([]) : undefined });
  assert.deepEqual(await none.dispatch(), { delivered: 0, deferred: 0, suppressed: 0 });
});

test("invalid device records are not interpolated into APNS URLs", async () => {
  for (const device of [{ token: "../other", environment: "ios" }, { token: "abcd", environment: "untrusted" }]) {
    const context = fixture("shot_called", { route: (query) => query.table === "device_tokens" ? ok([device]) : undefined });
    assert.deepEqual(await context.dispatch(), { delivered: 0, deferred: 1, suppressed: 0 });
    assert.equal(context.sends.length, 0);
  }
});

test("APNS retryable response or thrown request leaves notification queued", async () => {
  for (const sender of [async () => ({ ok: false, status: 503 }), async () => { throw new Error("APNS offline"); }]) {
    const context = fixture();
    assert.deepEqual(await context.dispatch(sender), { delivered: 0, deferred: 1, suppressed: 0 });
    assert.ok(!context.queries.some((query) => query.kind === "update"));
  }
});

test("APNS 410 removes only this recipient's token and deletion errors remain retryable", async () => {
  const context = fixture();
  assert.deepEqual(await context.dispatch(async () => ({ ok: false, status: 410 })), { delivered: 0, deferred: 0, suppressed: 0 });
  const removal = context.queries.find((query) => query.kind === "delete");
  assert.deepEqual(removal.filters, [["eq", "user_id", recipient], ["eq", "token", "abcdef0123456789"]]);
  const failed = fixture("shot_called", { route: (query) => query.kind === "delete" ? failure() : undefined });
  assert.deepEqual(await failed.dispatch(async () => ({ ok: false, status: 410 })), { delivered: 0, deferred: 1, suppressed: 0 });
});

test("finalization errors are reported rather than silently losing retry state", async () => {
  const context = fixture("shot_called", { route: (query) => query.kind === "update" ? failure() : undefined });
  assert.deepEqual(await context.dispatch(), { delivered: 1, deferred: 1, suppressed: 0 });
});

test("existing nonsocial self notifications keep their preference behavior", async () => {
  const context = fixture("weekly_goal"); context.note.actor_id = null;
  assert.deepEqual(await context.dispatch(), { delivered: 1, deferred: 0, suppressed: 0 });
  assert.equal(context.rpcCalls.length, 0);
});
