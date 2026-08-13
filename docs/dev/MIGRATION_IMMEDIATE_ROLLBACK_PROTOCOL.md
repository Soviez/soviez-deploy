# Migration Immediate Rollback Protocol

## Purpose

Restore Production traffic to source within the default rollback window when post-cutover validation fails or operator initiates abort.

## Eligibility

`soviez_migration_rollback_eligibility <op-id> <authorization-id>`:

| Tier | When |
|------|------|
| R0 | `traffic_owner != destination` (pre-commit abort) |
| R1 | Post-commit, window open, no meaningful writes / payment capture |
| R2 | Post-commit, window open, elapsed ≥ `SOVIEZ_MIG_P21_DUAL_CONTROL_AFTER_SECONDS` (900) |
| R3 | Meaningful writes, payment side effect, or window expired → not safe |

## Execution

`soviez_migration_rollback_run <pair-id> <op-id> <auth-id> <fqdn> [previous-dns-target] [dual-control-confirmed]`

Steps (best-effort, idempotent):

1. DNS rollback to `previous_dns_target` (exact record)
2. Disable destination Production nginx config
3. Disable stage cutover bindings
4. Source → `rollback_origin`
5. `traffic_owner` → `source`

Token is **never** restored (`token_restored=false`, `migration_token_consumed=true`).

## Automatic evaluation

`soviez_migration_rollback_auto_check <authorization-id>`:

- `SOVIEZ_MIG_P21_SPLIT_BRAIN=1` → AR-04 enforced rollback
- `SOVIEZ_MIG_P21_HEALTH_FLAPPING=1` → AR-01 suppressed or advisory per post-window flag

## Unsafe rollback

When `SOVIEZ_MIG_P21_MEANINGFUL_WRITES=1` or window expired:

- Code: `MIGRATION_ROLLBACK_NOT_SAFE` or `MIGRATION_ROLLBACK_WINDOW_EXPIRED`
- Operator path: Needs Action / reverse-migration (Phase 22 scope)

## Window artifact

`$SOVIEZ_MIG_CUTOVER_OPS_DIR/<op-id>/rollback_window.json` — `opened_at`, `expires_at`, `window_seconds` (default 1800).
