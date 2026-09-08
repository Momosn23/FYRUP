// Portable local checks. No uploads, no production DB, no iOS claims.
import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = process.cwd();
const output = resolve(root, 'build/reference-preflight');
mkdirSync(output, { recursive: true });
const node = process.execPath;
const python = process.env.FYRUP_PYTHON ?? (process.platform === 'win32' ? 'python' : 'python3');
const checks = [
  ['catalog', node, ['scripts/validate-exercise-catalog.mjs']],
  ['terminology', node, ['scripts/audit-terminology.mjs']],
  ...['workout', 'blind', 'copy', 'personal_training', 'preference', 'shot', 'step', 'weekly', 'supplement', 'deployment_bundle', 'onboarding', 'reference_revision']
    .map(name => [name, node, [`supabase/tests/run_${name}_tests.mjs`]]),
  ['notification-rules', node, ['--test', 'supabase/functions/dispatch-notifications/dispatch-queue.test.mjs', 'supabase/functions/dispatch-notifications/terminology.test.mjs']],
  ['signing-validator-fixtures', python, ['scripts/test_signing_profile.py']],
  ['release-validator-fixtures', python, ['scripts/test_release_ipa.py']],
  ['reference-comparison-tool-fixtures', python, ['scripts/test_reference_comparison.py']],
  ['reference-config', python, ['scripts/validate-reference-config.py']],
  ['ios-runtime-selection-fixtures', python, ['scripts/test_ios_qa_selection.py']],
  ['whitespace', 'git', ['-c', 'core.safecrlf=false', 'diff', '--check']],
];
const results = [];
for (const [name, command, args] of checks) {
  const started = Date.now();
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', timeout: 180_000, maxBuffer: 8 * 1024 * 1024, windowsHide: true });
  const passed = result.status === 0 && !result.error;
  writeFileSync(resolve(output, `${name}.log`), (result.stdout ?? '') + (result.stderr ?? '') + (result.error?.message ?? ''));
  results.push({ name, status: passed ? 'PASS' : 'FAIL', milliseconds: Date.now() - started, exitCode: result.status });
  console.log(`${passed ? 'PASS' : 'FAIL'} ${name}`);
}
const report = { atUTC: new Date().toISOString(), checks: results, nativeSwiftTests: 'NOT RUN', simulatorScreenshots: 'NOT RUN', productionBackend: 'NOT RUN', physicalIPhone: 'NOT RUN' };
writeFileSync(resolve(output, 'report.json'), JSON.stringify(report, null, 2));
console.log('Local checks only. iOS/production/device checks remain separate.');
process.exitCode = results.every(r => r.status === 'PASS') ? 0 : 1;
