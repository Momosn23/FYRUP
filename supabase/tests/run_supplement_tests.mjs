// Disposable PostgreSQL only; includes all preceding privacy and regression suites.
process.argv.push('--supplements');
await import('./run_blind_tests.mjs');
