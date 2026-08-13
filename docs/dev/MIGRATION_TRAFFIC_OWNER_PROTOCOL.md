# Migration Traffic Owner Protocol

## Purpose

Maintain the single authoritative signal for who owns live Production traffic during and after migration cutover.

## Schema

`soviez.traffic_owner.v1`:

```json
{
  "schema": "soviez.traffic_owner.v1",
  "id": "<authorization_id>",
  "traffic_owner": "source|destination",
  "previous_owner": "...",
  "switched_at": "ISO8601|null"
}
```

Stored at `$SOVIEZ_MIG_ROOT/traffic_owner/<authorization_id>.json` (signed).

## Lifecycle

| Phase | Default owner |
|-------|---------------|
| Phase 18–20 pre-cutover | `source` (implicit if file missing) |
| Phase 21 cutover commit | `destination` (exactly-once switch) |
| Immediate rollback R1/R2 | `source` |

## API

- `soviez_migration_traffic_owner_get <authorization-id>`
- `soviez_migration_traffic_owner_switch <authorization-id> <source|destination>`

Switch is idempotent: repeated switch to current owner is a no-op returning existing record.

## Invariants

- Cutover plan records `traffic_owner=source`
- Phase 20 activation: `traffic_owner=source`, `traffic_cutover_started=false`
- Phase 21 complete: `traffic_owner=destination`, `production_dns_changed=true`
- Rollback never restores migration token consumption

## Integration

Phase 22 post-cutover readiness blocks if `traffic_owner != destination`.

License Guard policy (OD-38) should treat `traffic_owner` as first-class alongside `migration_origin_grace` and `production_licensed_pre_cutover`.
