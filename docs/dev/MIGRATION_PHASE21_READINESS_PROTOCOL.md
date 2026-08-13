# Migration Phase 21 Readiness Protocol

## Purpose

Produce a signed readiness report after destination pre-cutover activation. Confirms Phase 20 invariants before **separate** Phase 21 authorization — does **not** enable cutover.

## Operation

`soviez_migration_phase21_readiness` (`phase21_readiness/engine.sh`):

Input: `authorization_id` or operation id.

## Blockers (→ BLOCKED)

- `destination_activation_missing`
- `source_grace_missing`
- `destination_backup_missing`
- `token_not_fully_consumed` (grant remaining ≠ 0)
- `slot_count_invalid` (≠ 1)
- `public_route` true on activation
- `mandatory_stage_failure`
- Injected drift (`SOVIEZ_MIG_P20_INJECT_DRIFT=readiness`)

## Warnings (→ WARNING)

- `optional_stage_failure`

## Pass (→ PASS)

All blockers clear; may include warnings.

## Report schema

`soviez.migration_phase21_readiness.v1`:

```text
readiness_status: PASS | WARNING | BLOCKED
phase21_allowed: false          # always false in Phase 20
production_dns_changed: false
traffic_cutover_started: false
public_route: false
traffic_owner: source
expires_at: created + SOVIEZ_MIG_P21_READINESS_TTL_SECONDS (default 86400)
```

## Expiry and drift

`soviez_migration_phase21_readiness_show`:

- Expired report → `MIGRATION_PHASE21_NOT_READY`
- Drift injection → `MIGRATION_PHASE19_DRIFT_DETECTED`

## Ledger snapshot checks

`snapshot --license-id`:

- `grant_remaining == 0`
- `slot_count == 1`
- `committed_authorizations >= 1`

## Phase boundary

Phase 21 remains **UNAUTHORIZED**. PASS readiness does not mutate DNS, traffic, or `phase21_allowed`.
