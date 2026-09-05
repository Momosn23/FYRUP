import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const catalogPath = new URL('../FYRUP/Resources/exercise-library.tsv', import.meta.url);
const requiredPath = new URL('../FYRUPTests/Fixtures/exercise-catalog-required.tsv', import.meta.url);
const rows = path => readFileSync(path, 'utf8').split(/\r?\n/).filter(line => line.trim() && !line.startsWith('#')).map(line => line.split('\t'));
const muscles = new Set(['chest', 'back', 'shoulders', 'biceps', 'triceps', 'quads', 'hamstrings', 'glutes', 'calves', 'adductors', 'core', 'traps', 'forearms', 'full_body', 'other']);
const equipment = new Set(['barbell', 'dumbbell', 'cable', 'machine', 'smith', 'bodyweight', 'kettlebell', 'band', 'other']);
const catalog = rows(catalogPath);
const required = rows(requiredPath);
const ids = new Map();
const names = new Set();
const normalize = value => value.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase().replace(/ß/g, 'ss').replace(/[^\p{Letter}\p{Number}]+/gu, '');

for (const fields of catalog) {
  assert.equal(fields.length, 6, `Expected six fields: ${fields}`);
  const [id, name, primary, secondary, gear, type] = fields;
  assert.match(id, /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i);
  assert(!ids.has(id), `Duplicate ID: ${id}`);
  assert(!names.has(normalize(name)), `Duplicate name: ${name}`);
  assert.equal(name, name.trim(), `Untrimmed name: ${name}`);
  assert(name.length >= 2 && name.length <= 100, `Invalid name: ${name}`);
  assert(muscles.has(primary), `Invalid primary: ${name}`);
  assert(equipment.has(gear), `Invalid equipment: ${name}`);
  assert(['strength', 'timed'].includes(type), `Invalid type: ${name}`);
  const secondaryMuscles = secondary ? secondary.split(',') : [];
  assert.equal(new Set(secondaryMuscles).size, secondaryMuscles.length, `Duplicate secondary: ${name}`);
  assert(secondaryMuscles.every(value => muscles.has(value) && value !== primary), `Invalid secondary: ${name}`);
  ids.set(id, { name, muscles: new Set([primary, ...secondaryMuscles]) });
  names.add(normalize(name));
}

assert.equal(required.length, 127, 'The original prompt specifies 127 muscle/name memberships.');
assert.equal(new Set(required.map(fields => fields[2])).size, 122, 'Shared movements are deduplicated into 122 original catalog IDs.');
const membershipCounts = {};
for (const [muscle, name, id] of required) {
  const entry = ids.get(id);
  assert(entry, `Missing stable ID for ${name}: ${id}`);
  assert(entry.muscles.has(muscle), `Missing muscle membership: ${name} → ${muscle}`);
  const canonical = name === 'Bulgarian Split Squat' ? 'Bulgarian Split Squats' : name;
  assert.equal(entry.name, canonical, `Original stable ID was remapped: ${id}`);
  membershipCounts[muscle] = (membershipCounts[muscle] ?? 0) + 1;
}

process.stdout.write(JSON.stringify({
  result: 'PASS',
  check: 'Static catalog schema, all prompt muscle/name memberships and frozen ID mapping',
  catalog: fileURLToPath(catalogPath),
  exercises: catalog.length,
  requiredMemberships: required.length,
  membershipCounts,
  note: 'This is not an iOS simulator, UI, database, or TestFlight test.'
}, null, 2) + '\n');
