// Disposable local PostgreSQL only: copy idempotency plus every preceding suite.
process.argv.push('--copy-requests');
await import('./run_blind_tests.mjs');
