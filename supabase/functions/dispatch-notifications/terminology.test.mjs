import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { notificationCopy, notificationPayload } from './dispatch-queue.mjs';

const examples = JSON.parse(await readFile(new URL('../../../FYRUPTests/Fixtures/terminology-notifications.json', import.meta.url), 'utf8'));
for (const [index, example] of examples.entries()) {
  test(`terminology ${index + 1}: ${example.type}; same fixture as native app`, () => {
    const expected = { title: example.expectedTitle, body: example.expectedBody };
    assert.deepEqual(notificationCopy(example), expected);
    const note = { ...example, id: 'receipt', recipient_id: 'owner', data: { plan_id: 'plan', title: 'Training' } };
    const before = structuredClone(note);
    assert.deepEqual(notificationPayload(note).aps.alert, expected);
    assert.deepEqual(notificationCopy({ ...example, ...expected }), expected, 'idempotent formatting');
    assert.deepEqual(note, before, 'source row and user content unchanged');
    assert.equal(notificationPayload(note).fyrup_notification_id, 'receipt');
    assert.equal(notificationPayload(note).plan_id, 'plan');
  });
}
