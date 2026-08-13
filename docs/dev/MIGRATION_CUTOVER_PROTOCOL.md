# Migration Cutover Protocol

## Purpose

Execute Production traffic cutover from Phase 20 committed state through the canonical Phase 21 engine.

## Preconditions

- Committed Phase 20 authorization (`transaction_status=committed`)
- Destination activation + verified backup
- Source `migration_origin_grace`
- Token ledger: `grant_remaining=0`, `slot_count=1`
- Phase 21 pre-cutover readiness PASS (or `SOVIEZ_MIG_P21_FIXTURE=1` in certification)

## Operations

| Function | Role |
|----------|------|
| `soviez_migration_cutover_plan` | Signed read-only intent; no mutation |
| `soviez_migration_cutover_plan_show` | Verify signature + display plan |
| `soviez_migration_cutover_start` | Full cutover state machine |
| `soviez_migration_cutover_retry` | Idempotent re-run |
| `soviez_migration_cutover_recover` | Recover persisted op state after lost response |
| `soviez_migration_cutover_status` | Read op state |

## Plan schema

`soviez.migration_cutover_plan.v1` — fields include `production_fqdn`, `destination_target`, `rollback_window_seconds`, `freeze_max_seconds`, `traffic_owner=source`, `phase22_allowed=false`.

## DNS modes

- **fixture** (default in TEST_MODE): exact-record zone files under `SOVIEZ_MIG_P21_DNS_ZONE_DIR`
- **manual**: emits instructions; requires `SOVIEZ_MIG_P21_DNS_CONFIRMED=1` before mutate

## Gates

- `SOVIEZ_MIG_P21_CANONICAL_CUTOVER=1` set only inside `cutover_start`
- `SOVIEZ_MIG_ALLOW_CUTOVER=1` without canonical flag → `MIGRATION_CANONICAL_CUTOVER_REQUIRED`
- Injected drift → `MIGRATION_CUTOVER_DRIFT_DETECTED`

## Certification banner (stderr on success)

```text
TRAFFIC OWNER — DESTINATION
PRODUCTION DNS — CHANGED
SOURCE — MAINTENANCE (BUSINESS WRITES DENIED)
ROLLBACK WINDOW — OPEN
PHASE 22 READINESS — REPORTED
NO SOURCE PURGE / NO SOURCE ARCHIVE / NO SAAS PAYLOAD RELAY
MIGRATION TOKEN — CONSUMED EXACTLY ONCE (PHASE 20)
```

## Error codes (selected)

`MIGRATION_CUTOVER_CONFIRMATION_REQUIRED`, `MIGRATION_FINAL_CUTOVER_SYNC_FAILED`, `MIGRATION_DNS_CUTOVER_NOT_CONFIRMED`, `MIGRATION_TLS_PRODUCTION_INVALID`, `MIGRATION_POST_CUTOVER_HEALTH_FAILED`, `MIGRATION_TRAFFIC_OWNER_SWITCH_FAILED`
