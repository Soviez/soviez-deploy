# IMPLEMENTATION_DECOMPOSITION.md

Proposed modules (do **not** implement now):

```text
src/migration/authorization/
  codes.sh model.sh targeting.sh readiness.sh idempotency.sh
  signing.sh offline.sh report.sh engine.sh
src/migration/token/
  eligibility.sh transaction.sh consume.sh reconcile.sh offline.sh audit.sh
src/migration/rebind/
  model.sh license.sh source_grace.sh destination_binding.sh
  stages.sh split_brain.sh compensate.sh recover.sh engine.sh
src/migration/activation/
  destination.sh license_guard.sh neutralization.sh validate.sh
  backup.sh report.sh engine.sh
src/migration/phase21_readiness/
  model.sh validate.sh drift.sh report.sh engine.sh
src/migration/commands/
  authorization.sh activate.sh recover.sh stage_rebind.sh phase21_readiness.sh
```

## SaaS work (separate repo; frozen UI)

- Atomic migrate-authorization RPC replacing wallet-only burn as SoR
- Sync `commercial_grants.quantity_consumed`
- Installer/device PoP APIs with slot-style idempotency
- Replay registry for offline packages

## Gate change (when authorized)

Replace hard deny of burn in `assert_no_cutover_or_token` with **scoped** `assert_phase20_authorization_allowed` that still forbids DNS cutover / purge / SaaS payload relay.
