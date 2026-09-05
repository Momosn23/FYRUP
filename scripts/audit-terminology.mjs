// Guard new app copy without renaming APIs, persisted catalog choices or user content.
import { readdir, readFile } from 'node:fs/promises';
import { dirname, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const catalog = new Set(['Freies Training', 'Mannschaftstraining', 'Einzeltraining', 'Training', 'Tennis · Training', 'Padel · Training']);
const technical = new Set(['my_training_groups', 'create_training_group', 'delete_training_group',
  'get_training_routine', 'save_training_routine', 'get_personal_training_week', 'save-training-routine', 'skip-training-routine']);
const exceptions = new Map();
const violations = [];
let filesChecked = 0;

function allowed(path, value, line) {
  if (/^figure\.[a-z.]*training[a-z.]*$/.test(value)) return 'Apple SF Symbols';
  if (technical.has(value) || value.startsWith('training-week-day-\\(')) return 'Stable API / accessibility ID';
  if (path === 'FYRUP/Models/Domain.swift' && catalog.has(value)) return 'Persisted catalog input';
  if (path === 'FYRUP/Views/AuthViews.swift' && value === 'Freies Training' && line.includes('item ==')) return 'Catalog comparison, not output';
  if (path === 'FYRUP/Models/FyrupLanguage.swift' && (line.includes('case (') || line.includes('if title ==') || line.includes('if body ==') || line.includes('replacingOccurrences(of:'))) return 'Tested legacy display adapter';
  if (path.endsWith('/Localizable.strings') && ['TRAINING PLANEN', 'TRAINING BEENDEN'].includes(value)
      && line.trimStart().startsWith(`"${value}" =`)) return 'Legacy localization key, modern value';
  return null;
}

async function scan(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const full = resolve(directory, entry.name);
    if (entry.isDirectory()) { await scan(full); continue; }
    if (!/\.(swift|strings|plist)$/.test(entry.name)) continue;
    filesChecked++;
    const path = relative(root, full).replaceAll('\\', '/');
    const lines = (await readFile(full, 'utf8')).split(/\r?\n/);
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index];
      if (line.trimStart().startsWith('//')) continue;
      const values = [...line.matchAll(/"((?:\\.|[^"\\])*)"/g)].map(match => match[1]);
      if (entry.name.endsWith('.plist')) values.push(...[...line.matchAll(/<string>(.*?)<\/string>/g)].map(match => match[1]));
      for (const value of values.filter(value => /training|trainier/i.test(value))) {
        const reason = allowed(path, value, line);
        if (reason) exceptions.set(reason, (exceptions.get(reason) ?? 0) + 1);
        else violations.push(`${path}:${index + 1}: ${value}`);
      }
    }
  }
}

await scan(resolve(root, 'FYRUP'));
for (const [reason, count] of exceptions) console.log(`Allowed ${count}: ${reason}`);
if (violations.length) {
  console.error(violations.join('\n'));
  process.exitCode = 1;
} else console.log(`Terminology audit PASS: ${filesChecked} app text files; no unreviewed legacy copy.`);
// This guard complements native tests/screenshots; it is not a Swift parser or a visual review.
