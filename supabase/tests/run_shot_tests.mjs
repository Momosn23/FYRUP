// Reuse the full preceding-feature integration harness, with 008 and its suite.
// node supabase/tests/run_shot_tests.mjs
process.argv.push('--shots');
await import('./run_blind_tests.mjs');
