# Migration Stage Rebind Protocol

## Purpose

Selected Stage environments must rebind parent license context from source to destination as part of authorization commit metadata and local apply.

## Commit-time (ledger)

Stage IDs passed in commit payload (`stage_ids`, `mandatory_stage_ids`).

Fixture ledger evaluates each stage:

| Condition | Status | Code |
|-----------|--------|------|
| Normal stage | `rebound` | `OK` |
| `expired-*` prefix | `denied_expired` | `MIGRATION_STAGE_EXPIRED` |
| `wrong-parent-*` prefix | `denied_parent` | `MIGRATION_STAGE_REBIND_FAILED` |

Results stored in authorization `stage_rebind_results[]` and `stage_rebinds` table.

## Local apply

`soviez_migration_stage_rebind_apply`:

- Reads results from committed authorization.
- Mandatory stage failure → exit 2 (BLOCKED).
- Optional stage failure → exit 1 (WARNING).
- Retention deadline unchanged (`retention_unchanged=true`).

## Activation impact

| Stage rebind outcome | Activation `stage_rebind` | Phase 21 readiness |
|---------------------|---------------------------|-------------------|
| All rebound | PASS | eligible |
| Optional failure | WARNING | WARNING |
| Mandatory failure | BLOCKED | BLOCKED |

## Retention

Stage retention policy from Phase 13 unchanged; rebind does not extend or shorten retention deadlines.

## Codes

- `MIGRATION_STAGE_REBIND_FAILED`
- `MIGRATION_STAGE_REBIND_PARTIAL`
- `MIGRATION_STAGE_EXPIRED`
