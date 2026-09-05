// Disposable PostgreSQL. Includes every preceding feature regression suite.
process.argv.push('--personal-training');
await import('./run_blind_tests.mjs');
