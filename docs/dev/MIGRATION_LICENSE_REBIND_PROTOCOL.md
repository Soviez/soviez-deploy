# Migration License Rebind Protocol

## Semantics

Phase 20 performs a **binding transition** on the existing license — not a new license issuance.

| Invariant | Value |
|-----------|-------|
| Licenses created | 0 |
| `license_slots_used` delta | 0 |
| `slot_count` | unchanged (typically 1) |
| Binding change | source fingerprint → destination fingerprint |
| DB UUID / image digest | updated to destination values |

## Commit-time binding (SaaS)

Recorded in `migration_binding_transitions` with status `authorized`. License row binding fields updated within the same transaction as token consume (SaaS) or in fixture `licenses` table (SQLite).

## Local apply (destination)

`soviez_migration_destination_binding_apply` (`rebind/engine.sh`):

- Requires committed `authorization.json`.
- Proof-of-possession: `SOVIEZ_MIG_P20_LOCAL_DEST_FP` must match receipt if set.
- Writes `production_licensed_pre_cutover` binding to `$SOVIEZ_MIG_ROOT/activation/{auth_id}/binding.json`.
- `public_route=false`, integrations neutralized (mail, payments, webhooks, cron).
- `license_guard=enabled`, `permanent_slot=true`.

## Conflict detection

- Source fingerprint mismatch → `MIGRATION_SOURCE_BINDING_INVALID`
- Duplicate committed authorization for license → `MIGRATION_ACTIVE_OPERATION_CONFLICT`
- Destination PoP mismatch → `MIGRATION_DESTINATION_BINDING_INVALID`
- Second production binding → `MIGRATION_DUPLICATE_PRODUCTION_BINDING`

## One license, one slot

Authorization receipt includes `slot_count_before == slot_count_after`. Phase 21 readiness blocks if `slot_count != 1` or token not fully consumed.
