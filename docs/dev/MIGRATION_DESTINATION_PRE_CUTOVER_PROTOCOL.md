# Migration Destination Pre-Cutover Protocol

## Status

Destination enters **`production_licensed_pre_cutover`** after authorization commit and successful local activation apply.

Licensed for internal operation; **not** publicly routed.

## Activation sequence

`soviez_migration_destination_activate` (`activation/engine.sh`):

1. `destination_binding_apply(auth_id)`
2. `source_grace_apply(auth_id)` — failure aborts with destination non-public
3. `stage_rebind_apply(auth_id)` — mandatory failures block
4. `split_brain_validate(auth_id)`
5. Internal health check (login, modules, filestore, license guard)
6. Destination verified backup marker (`VERIFIED`, `public_route=false`)
7. Write `activation.json`

## Hard flags (all phases through 20)

```text
public_route = false
production_domain = null
production_dns_changed = false
traffic_cutover_started = false
phase21_allowed = false
traffic_owner = source
```

## Integration neutralization

Binding record sets:

- `mail_neutralized=true`
- `payments_neutralized=true`
- `webhooks_neutralized=true`
- `cron_neutralized=true`

Destination ERP may run internally; outbound integrations must not act as production until Phase 21.

## Prerequisites

- Committed authorization with matching destination fingerprint/digest
- Phase 19 staging validated (no public route on staging identity)
- Optional: `SOVIEZ_MIG_P20_REQUIRE_DEST_BACKUP=1` (default)

## Failure codes

- `MIGRATION_DESTINATION_ACTIVATION_FAILED`
- `MIGRATION_LICENSE_GUARD_DENIED`
- `MIGRATION_DESTINATION_BINDING_INVALID`
