# OPERATION_ENGINE_MODEL.md

## Operation family

All Phase 21 work under unified operation types (Phase 14 engine reuse):

| operation_type | Purpose |
|----------------|---------|
| `migration_cutover_plan` | Preflight + readiness revalidation |
| `migration_cutover_final_sync` | Optional delta sync |
| `migration_cutover_route_activate` | Destination nginx Production route |
| `migration_cutover_tls_validate` | Production cert gate |
| `migration_cutover_dns_instruction` | Emit manual DNS doc + attestation |
| `migration_cutover_source_maintenance` | Source freeze/maintenance |
| `migration_cutover_health` | Public health/smoke |
| `migration_cutover_commit` | traffic_owner flip |
| `migration_cutover_integrations` | Incremental activation |
| `migration_cutover_stage_public` | Stage routing |
| `migration_cutover_rollback` | Rollback sequence |
| `migration_cutover_complete` | Signed completion report |

## Parent operation

Recommended single parent: `migration_cutover` with sub-steps as state machine transitions — enables pause/recover/reboot survival.

## State machine (simplified)

```text
planned → final_sync? → route_active → tls_valid → dns_instruction →
source_maintenance → health_pending → committed → integrations → stages →
completed | rolling_back | aborted | needs_action
```

## Idempotency

- Key: `(authorization_id, operation_type, idempotency_key)`.
- Replay returns same step outcome or explicit resume pointer.
- Commit step exactly-once for `traffic_owner` flip.

## Locks

- Exclusive lock on `authorization_id` during cutover (no concurrent Phase 19/20 ops).
- Source/dest host locks via Phase 14 ops primitives.

## Pause / recover

- Pause allowed **before** commit only.
- Recover after reboot: reload operation JSON; resume from last completed sub-step.
- Commit unknown: query ledger for traffic_owner before local retry.

## Abort

- Pre-commit: full abort restores source grace/freeze exit.
- Post-commit: must use rollback operation, not abort.

## Gate integration

Replace env-flag cutover with:

```bash
soviez_migration_assert_phase21_cutover_allowed "$operation_type"
```

Requires: Phase 21 readiness valid, Phase 20 committed, owner authorization flag in operation plan (not ambient env).

## Reporting

Each sub-step emits signed sub-report; parent aggregates into `migration_cutover_complete` banner matching `CORRECTED_SCOPE.md`.
