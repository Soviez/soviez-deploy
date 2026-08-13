# Migration Source Grace Protocol

## State

After successful authorization commit and local apply, source production enters **`migration_origin_grace`**.

| Field | Value |
|-------|-------|
| `traffic_owner` | `source` |
| `licensed_future_owner` | `destination` |
| `slot` | false (source no longer owns permanent slot) |
| `expires` | null (until Phase 21+ cutover policy) |

## Allowed operations (source)

- Traffic service (production remains live)
- Backup, status, diagnostics, recovery

## Denied operations (source)

Enforced by `soviez_migration_source_grace_assert_allowed`:

- `update`, `clone`, `stage_create`, `second_migration`, `rebind`
- `device_reauth`, `license_export`, `restore_to_new_production`

Violation → `MIGRATION_SOURCE_GRACE_INVALID`.

## Local artifact

`$SOVIEZ_MIG_ROOT/grace/{license_id}/grace.json` — schema `soviez.migration_origin_grace.v1`.

`ENFORCED` marker file indicates restriction checks active.

## Apply

`soviez_migration_source_grace_apply` — called during destination activation sequence after binding apply. Failure → `MIGRATION_SOURCE_GRACE_APPLY_FAILED`; destination remains non-public.

## SaaS record

Fixture/SaaS: `source_grace` table / `migration_source_grace_states` with `state = migration_origin_grace`, `traffic_owner = source`.

## Non-goals (Phase 20)

- Source deactivation or purge (`MIGRATION_SOURCE_PURGE_NOT_AUTHORIZED`)
- DNS or traffic cutover
