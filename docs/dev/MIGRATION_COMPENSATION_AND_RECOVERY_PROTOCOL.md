# Migration Compensation and Recovery Protocol

## Lost response recovery

After `migration_authorization_commit` with unknown outcome:

1. Query local op state: `$SOVIEZ_MIG_ROOT/ops/{op_id}/authorization.json`
2. If missing, call ledger `get --account-id --idempotency-key`
3. SaaS: `get_migration_authorization_by_idempotency`

Same idempotency key + hash → safe replay returns receipt; no double consume.

## Local apply pending

If commit succeeded but local binding/grace not applied:

- State: `MIGRATION_LOCAL_APPLY_PENDING` (code registered)
- Recovery: re-run destination activation with known `authorization_id`
- Idempotent local writes (binding/grace files overwritten consistently)

## Partial failure after commit

| Failure point | Token state | Destination | Source | Action |
|---------------|-------------|-------------|--------|--------|
| Commit OK, grace fail | Consumed | Non-public binding may exist | Not in grace | Manual recovery; no auto refund |
| Commit OK, stage BLOCKED | Consumed | Partial activation | Grace may exist | Phase 21 BLOCKED; ops review |
| Commit unknown | Unknown | Unknown | Unknown | Idempotency recover |

## Compensation / reversal

- Default: **no automatic token refund** on failed local apply.
- Pre-cutover reversal: admin-only exceptional op `migration_pre_cutover_reversal` (registered; deferred implementation).
- SaaS authorization status may transition to `compensated` / `revoked` only via admin paths (not installer auto).

## Codes

- `MIGRATION_AUTHORIZATION_COMMIT_UNKNOWN`
- `MIGRATION_COMPENSATION_REQUIRED`
- `MIGRATION_REVERSAL_NOT_AUTHORIZED`
- `MIGRATION_REVERSAL_SAFETY_CHECK_FAILED`

## Operation engine

Op state files under `$SOVIEZ_MIG_ROOT/ops/{op_id}/state.json` track:

- `committing_token_and_binding`
- `authorization_committed`
- `failed_precommit`
- `source_grace_apply_failed`
