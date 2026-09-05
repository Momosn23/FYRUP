// Disposable local PostgreSQL, including all preceding feature migrations.
process.argv.push('--preference-cas');
await import('./run_blind_tests.mjs');
